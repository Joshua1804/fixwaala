/**
 * Server-side AI triage proxy.
 *
 * The Gemini API key lives here and never reaches a client. Previously the app
 * called Gemini directly with a key read from a bundled `.env` asset, which is
 * a plain file inside the APK and recoverable with `unzip` — meaning anyone
 * with a copy of the app could spend the project's quota.
 *
 * Callers must present a valid Firebase ID token, so usage is attributable and
 * revocable per account.
 *
 * Deploy:
 *   firebase functions:secrets:set GEMINI_API_KEY
 *   firebase deploy --only functions
 *
 * Then build the app with the resulting URL:
 *   flutter build apk --dart-define=AI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/aiTriage
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

// Server-owned matching lifecycle — radius expansion and lease expiry.
// These previously ran on timers inside widgets and stopped the moment the
// screen closed. See scheduled.js.
Object.assign(exports, require("./scheduled"));

// Push triggers — job opportunities, candidate acceptance, status changes.
Object.assign(exports, require("./notifications"));

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const MODEL = "gemini-2.5-flash";

/** Rejects anything without a verifiable Firebase ID token. */
async function requireAuth(req) {
  const header = req.get("Authorization") || "";
  if (!header.startsWith("Bearer ")) return null;
  try {
    return await admin.auth().verifyIdToken(header.substring(7));
  } catch (err) {
    console.warn("Rejected token:", err.message);
    return null;
  }
}

exports.aiTriage = onRequest(
  { secrets: [GEMINI_API_KEY], cors: false, maxInstances: 10 },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed" });
    }

    const caller = await requireAuth(req);
    if (!caller) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const { prompt, responseSchema } = req.body || {};
    if (typeof prompt !== "string" || !prompt.trim() || !responseSchema) {
      return res.status(400).json({ error: "prompt and responseSchema required" });
    }
    // Bound the request so a modified client cannot use this as a free,
    // general-purpose LLM endpoint on the project's bill.
    if (prompt.length > 4000) {
      return res.status(413).json({ error: "prompt too long" });
    }

    try {
      const upstream = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY.value()}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              responseMimeType: "application/json",
              responseSchema,
            },
          }),
        }
      );

      if (!upstream.ok) {
        const detail = await upstream.text();
        console.error("Gemini error", upstream.status, detail);
        return res.status(502).json({ error: "Upstream AI request failed" });
      }

      const payload = await upstream.json();
      const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) {
        return res.status(502).json({ error: "Empty AI response" });
      }

      // The app expects the parsed structured object, not the envelope.
      return res.status(200).json(JSON.parse(text));
    } catch (err) {
      console.error("aiTriage failed:", err);
      return res.status(500).json({ error: "AI request failed" });
    }
  }
);
