# Android release checklist

Android is the only mobile target. There is no iOS project. `web/` is the
Flutter web platform scaffold used by the admin website
([`lib/admin/`](../lib/admin/), see [ADMIN_WEB.md](ADMIN_WEB.md)) — the
customer/provider app has no web build.

## Blocking — must be done by a human

These cannot be scripted; they need credentials or assets only you have.

### 1. Signing keystore

The release build previously used `signingConfigs.getByName("debug")`. Play
rejects debug-signed uploads, and the debug keystore is shared by every Flutter
install on the machine, so it proves nothing about who published the app.

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (gitignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

`build.gradle.kts` picks it up automatically. **Without this file the release
build still succeeds but logs a warning and signs with the debug key** — check
the build output before uploading. Back the keystore up: losing it means you
can never update the app under the same listing.

### 2. Launcher icon

Still Flutter's default. Add a 1024×1024 source image and generate the
densities (`flutter_launcher_icons` or Android Studio's Image Asset tool),
including an adaptive icon for API 26+.

### 3. Rotate the leaked Gemini key

`.env` used to ship as a Flutter asset, so the key is recoverable from every
build already produced. Treat it as compromised regardless of when you deploy
the proxy. See [CONFIGURATION.md](CONFIGURATION.md).

### 4. Legal review

`lib/core/constants/legal_content.dart` contains drafts written to match what
the app actually does. They are **not legal advice**. Have counsel review the
Privacy Policy and Terms, and replace the `[Company legal name]` and
`[support@yourdomain.com]` placeholders.

### 5. Play Console data-safety form

Declare precise location, photos, name, email, phone, and device identifiers.
Note that descriptions and photo counts are sent to Google Gemini via our own
server, and photos are hosted on Cloudinary.

### 6. Upgrade the project to the Blaze plan

`fixwaala` is on the Spark (free) plan, and **Cloud Functions cannot be
deployed at all on Spark** — Functions v2 requires Cloud Build, Artifact
Registry, and Secret Manager, none of which Spark enables. Until this is done:

| Function | What is missing without it |
|---|---|
| `aiTriage` | AI assist falls back to the keyword classifier and shows the "AI assist is unavailable" banner. |
| `expandBroadcastRadius` | A request never widens past its initial 5 km. |
| `expireCandidateLeases` | Candidate leases never expire server-side. |
| `onOpenTicketCreated` / `onCandidateCreated` / `onJobStatusChanged` | No push notifications. |

The app degrades honestly in each case rather than breaking, so this is not a
blocker for testing — but it is a blocker for release. Blaze has a free tier;
set a budget alert when upgrading.

This is also why granting admin access is a local script
([`scripts/admin/`](../scripts/admin/README.md)) instead of an in-app "add
admin" button: that operation needs the Admin SDK too, and has the same
Cloud-Functions-need-Blaze ceiling as everything in the table above.

## Deploy the backend first

The app depends on rules, indexes, and functions being live. Deploy them
**before** distributing a build.

```bash
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm install && cd ..
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

Without the composite indexes the scoped listeners fail at runtime. Without the
scheduled functions, geo-broadcast never widens its radius and candidate leases
never expire.

## Build

```bash
flutter build appbundle --release \
  --dart-define=AI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/aiTriage \
  --dart-define=CLOUDINARY_CLOUD_NAME=<name> \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=<preset>
```

Use `appbundle` for Play; `apk` is for sideloading and testing.

## Pre-flight verification

- [ ] Build log does **not** contain "signing release with the DEBUG key".
- [ ] The red **DEMO MODE** banner does not appear — it means Firebase failed
      to initialise and nothing is being saved.
- [ ] Sign out, force-stop, relaunch: lands on role selection, not the previous
      account.
- [ ] A second account cannot see the first's tickets, jobs, or address.
- [ ] Privacy Policy and Terms open from both roles.
- [ ] A provider with `isVerified == false` shows **no** Verified badge.
- [ ] Push arrives with the app backgrounded.

## Known gaps

- **Payments are simulated.** No gateway; no money moves. The Terms say so.
- **The call handoff dials the real number**, not a masked proxy. Needs a
  telephony integration (Exotel/Twilio) before scale.
- **The "Verified" badge is a manual admin decision**, not an identity check.
  There is no Aadhaar or selfie capture anywhere in the app.
- **No automated test coverage of the Firestore paths or the rules.** The 67
  unit tests exercise in-memory service logic only.
