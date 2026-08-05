# Admin bootstrap scripts

Two one-off operator scripts for the two things the admin website's
client-side code cannot do for itself, because both require the Firebase
Admin SDK — and the Admin SDK needs either a Cloud Function (this project
stays on the free Spark plan, which cannot deploy those at all) or a trusted
machine with a service-account key. These scripts are that trusted machine:
you, running them locally.

- **`grant_admin_claim.js`** — grants/revokes who can sign in to the admin
  website at all.
- **`delete_user.js`** — finishes deleting a user: the website's own "Delete"
  button removes their Firestore profile (a plain client-side write, no
  script needed), but only the Admin SDK can delete the underlying Firebase
  Auth login.

Everything else the admin website does — editing users, resolving reports,
publishing announcements, suspending accounts — happens directly from the
browser once your account holds the claim. These scripts only exist for what
that can't reach.

## Setup (one time)

1. Firebase Console → **Project settings → Service accounts → Generate new
   private key**. This downloads a JSON file.
2. Save it as `service-account.json` **in this folder**
   (`scripts/admin/service-account.json`). It is gitignored — double-check
   `git status` never shows it before committing anything.
3. ```bash
   cd scripts/admin
   npm install
   ```

## Usage

```bash
# Make yourself (or anyone) an admin
node grant_admin_claim.js grant you@example.com

# Remove admin access
node grant_admin_claim.js revoke someone@example.com

# See who currently has it
node grant_admin_claim.js list

# Check the claim and the directory agree
node grant_admin_claim.js verify you@example.com
```

**After granting or revoking, sign out and back in to the admin website.**
A custom claim only shows up in a *new* ID token — the one already sitting in
the browser from a previous sign-in won't have it.

## What this actually does

Two things, in one run of `grant`:

1. Sets `{ admin: true }` as a custom claim on the account's Firebase Auth
   user record. This is what `firestore.rules` checks (`isAdmin()`) to allow
   every privileged read/write across the app.
2. Writes a matching document to `admins/{uid}` in Firestore — a read-only
   directory the admin website's **Admins** screen displays. The website
   cannot write this collection itself (rules deny it outright); only this
   script, running with a service-account key that bypasses rules entirely,
   can.

`revoke` does the reverse: flips the claim to `false` and deletes the
directory entry, in one run, so the two never drift apart. If they ever do —
say, a claim was hand-edited in the Firebase Console — `verify` will tell you.

## This account needs to exist first

The script looks the user up by email via `admin.auth().getUserByEmail()`, so
they must have already signed up through the Fixwaala app (or been created
directly in Firebase Auth) before you can grant them admin access.
