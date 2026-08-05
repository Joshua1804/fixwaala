#!/usr/bin/env node
/**
 * Deletes a Firebase Auth login by email.
 *
 * The admin website's "Delete" button on a user's profile removes their
 * Firestore documents (`users/{uid}`, and `providerPublicProfiles/{uid}` for
 * a provider) — that's a plain client-side Firestore write, which
 * `firestore.rules` allows `isAdmin()` to do directly, no server needed.
 *
 * It cannot also delete the underlying Firebase Auth account: deleting an
 * Auth user is an Admin SDK operation, same boundary as granting the admin
 * claim in `grant_admin_claim.js`. Run this afterwards to finish the job —
 * two steps because the platform draws the line there, not because this
 * project chose to.
 *
 * Setup: see scripts/admin/README.md (same service-account key as
 * grant_admin_claim.js).
 *
 * Usage:
 *   node delete_user.js someone@example.com
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
      "or set GOOGLE_APPLICATION_CREDENTIALS to point at one."
  );
  process.exit(1);
}

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.log("Usage: node delete_user.js <email>");
    process.exit(1);
  }

  initAdmin();

  try {
    const user = await admin.auth().getUserByEmail(email);
    if (user.customClaims?.admin === true) {
      console.error(
        `${email} currently holds admin access. Run ` +
          `"node grant_admin_claim.js revoke ${email}" first — deleting an ` +
          "admin's login without revoking the claim first leaves a stale " +
          "admins/ directory entry pointing at a uid that no longer exists."
      );
      process.exit(1);
    }
    await admin.auth().deleteUser(user.uid);
    console.log(`Deleted the Auth login for ${email} (${user.uid}).`);
    console.log(
      "Their Firestore profile should already be gone if you deleted it " +
        "from the admin website first. Their historical tickets, jobs, " +
        "and payments are untouched — see docs/ADMIN_WEB.md."
    );
  } catch (err) {
    console.error(err.message || err);
    process.exit(1);
  }
}

main();
