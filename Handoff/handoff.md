# Fixwaala — Handoff Notes

Last updated: 2026-07-25. For a module-by-module completion breakdown, see [project-status.md](project-status.md).

## What this is

A Flutter home-repair marketplace (plumbing/electrical/carpentry/etc.) with two user roles — customer and provider — plus an admin panel. Built as a 12-module college project (see `lib/core/routes/route_names.dart` for the module map). Backed by a real Firebase project (`fixwaala`): Auth + Firestore, with an in-memory simulation fallback that activates automatically whenever Firebase isn't configured.

## Running it

```bash
flutter pub get
flutter run -d chrome              # or an attached device
```

Firebase is already wired (`lib/firebase_options.dart`, project `fixwaala`) — no `flutterfire configure` needed unless you're pointing at a different project.

A `.claude/launch.json` exists for browser-preview tooling with `--web-port=8080 --web-hostname=localhost`; irrelevant if you're not using that tooling.

## Firebase project access

- Project: `fixwaala` (console: https://console.firebase.google.com/project/fixwaala)
- Firebase CLI is installed locally and logged in as `joshua.george@mca.christuniversity.in`. `firebase use fixwaala` links this folder (creates `.firebaserc`, currently gitignored/untracked — recreate with that command if missing).
- **`firestore.rules` and `firestore.indexes.json` live in this repo and are the source of truth** — deploy changes with:
  ```bash
  firebase deploy --only firestore:rules,firestore:indexes
  ```
  Both are currently deployed and live. If you edit either file, redeploy — local edits do nothing to the live project until you do.

## The core architectural pattern — read this before touching any service

Every backend-connected service (`TicketService`, `JobService`, `PaymentService`, `RatingService`) follows the same shape, established first in `TicketService` and extended to the others this session:

1. An in-memory cache (`Map`/`List`) is the **synchronous** source of truth for every read method — this is why `JobService.instance.jobById(id)` etc. can be called directly inside `build()` methods across dozens of screens without `async`/`FutureBuilder`.
2. A `bool get _live => FirebaseService.instance.isInitialized;` gate — `false` means Firebase isn't configured (or running in a test), and the service behaves as a pure in-memory simulation, exactly as it did before any Firestore work.
3. When `_live`, every mutation also fire-and-forget writes through to Firestore (`_persist(...)`, wrapped in try/catch that swallows `permission-denied` with a `debugPrint` so a rules problem degrades to "local-only" instead of crashing).
4. An `initialize()` method (called once from `main.dart` after `FirebaseService.instance.initialize()`) opens a `.snapshots()` listener on the whole collection that both hydrates the in-memory cache on cold start and keeps it live-synced afterward.

**If you add a new persisted entity, copy this pattern rather than inventing a new one.** It's what lets ~20+ existing call sites stay synchronous and unchanged while gaining real persistence.

## Known bugs / rough edges (priority order — see project-status.md for full detail)

1. **`JobService.initialize()`'s Firestore listener has no `onError` handler** (`job_service.dart:52`). Any listener error would silently hang every job-watching screen on a loading spinner forever. Small, safe fix — add an `onError` callback that at minimum `debugPrint`s. Not yet done.
2. **`my_tickets_screen.dart:90`** reads a Firestore stream as `snapshot.data ?? []` with no `snapshot.hasError` check — a backend failure looks identical to "no tickets." The same pattern was already fixed in `customer_home_screen.dart` and `provider_home_screen.dart`; this file was missed.
3. **Provider identity isn't threaded through to 5 provider-dashboard screens** — `provider_dashboard_screen.dart`, `earnings_screen.dart`, `trust_score_screen.dart`, `performance_screen.dart`, `active_jobs_screen.dart` all hardcode `AppConstants.demoProviderId` instead of `AuthService.instance.currentUser()?.id`. A real signed-in provider currently sees the demo account's numbers.
4. **Two "fake identity" fallbacks can tag Firestore docs with a non-real owner**: `matching_service.dart:62` (`customerId ?? 'demo-customer'`) and `provider_home_screen.dart`'s `_OpportunityTicketCardState._accept()` (`?? AppConstants.demoProviderId`). This already caused one real bug this session (a job permanently un-writable because its `providerId` field was the literal demo string, never matching any real Firebase Auth UID) — currently worked around by loosening `firestore.rules` rather than fixing the identity flow itself. Worth fixing properly.
5. **`GeoBroadcastService` is a complete stub** (`findEligibleProviders` returns `const []`, `notifyProviders` is a no-op) — Module 5's actual feature (geo-filtered provider discovery + push notify) doesn't exist. The app works around it: providers just browse all `matching`-status tickets directly.
6. **`AccountService`, `ReportService`, `AdminService` are pure in-memory** — admin moderation actions, reports, and SOS alerts are lost on reload and never sync across devices/sessions. Same fix pattern as above (§ Core architectural pattern) would apply if/when persistence matters for these.

## Firestore collections in use

`users`, `tickets`, `jobs`, `payments`, `ratings` — all five have matching `match` blocks in `firestore.rules`; verified with no gaps as of this session. If you add a new collection, add its rule before shipping or every read/write will silently permission-deny.

## Testing

```bash
flutter test          # 62 tests, all passing as of this session
flutter analyze        # clean except a handful of pre-existing lint infos (unnecessary_underscores etc.)
```

Tests only exercise the in-memory (`_live == false`) branch of every service — there is no rules-emulator test and nothing exercises the live Firestore path or `firestore.rules` directly. If you're debugging a "works in tests, breaks live" issue, that gap is almost certainly why — check the live rules/indexes before assuming a code bug (this happened twice this session: a missing composite index and an overly strict rule, both invisible to `flutter test`).

## Design system

Deep-green/sage/gold visual system (`lib/core/theme/`: `app_colors.dart`, `app_radii.dart`, `app_shadows.dart`, `app_durations.dart`, `app_spacing.dart`, `app_text_styles.dart`). Use these tokens rather than literal colors/radii/durations — the whole app was migrated to them and new code should follow suit. A `FloatingNavBar` (`lib/core/widgets/floating_nav_bar.dart`) replaced the old edge-to-edge `BottomNavigationBar` — icon-only by design (a labeled variant was tried and reverted for looking cramped on mobile).
