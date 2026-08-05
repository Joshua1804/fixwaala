#!/usr/bin/env node
/**
 * Grants or revokes the `admin` Firebase custom claim.
 *
 * This exists because the claim can only be set by the Firebase Admin SDK,
 * and the Admin SDK can only run somewhere trusted with a service-account
 * key — normally a Cloud Function. This project stays on the free Spark
 * plan, which cannot deploy Cloud Functions at all (v2 functions need a
 * billing account attached even at zero usage). So this one privileged
 * operation runs here instead: a script an operator runs by hand, from
 * their own machine, with a downloaded key that never leaves it.
 *
 * Nothing else about the admin website needs this. Once an account holds
 * the claim, its ID token carries `admin: true` on every subsequent
 * sign-in, and `firestore.rules` reads that token directly — every other
 * admin action (editing users, resolving reports, publishing announcements)
 * happens straight from the web app's client-side Firestore SDK, no server
 * involved.
 *
 * Setup:
 *   1. Firebase Console → Project settings → Service accounts →
 *      "Generate new private key". Save it as
 *      scripts/admin/service-account.json (gitignored — never commit it).
 *   2. cd scripts/admin && npm install
 *
 * Usage:
 *   node grant_admin_claim.js grant   someone@example.com
 *   node grant_admin_claim.js revoke  someone@example.com
 *   node grant_admin_claim.js list
 *   node grant_admin_claim.js verify  someone@example.com
 *
 * After granting or revoking, the affected account must sign out and back
 * in to the admin website — a custom claim only appears in a *new* ID
 * token, not the one already in the browser.
 */

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

const SERVICE_ACCOUNT_PATH = path.join(__dirname, "service-account.json");

function initAdmin() {
  if (fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    admin.initializeApp({
      credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
    });
    return;
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    return;
  }
  console.error(
    "No credentials found. Either place a service-account key at\n" +
      `  ${SERVICE_ACCOUNT_PATH}\n` +
      "or set GOOGLE_APPLICATION_CREDENTIALS to point at one.\n" +
      "See the setup instructions at the top of this file."
  );
  process.exit(1);
}

async function grant(email) {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, {
    ...(user.customClaims || {}),
    admin: true,
  });
  await admin
    .firestore()
    .collection("admins")
    .doc(user.uid)
    .set({
      uid: user.uid,
      email: user.email || email,
      displayName: user.displayName || null,
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
      grantedBy: "local-script",
    });
  console.log(`Granted admin to ${email} (${user.uid}).`);
  console.log(
    "They must sign out and back in to the admin website for it to take effect."
  );
}

async function revoke(email) {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, {
    ...(user.customClaims || {}),
    admin: false,
  });
  await admin.firestore().collection("admins").doc(user.uid).delete();
  console.log(`Revoked admin from ${email} (${user.uid}).`);
  console.log(
    "Their current session stays valid until the ID token naturally expires " +
      "(up to one hour) or they sign out."
  );
}

async function list() {
  const snap = await admin.firestore().collection("admins").get();
  if (snap.empty) {
    console.log(
      "No admins in the directory yet. Run `grant <email>` to create the first one."
    );
    return;
  }
  console.log(`${snap.size} admin(s):`);
  for (const doc of snap.docs) {
    const data = doc.data();
    console.log(`  ${data.email}  (${doc.id})`);
  }
}

async function verify(email) {
  const user = await admin.auth().getUserByEmail(email);
  const hasClaim = user.customClaims?.admin === true;
  const mirrorDoc = await admin.firestore().collection("admins").doc(user.uid).get();
  console.log(`${email} (${user.uid})`);
  console.log(`  Custom claim admin=true : ${hasClaim}`);
  console.log(`  admins/ directory entry : ${mirrorDoc.exists}`);
  if (hasClaim !== mirrorDoc.exists) {
    console.log(
      "  MISMATCH — the claim and the directory disagree. This should only " +
        "happen if a claim was changed outside this script. Re-run `grant` " +
        "or `revoke` to reconcile."
    );
  }
}

async function main() {
  const [command, email] = process.argv.slice(2);

  if (!command || !["grant", "revoke", "list", "verify"].includes(command)) {
    console.log(
      "Usage:\n" +
        "  node grant_admin_claim.js grant  <email>\n" +
        "  node grant_admin_claim.js revoke <email>\n" +
        "  node grant_admin_claim.js list\n" +
        "  node grant_admin_claim.js verify <email>"
    );
    process.exit(command ? 1 : 0);
  }
  if (command !== "list" && !email) {
    console.error(`"${command}" requires an email argument.`);
    process.exit(1);
  }

  initAdmin();

  try {
    if (command === "grant") await grant(email);
    else if (command === "revoke") await revoke(email);
    else if (command === "list") await list();
    else if (command === "verify") await verify(email);
  } catch (err) {
    console.error(err.message || err);
    process.exit(1);
  }
}

main();
