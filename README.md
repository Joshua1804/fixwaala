# Fixwaala

AI-assisted hyperlocal home-repair marketplace with trust-gated matching.
Android app (Flutter) + Firebase backend.

**The core promise:** a customer's exact address is never visible to anyone
until they personally confirm a provider. That is enforced in
[`firestore.rules`](firestore.rules), not just in the UI.

## How matching works

1. A customer describes a problem; AI triage classifies it and asks follow-ups.
2. The request is broadcast to nearby providers with matching skills, widening
   from 5 km → 10 km → 15 km if nobody accepts.
3. Providers who accept become **candidates** — the customer reviews their
   rating and history and confirms one.
4. Only at that moment is the exact address revealed, to that provider alone.

Providers searching see a **redacted projection** (`openTickets`) carrying the
customer's first name and an approximate location — never the full name,
street address, or precise coordinates.

## Getting started

```bash
flutter pub get
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=… --dart-define=CLOUDINARY_UPLOAD_PRESET=…
```

Configuration is passed with `--dart-define`, never a bundled `.env` asset —
see [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

Running without Firebase configured drops into **simulation mode**: everything
works but nothing persists. A red banner across the top says so.

## Layout

```
lib/
  core/            shared across features
    models/        AppUser, enums, UserFacingException
    services/      Firebase, account standing, session teardown, storage
    routes/        RouteNames + onGenerateRoute
    theme/         colors, spacing, radii, text styles
    widgets/       AsyncStateBuilder, RemoteImage, profile tabs, …
  features/<module>/{models,screens,services,widgets}
  home/            the two role shells
  admin/           the admin website — separate entry point, see below
functions/         Cloud Functions — AI proxy, schedules, push triggers
scripts/admin/     local operator scripts (grant admin access, delete a login)
```

Services are singletons: `ClassName._()` + `static final instance`, with a
`bool get _live => FirebaseService.instance.isInitialized` selecting between
Firestore and an in-memory fallback.

## Backend

Deploy before distributing a build — the app depends on all three.

```bash
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

| Function | Purpose |
|---|---|
| `aiTriage` | Holds the Gemini key server-side; authenticates callers by ID token. |
| `expandBroadcastRadius` | Widens the search on stalled tickets. |
| `expireCandidateLeases` | Releases leases when the review window closes. |
| `onOpenTicketCreated` / `onCandidateCreated` / `onJobStatusChanged` | Push. |

The two scheduled jobs exist because that logic used to run on `Timer.periodic`
inside a widget — so it stopped the moment the screen closed.

## Admin

**There is no admin UI in the Android app.** It's a separate Flutter Web
app at [`lib/admin/`](lib/admin/), run locally (not publicly hosted):

```bash
flutter run -t lib/admin/main_admin.dart -d chrome
```

`admin` is a Firebase custom claim, granted out of band with
[`scripts/admin/grant_admin_claim.js`](scripts/admin/README.md); the
Android app's `UserRole` has only `customer` and `provider` and nothing it
ships can obtain the claim.

The Android app *creates* moderation records; the website *reads and
resolves* them. See [docs/ADMIN_WEB.md](docs/ADMIN_WEB.md) for what it does,
and [docs/ADMIN_DATA_CONTRACT.md](docs/ADMIN_DATA_CONTRACT.md) for the
Firestore contract between the two.

## Testing

```bash
flutter analyze && flutter test
```

67 unit tests covering in-memory service logic. **They do not exercise the
Firestore paths or `firestore.rules`** — a rules-emulator suite is the highest
-value coverage still missing.

## Releasing

See [docs/RELEASE.md](docs/RELEASE.md). A signing keystore and a launcher icon
are still required and cannot be scripted.
