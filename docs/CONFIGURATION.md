# Build configuration

All runtime configuration is passed at build time with `--dart-define`. Nothing
is read from a bundled `.env` asset.

**Why:** Flutter assets are plain files inside the APK. Anything placed there is
recoverable with `unzip`. The project previously shipped `.env` as an asset with
a live `GEMINI_API_KEY` inside it, so that key was readable by anyone who
obtained a build. Values that are genuinely secret now live server-side; values
that are safe to publish are compiled in.

## Required defines

| Define | Secret? | Purpose |
|---|---|---|
| `AI_PROXY_URL` | No — a URL | Endpoint of the `aiTriage` Cloud Function. Omit and AI assist falls back to the keyword classifier, or to `GEMINI_API_KEY` below if that is set. |
| `GEMINI_API_KEY` | **Yes — dev only** | Calls Gemini directly, no proxy. See the warning below before ever using this. |
| `CLOUDINARY_CLOUD_NAME` | No | Cloudinary account. Public by design. |
| `CLOUDINARY_UPLOAD_PRESET` | No | **Unsigned** upload preset. Public by design — scope it to a folder and rate-limit it in the Cloudinary console. |

```bash
flutter build apk --release \
  --dart-define=AI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/aiTriage \
  --dart-define=CLOUDINARY_CLOUD_NAME=<name> \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=<preset>
```

For day-to-day work, keep these in a `--dart-define-from-file` JSON file that is
gitignored, rather than retyping them.

## Server-side secrets (the proxy path)

The Gemini API key is held only by the Cloud Function:

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

The app calls that function with the signed-in user's Firebase ID token, so
usage is attributable to an account and revocable per user. **This requires
the Firebase project to be on the Blaze plan** — Cloud Functions v2 needs a
billing account attached even at zero usage. See "No Blaze plan" below if
that is not an option right now.

> **The key that previously shipped in `.env` must be treated as compromised
> and rotated.** It was extractable from every build already produced. Rotating
> it is independent of deploying the proxy — do it first.

## No Blaze plan: `GEMINI_API_KEY` dev fallback

If the project is staying on Spark — no functions deployable at all — AI
assist can call Gemini directly instead, by compiling the key into the app:

```bash
flutter run --dart-define=GEMINI_API_KEY=<your-key>
```

**This reintroduces the exact problem the paragraph above describes: a key
compiled into the app is recoverable from any build with `unzip`.** It exists
only as a dev-time convenience and is gated behind an explicit dart-define so
it is never on by accident. Rules for using it safely:

- Use a key from a throwaway Google AI Studio project, not one tied to
  anything you'd mind someone else spending against.
- Never pass it in a build you hand to another person or distribute — sideload
  or debug builds on your own device only.
- Delete the key (or set a tight quota on it) once you stop needing it, and
  before this app is ever distributed to anyone else.
- If both `AI_PROXY_URL` and `GEMINI_API_KEY` are set, the proxy wins — this
  is purely a fallback for when there is no proxy to point at.

## Firestore

Rules and indexes must be deployed together with any build that relies on them;
the scoped listeners added in this phase depend on the composite indexes.

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Admin access

`admin` is a **Firebase custom claim**, not a role in the app. The mobile app
has no administrator UI and cannot grant or obtain the claim. It's set out of
band, locally, with [`scripts/admin/grant_admin_claim.js`](../scripts/admin/README.md)
and consumed by the separate admin website at [`lib/admin/`](../lib/admin/) —
see [ADMIN_WEB.md](ADMIN_WEB.md):

```bash
node scripts/admin/grant_admin_claim.js grant you@example.com
```

`firestore.rules` gates every moderation collection (`reports`, `safetyAlerts`,
`auditEvents`, `admins`, `platformSettings`, `announcements`) and the
`isVerified` / `accountStatus` fields on that claim.
