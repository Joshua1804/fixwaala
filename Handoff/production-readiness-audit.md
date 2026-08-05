# Fixwaala — Production Readiness Audit

**Date:** 2026-08-03
**Scope:** Full application — Flutter client (`lib/`, ~20k LOC), Firebase backend (Auth, Firestore, rules, indexes), Android/web platform config, external integrations (Gemini, Cloudinary), test suite.
**Method:** Every Dart file read; all 47 routes traced to their entry points; all 12 service singletons traced from UI call site to persistence; `firestore.rules` + `firestore.indexes.json` reviewed against actual queries; `flutter analyze` and `flutter test` executed.

## Baseline health

| Check | Result |
|---|---|
| `flutter analyze` | 9 issues, all `info` (lint style only). No errors or warnings. |
| `flutter test` | 77/77 passing (~12s). |
| Architecture | Clean feature-first layout, consistent service-singleton pattern, well-documented. |
| Design system | Real token system (colors, spacing, radii, shadows, durations, text styles) — genuinely good foundation. |

**The code compiles cleanly and the tests pass. That is not the same as production-ready.** The tests only exercise the in-memory fallback paths, never Firestore. The critical gaps are in what is *not* covered: security rules, session handling, ticket lifecycle completion, and roughly a dozen UI actions that display a success message without performing the action.

## Top-line verdict

**Not deployable in its current state.** Five findings are release-blocking on their own:

1. **Firestore rules grant every signed-in user read access to every customer's exact home address** and write access to every job, payment, and rating in the system (`SEC-01`). This directly defeats the app's core "trust-gated" privacy promise.
2. **Admin access is gated by a hardcoded credential pair compiled into the client**, with no route guard on `/admin/*` (`SEC-02`).
3. **Sign Out does not sign the user out** — it only navigates (`SEC-03`).
4. **Every device downloads the entire `jobs`, `payments`, and `ratings` collections** on startup (`BE-01`). This is both a privacy leak and an O(all-users) cost curve.
5. **There is no iOS project, and the Android release build is signed with the debug key** (`BE-16`, `BE-17`).

Beyond those, the app has a substantial class of "theatre" bugs — UI that reports success for work it never did. Profile editing, provider verification, moderation actions, and the ticket lifecycle all fall into this category.

---

# 1. Frontend

### FE-01 · Critical — Profile "Save Changes" discards the edit and reports success
`lib/home/customer_home_screen.dart:1234` and `lib/home/provider_home_screen.dart:876`

`_handleSave()` calls `widget.user!.copyWith(name: …, phone: …)` and **throws the returned object away**. It then shows "Profile updated successfully" and exits edit mode. Nothing is written to `AuthService`, nothing reaches Firestore. Re-opening the tab shows the old values.

**Why it matters:** The user is actively lied to about their own data. Any support workflow built on "ask the user to update their phone number" is broken.
**Fix:** Add `AuthService.updateProfile({name, phone})` (Firestore `users/{uid}` update + `_currentUser` refresh, mirroring the existing `updateProviderProfile`). Await it, show the snackbar only on success, surface errors inline.
**Depends on:** none.

### FE-02 · Critical — `TextEditingController`s are reset on every rebuild
`customer_home_screen.dart:1194`, `provider_home_screen.dart:835`

`_nameController.text = user.name` runs *inside* the `FutureBuilder` builder. Any rebuild (keyboard open, theme change, tab switch) wipes what the user typed and resets the cursor.

**Why it matters:** Editing is effectively impossible even after FE-01 is fixed.
**Fix:** Seed controllers once — hoist the user load to `initState`/a cached future and populate in a `then`, or gate on a `_seeded` flag.
**Depends on:** FE-01 (fix together).

### FE-03 · High — `FutureBuilder(future: AuthService.instance.currentUser())` constructed inside `build()`
17 occurrences across home screens, dashboards, rating, report, SOS, verification, job tracking.

A new `Future` is created on every rebuild, so the builder re-runs, re-fires the Firestore `users/{uid}` read, and flashes back through its loading state. On the customer home screen this happens on every scroll frame that triggers a rebuild.

**Why it matters:** Redundant network reads (billable), visible flicker, and non-deterministic UI. It is the single most repeated anti-pattern in the codebase.
**Fix:** Introduce a `Stream<AppUser?> currentUserStream` on `AuthService` (backed by `authStateChanges` + the Firestore doc snapshot) and consume it via a single `StreamBuilder` high in the tree, or cache the future in `initState`. Prefer the stream — it also fixes staleness after profile edits.
**Depends on:** none. Unblocks FE-01/FE-02 and BUG-14.

### FE-04 · High — Customer "History" tab wired to the wrong query
`customer_home_screen.dart:947`

`_HistoryTicketsView` calls `JobService.instance.completedJobsForProvider(customerId)` — a **provider** lookup, passed a **customer** id. It always returns `[]`. The result is assigned to `pastJobs`, used only in an `isEmpty` guard, and never rendered.

**Why it matters:** Dead, misleading code that hides the intended "past jobs" feature.
**Fix:** Add `JobService.completedJobsForCustomer(customerId)` and render it, or delete the block. Note this is masked today by BUG-02 (no ticket ever becomes historical anyway).
**Depends on:** BUG-02 for the feature to be observable.

### FE-05 · High — Active tickets list double-renders the in-flight request
`customer_home_screen.dart:902`

The list prepends `_ActiveJobCard(activeJob)` and then renders every active ticket — including the very ticket that job belongs to. The user sees the same request twice with two different status vocabularies (`JobStatus` vs `TicketStatus`).

**Fix:** Filter `active` to exclude `t.id == activeJob.ticketId`.

### FE-06 · High — Twelve navigation targets are `onTap: () {}`
Help & Support, About Fixwaala, Change Password, Email Verification Status, Privacy Policy, Terms of Service (×2 roles = 12 tiles), the notification bell on both home headers, and the admin "Matching failures" tile.

**Why it matters:** Privacy Policy and Terms of Service are **store-submission requirements** — Google Play rejects apps without them. The rest read as broken to any evaluator.
**Fix:** Build a shared `StaticContentScreen` (markdown/asset-backed) for Privacy/Terms/About/Help; route Change Password to a re-auth + `updatePassword` flow; route Email Verification Status to the existing `emailVerification` route; build a notifications inbox or remove the bell.
**Depends on:** legal copy for Privacy/Terms.

### FE-07 · High — Search bar and voice-search icon are decorative
`customer_home_screen.dart:305-364`

The search field is a `GestureDetector` that pushes `createTicket`. The mic icon is a static `Icon` inside a `Container` — not a button, not wired to anything.

**Fix:** Either implement category/service search (filter the grid + popular services), or replace the affordance with an honest "Request a repair" CTA. Do not ship a fake search field. Remove the mic or wire `speech_to_text`.

### FE-08 · Medium — Category grid discards the tapped category
`customer_home_screen.dart:544`

`_handleTap(index)` navigates to `createTicket` with no arguments. The user picks "Plumbing", then the AI re-derives the category from free text.

**Fix:** Pass the selected `ServiceCategory` through as a route argument and pre-seed it in `CreateTicketScreen` → `AiAssistScreen`.

### FE-09 · Medium — Web build is broken for the photo flow
`create_ticket_screen.dart:1` imports `dart:io` and uses `File`; `cloudinary_service.dart` takes a `File`.

`dart:io` is unavailable on web. A `web/` target exists and `build/web/` artifacts are checked in, so web is an intended platform.

**Fix:** Switch to `XFile` + `readAsBytes()` and use `http.MultipartFile.fromBytes`, which works on all platforms. Same for the (currently stubbed) selfie capture.
**Depends on:** BUG-10 if selfie capture is implemented at the same time.

### FE-10 · Medium — No pull-to-refresh anywhere
Tickets, jobs, dashboard, earnings, admin lists all lack `RefreshIndicator`. Several (admin dashboard, audit events, verification status) are one-shot `FutureBuilder`s with no way to re-fetch short of leaving and re-entering the screen.

**Fix:** Wrap the primary scrollables in `RefreshIndicator`; convert one-shot admin `FutureBuilder`s to streams or add explicit refresh.

### FE-11 · Medium — Responsiveness is inconsistent between roles
`CustomerHomeScreen` has a `LayoutBuilder` + `NavigationRail` at ≥900px. `ProviderHomeScreen` has neither — it renders a phone-width `FloatingNavBar` on desktop/tablet/web. No screen sets a `maxWidth` constraint, so forms stretch edge-to-edge at 1920px. `_PopularServicesSection` hardcodes `height: 200`, which clips at large text scales.

**Fix:** Extract the customer's wide-layout shell into a reusable `AdaptiveScaffold` and apply it to both roles. Add `ConstrainedBox(maxWidth: 640)` to form screens. Replace fixed heights with intrinsic sizing.

### FE-12 · Medium — Dark mode has hardcoded light-only colors
`AppColors.textPrimary` (`#0F2515`, near-black green) is used unconditionally for unselected theme-option labels (`customer_home_screen.dart:1593`, `provider_home_screen.dart:1243`) and in `service_category_tile.dart:110`. On `scaffoldDark` (`#0A1610`) that is effectively invisible. `NavigationRail` hardcodes `backgroundColor: AppColors.surface` (pure white). The search bar hardcodes `AppColors.surface`.

**Fix:** Route every color through `Theme.of(context).colorScheme` / `textTheme`, or add dark variants to the token file. Audit all 17 sites flagged by `grep -rn "AppColors.textPrimary\|AppColors.surface" lib/`.

### FE-13 · Medium — 20k LOC with three `Semantics` widgets
Only `customer_home_screen.dart` (2) and `service_category_tile.dart` (1) carry semantics. No `semanticLabel` on any decorative-vs-meaningful icon. Star-rating `IconButton`s in `rating_screen.dart` have no labels — a screen reader announces five identical unlabeled buttons. No `Focus` management on multi-step forms. Text scaling untested (several fixed-height containers will clip).

**Fix:** A dedicated accessibility pass — label all interactive icons, add `Semantics(value:)` to the rating control, verify contrast ratios against WCAG AA (the sage `#8FAF93` on white is ~2.1:1, below the 4.5:1 minimum), and test at 200% text scale.

### FE-14 · Medium — Two 1,600-line home screens
`customer_home_screen.dart` (1,682) and `provider_home_screen.dart` (1,567) each contain 10+ private widget classes, including two near-identical copies of the profile/settings tab (`_ProfileContent`/`_ProviderProfileContent`, `_SettingsContent`/`_ProviderSettingsContent`, `_ProfileTile`/`_ProviderProfileTile`, `_buildThemeOption` ×2, `_formatDate` ×2 across three files).

**Why it matters:** Every bug in this file is a *pair* of bugs (FE-01 and FE-02 each exist twice, and were fixed nowhere). Merge conflicts are guaranteed with parallel agents.
**Fix:** Extract shared `ProfileTab`, `SettingsTab`, `ProfileTile`, `ThemeOptionSelector`, and a `RelativeTime.format()` helper into `core/widgets/`. Split each home screen into `home/<role>/tabs/*.dart`.
**Depends on:** should land **before** other frontend work to avoid conflicts.

### FE-15 · Low — Performance
- `JobService.activeJobForCustomer` / `allJobsForProvider` do a full linear scan of the in-memory map inside `build()`, re-running on every stream tick (see BE-01 — that map holds *every job in the system*).
- `_ActiveTicketPreview` rebuilds on `watchAllChanges()` — i.e. on any job change anywhere, for any user.
- `Image.network` at three sites has no `cacheWidth`, `loadingBuilder`, or `errorBuilder` (see BUG-11).
- No `const` on many static subtrees; `_popularServices` cards rebuild on each parent rebuild.

**Fix:** Index jobs by `customerId`/`providerId` in `JobService`; scope `watchAllChanges` to a per-user filtered stream; add `cacheWidth` + builders to all remote images.

### FE-16 · Low — Missing screens
Notification inbox/history; in-app chat or call between confirmed customer and provider (currently zero communication channel after matching); saved addresses management; payment method management; provider availability/schedule editor (collected at onboarding, never editable); customer-side provider favorites; onboarding/tutorial for first-run.

---

# 2. Backend

### BE-01 · Critical — Every client subscribes to the entire `jobs`, `payments`, and `ratings` collections
`job_service.dart:52`, `payment_service.dart:37`, `rating_service.dart:44` — all call `_col.snapshots()` with **no `where` clause**.

Every device, on startup, downloads and holds in memory every job, every payment record, and every rating created by every user of the platform. `AdminService.dashboardSummary()` and `ActiveTicketsScreen` then read from that same local cache.

**Why it matters:** Simultaneously a data-privacy breach (a customer's device holds every other customer's job history, provider names, and payment amounts), a cost problem (Firestore bills per document read; this is O(users²)), and a memory/startup-latency problem that grows without bound.
**Fix:** Scope each listener to the signed-in user — `where('customerId', isEqualTo: uid)` / `where('providerId', isEqualTo: uid)`, subscribed *after* auth resolves and re-subscribed on user change. Add the matching composite indexes. Move admin aggregates to a server-side counter document or a Cloud Function, not a client scan.
**Depends on:** SEC-01 (rules must enforce the same scoping server-side).

### SEC-01 · Critical — Firestore rules are effectively "any signed-in user can read and write anything"
`firestore.rules`

| Rule | Actual effect |
|---|---|
| `users/{userId}` → `allow read: if isSignedIn()` | Any account can read **every** user's phone, home address, pincode, `aadhaarNumber`, `selfieUrl`, and live GPS location. |
| `tickets/{id}` → `allow read: if isSignedIn()` | Any account can read **every** ticket's `exactLocation` — the customer's precise home coordinates. This is the exact thing the product promises to protect. |
| `tickets/{id}` → `allow update: if isSignedIn()` | Any account can reassign any ticket to themselves, or flip its status. |
| `jobs/{id}` → `allow write: if isSignedIn()` | Any account can advance, cancel, or mark-paid any job in the system. |
| `payments/{id}` → `allow write: if isSignedIn()` | Any account can forge payment records → forge provider earnings. |
| `ratings/{id}` → `allow write: if isSignedIn()` | Any account can write unlimited 5-star ratings for themselves → forge trust score. |

No rules exist at all for `reports`, `safetyAlerts`, `accounts`, or `auditEvents` (those live only in memory today — see BE-04).

**Why it matters:** This is the single most severe finding. The app's entire value proposition is address privacy and a trustworthy reputation system; the rules protect neither. A trivially-obtained auth token reads the home address of every customer on the platform.
**Fix:** Rewrite the rules with per-document ownership:
- `users/{uid}`: full read/write only for `uid == request.auth.uid`. A separate **public** subset (display name, skills, aggregate rating, verification status) readable by others — either a `users/{uid}/public/profile` doc or a mirrored `providerPublicProfiles` collection. Never expose `aadhaarNumber`, `phone`, address, or `liveLocation` broadly.
- `tickets`: readable by `customerId`, by the `assignedProviderId`, and — for `status == 'matching'` only — a redacted broadcast projection that omits `exactLocation`, `customerName`, and `addressLine`. Move `exactLocation` to a subcollection readable only by the assigned provider.
- `jobs`/`payments`/`ratings`: read+write only by the job's `customerId` or `providerId`; validate status transitions and immutable fields (`jobId`, `createdAt`, `providerId`) in the rules.
- `ratings`: enforce one-per-`(jobId, fromUserId)` via a deterministic document id.
- Admin access via a custom claim (`request.auth.token.admin == true`), never a client-side check.
Add a rules-emulator test suite (`@firebase/rules-unit-testing`) covering each denial case.
**Depends on:** BE-01 (client queries must be scoped to match), SEC-02 (admin claim).

### SEC-02 · Critical — Admin authentication is a hardcoded constant in the shipped binary, with no route guard
`app_constants.dart:20` (`demoAdminEmail = 'admin@fixwaala.com'`, `demoAdminPassword = 'admin123'`), checked client-side in `admin_service.dart:23`.

Entry is a hidden 5-tap on the role-selection logo (`role_selection_screen.dart:35`). Worse, **the login is not required at all** — `AppRouter` maps `/admin/dashboard`, `/admin/accounts`, `/admin/reports`, `/admin/audit` etc. with no guard, and `AuthService.resolveInitialRoute()` will route any user whose Firestore `role` field says `admin` straight in. There is no admin session state, no sign-out on the admin dashboard, and `AdminService.loginWithCredentials` returns `false` for every real credential (the Firebase path is a `TODO`).

**Why it matters:** Anyone who decompiles the APK (or reads this repo) has admin access to account suspension and the audit log. Anyone who can deep-link into a route bypasses even that.
**Fix:** Firebase Auth + a custom claim set by a Cloud Function/admin SDK; a `RouteGuard` in `onGenerateRoute` that rejects `/admin/*` without the claim; enforce the same claim in `firestore.rules`; delete the demo constants; add admin sign-out. Keep the 5-tap easter egg only if it leads to a real login.
**Depends on:** SEC-01 (shared claim model).

### SEC-03 · Critical — Sign Out does not sign out
`customer_home_screen.dart:1554`, `provider_home_screen.dart:1204`

```dart
onTap: () => Navigator.of(context).pushReplacementNamed(RouteNames.roleSelection),
```
`AuthService.instance.signOut()` is never called. The Firebase session, the static `_currentUser` cache, and all Firestore listeners stay alive. Navigating back to `/customer/home` — or simply restarting the app, since splash calls `resolveInitialRoute()` — lands straight back in the previous user's account.

**Why it matters:** On a shared or lost device, "signing out" leaves the account fully open. It also makes multi-account testing unreliable.
**Fix:** `await AuthService.instance.signOut()`, cancel every service listener (`JobService`/`PaymentService`/`RatingService`/`ProviderPresenceService`), clear in-memory caches, then `pushNamedAndRemoveUntil(roleSelection)`. Add a confirmation dialog. The correct pattern already exists at `email_verification_screen.dart:132` — reuse it.

### SEC-04 · High — Gemini API key is shipped inside the app bundle
`pubspec.yaml:52` declares `.env` as a Flutter **asset**. `.env` currently contains a live `GEMINI_API_KEY` (and Cloudinary credentials). Assets are plain files inside the APK/web bundle — `unzip app.apk` recovers the key in seconds. `build/flutter_assets/.env` is already on disk as proof.

**Why it matters:** Extractable key = unbounded third-party billing against your account, and no way to revoke per-user.
**Fix:** Move the Gemini call behind a Cloud Function / Cloud Run endpoint that holds the key server-side and authenticates the caller with their Firebase ID token. Rotate the current key — treat it as compromised. Cloudinary unsigned upload presets are lower-risk but should be rate-limited and folder-scoped; prefer signed uploads via the same backend.

### SEC-05 · High — Aadhaar verification always succeeds by construction
`verification_service.dart:12` — `verifyAadhaarSandbox()` sleeps 1s and `return true`. `runSelfieChecks()` returns `(liveness: true, faceMatch: true)`. `uploadSelfie()` returns the literal string `'https://placeholder/selfie.jpg'`.

Meanwhile the customer-facing UI renders **"Aadhaar + Selfie verified"** with a green check (`provider_review_screen.dart:220`, `provider_profile_screen.dart:123`), and `provider_home_screen.dart:927` renders `StatusBadge.verified()` **unconditionally**, regardless of the provider's actual `verificationStatus`.

**Why it matters:** The app displays an identity-verification claim it has not performed, to a customer who is deciding whether to let a stranger into their home. That is the highest-consequence false statement in the product.
**Fix:** Until a real KYC provider (Signzy / Karza / IDfy / UIDAI-authorised AUA) and a real liveness/face-match service are integrated, **remove every "verified" badge** or relabel it honestly ("Identity check pending"). Then: real KYC integration, real image upload, admin review queue. Also see BE-05 — the verification result is never persisted anyway.
**Depends on:** BE-05, vendor selection/commercials.

### BE-02 · Critical — The ticket lifecycle never completes
Grep confirms `TicketService.updateStatus` is called from exactly three places, and the furthest a ticket ever advances is `TicketStatus.assigned`. `TicketStatus.providerEnRoute`, `providerArrived`, `underInspection`, `awaitingEstimateApproval`, `inProgress`, `completed`, `paid`, and `closed` are **defined, styled in `TicketStatusUi`, and never assigned**. `cancelTicket()` has zero call sites.

Because `Ticket.isActive` returns true for everything except `completed/paid/closed/cancelled/failed`, **every ticket a customer ever creates stays "active" forever**. The History tab is permanently empty. The Active tab grows without bound.

**Why it matters:** The customer-facing record of their own service history does not exist. Combined with FE-04, the entire "past requests" feature is non-functional.
**Fix:** Mirror `JobStatus` transitions onto the parent ticket inside `JobService._commit` (or via a Cloud Function trigger on `jobs/{id}`, which is more robust). Wire `cancelTicket()` to a customer-facing "Cancel request" action on the matching screen and the ticket card.
**Depends on:** none. Blocks FE-04.

### BE-03 · Critical — Module 2 (Provider Verification) is entirely orphaned
- `VerificationService.submitForAdminReview()` — the **only** method that writes `verificationStatus` to Firestore — has **zero call sites**.
- `RouteNames.aadhaarEntry` has zero navigations outside the router. The flow is unreachable from the UI. `verification_status_screen.dart` has no "Start verification" button.
- `RouteNames.adminVerificationReview` has zero navigations — the admin dashboard never links to it.
- `ProviderVerificationReviewScreen` renders three hardcoded fake providers (`'Provider 1'`, `'XXXX-XXXX-120'`).
- `AdminService.reviewProviderVerification()` is an empty method body with a `TODO`.

So: providers cannot start verification, the status is never written, and admins cannot review it. `VerificationService.status()` therefore returns `pending` for everyone — which is why the unconditional `verified` badge (SEC-05) is so damaging.

**Fix:** Full module rebuild — entry point from provider onboarding + profile, real capture and upload, `submitForAdminReview` wired in, admin queue backed by a Firestore query on `users where verificationStatus == pending`, `reviewProviderVerification` implemented with an audit event, and the dashboard link added.
**Depends on:** SEC-05 (vendor), BE-04 (persisted audit log), FE-09 (cross-platform image upload).

### BE-04 · Critical — Reports, safety alerts, moderation, and the audit log are in-memory only
`ReportService` (`List<Report> _reports`), `AccountService` (`Map<String, AccountStatus> _status`), `AdminService` (`List<AuditEvent> _auditLog`) — none touch Firestore.

Consequences:
- A customer's SOS **never reaches an admin**. It exists only in the RAM of the device that raised it, and is gone on app restart. The SOS screen tells the user "Our admin team has been alerted."
- Account suspensions evaporate on restart. `AccountService.assertActive()` — called at the top of every job transition, payment, and rating — therefore enforces nothing across sessions.
- The audit log has no durability, which defeats its purpose.
- `AccountService.allAccounts()` reads `AuthService.knownDemoUsers()`, which **returns `const []` whenever Firebase is configured**. So in production the admin Account Management screen is permanently empty and no one can be moderated at all.

**Why it matters:** SOS is a safety feature. Telling a user in distress that help has been alerted, when nothing was sent, is the most serious functional failure in the app.
**Fix:** Firestore-back all three: `reports/`, `safetyAlerts/`, `accountStatus/`, `auditEvents/` collections with live listeners and admin-only rules. Rewrite `AccountService.allAccounts()` to query the `users` collection. Add real-time admin notification for SOS (FCM to an admin topic) and, at minimum, a documented escalation path with local emergency numbers surfaced on the SOS screen itself.
**Depends on:** SEC-01 (rules), SEC-02 (admin identity).

### BE-05 · High — No push notification backend
`NotificationService` uses `flutter_local_notifications`, fired from a `StreamBuilder` on the *foreground* device. `firebase_messaging` is commented out in `pubspec.yaml`. `AndroidManifest.xml` lacks `POST_NOTIFICATIONS`, so on Android 13+ even the local notifications are silently suppressed.

Practical effect: a provider only learns about a nearby job **while the app is open and they are staring at it**. A customer only learns a provider accepted while the matching screen is foregrounded. This is the difference between a demo and a marketplace.

**Fix:** FCM + a Cloud Function on `tickets` create/update and `candidates` create. Token registration per device, topic subscription by role/geo. Add `POST_NOTIFICATIONS` and the runtime permission request. Wire the existing `AppPreferencesService.notificationsEnabled` toggle to actually gate delivery (today it gates nothing).

### BE-06 · High — Geo-broadcast expansion only runs while one screen is open
`GeoBroadcastService.runBroadcast()` starts a `Timer.periodic` in the stream's `onListen` and cancels it in `onCancel`. That stream is only listened to by `MatchingScreen`. If the customer backs out or backgrounds the app, the radius never expands past 5 km and the ticket never transitions to `failed` — it stays `matching` forever, invisible to providers 6 km away.

Similarly, `CandidateLease.expiresAt` is only enforced by a `Timer` inside `ProviderReviewScreen` (`_handleExpired`). Close the screen and leases never expire; providers stay pinned as pending candidates indefinitely.

**Fix:** Move both to scheduled Cloud Functions (a Firestore-triggered function plus Cloud Tasks / a cron sweep on `tickets where status == matching`). This is server-owned business logic; it cannot live in a widget's lifecycle.
**Depends on:** Cloud Functions project setup.

### BE-07 · High — No transactions anywhere; matching is race-prone
`MatchingService.confirmProvider()` performs four sequential un-batched writes (assign ticket → read candidates → update each candidate → create job). If the app dies midway, the ticket is `assigned` with no `Job`, or candidates are half-updated. Two customers confirming near-simultaneously, or a double-tap on "Confirm this provider", creates duplicate jobs — nothing guards against it.

`JobService` transitions are read-modify-write against a local cache, then `set()` the whole document. Two devices acting on the same job last-write-wins, silently discarding a transition.

**Fix:** `runTransaction` / `WriteBatch` for `confirmProvider`. Server-side status-transition validation in rules or a Cloud Function. Disable the confirm button after first tap. Use `update()` with field-level writes rather than whole-document `set()`.

### BE-08 · High — Ticket address is never captured
`ticket_review_screen.dart:69` reads `args['address']`, but nothing in the flow ever puts `address` into those args — `CreateTicketScreen` doesn't collect it, `AiAssistScreen` doesn't forward it. `LocationService.reverseGeocode()` exists and is **never called**. The customer's onboarding address (`CustomerProfile.addressLine/city/pincode`) is collected and never used.

Result: `Ticket.addressLine` is always null. The provider gets GPS coordinates and nothing else — no flat number, no landmark, no gate code.

**Fix:** In the review step, default to the customer's saved address, offer "use current location" with `reverseGeocode`, and allow an address-detail override. Persist to `addressLine`; reveal only after confirmation (alongside `exactLocation`).

### BE-09 · Medium — Preferences and local storage are not persisted
`StorageService` is a stub — every method is an empty body or `return null`. `AppPreferencesService.initialize()` hardcodes defaults with a `TODO`. Theme choice, notification toggle, and language reset to system defaults on every launch. `AppPreferencesService.dispose()` is never called.

**Fix:** Add `shared_preferences` (already listed, commented out) and implement both. Wire `language` to real localization or remove it.

### BE-10 · Medium — No error handling on two of the three Firestore listeners
`JobService.initialize()` correctly has an `onError` handler. `PaymentService.initialize():37` and `RatingService.initialize():44` do **not** — a stream error there kills the listener silently, and earnings/ratings freeze at their last value with no console signal and no UI indication.

Also: `_persist()` swallows `permission-denied` **only in `kDebugMode`** and returns success, so in debug the UI reports a write that never happened. In release it rethrows into an unhandled `unawaited()` future.

**Fix:** Add `onError` to both listeners. Replace the debug-only swallow with a consistent, surfaced error path (retry queue + user-visible "couldn't save" state).

### BE-11 · Medium — Null-assertion crash in the simulation path
`ticket_service.dart:106` — `return Stream.value(_memStore[ticketId]!)`. Any unknown id throws synchronously. Two screens already work around this with `try/catch` wrappers (`job_details_screen.dart:30`, `provider_opportunity_screen.dart:36`) — the workaround is documented in comments rather than the bug being fixed. `matching_service.dart:54` calls it unguarded.

**Fix:** Return `Stream.error(StateError(...))` or an empty stream; delete the two workarounds.

### BE-12 · Medium — `AiAssistScreen` errors are invisible
`GeminiAiService` returns `null` on every failure (no key, timeout, HTTP error, malformed JSON) and `AiClassifierService` silently degrades to the 18-keyword rule engine. The user is never told the AI is unavailable — they just get generic questions and a low-confidence category. There is no retry, no "skip AI" escape hatch, and if `_run()` throws the screen hangs on the loading spinner forever (`_step` never leaves `loadingInitial`).

**Fix:** Surface a non-blocking "AI assist unavailable — continue manually" banner, add retry, add a `try/catch` around `_run()`/`_runFinal()` that lands on an error state with a manual-category fallback.

### BE-13 · Medium — Platform fee is defined and never applied
`AppConstants.platformFeePercent = 0.05` has exactly one reference: its own declaration. Payments charge the full estimate; `AnalyticsService` credits the provider 100% of it. There is no revenue model in the code, no fee line on the payment screen, and no payout ledger.

**Fix:** Decide the commercial model, then apply the fee at payment time, show it as a line item, and split gross/net in earnings.

### BE-14 · Medium — Missing indexes and query gaps
`firestore.indexes.json` covers three `tickets` composites. Once BE-01 scopes the job/payment/rating listeners, you will need composites for `jobs (customerId, createdAt)`, `jobs (providerId, status, createdAt)`, `payments (jobId)`, `ratings (toUserId, createdAt)`, and — after BE-04 — `reports (status, createdAt)` and `safetyAlerts (resolved, raisedAt)`. There is also no geohash field on tickets, so radius filtering is entirely client-side after downloading every matching ticket in the world.

**Fix:** Add a geohash (`geoflutterfire_plus`) to `tickets.approximateLocation` and do a bounded server-side range query, then refine client-side. Add the composites above.
**Depends on:** BE-01.

### BE-15 · Medium — Missing integrations
Real payment gateway (Razorpay/Stripe — currently simulated by design, but "by design" ends at launch); SMS/OTP phone verification (phone is collected, never verified); maps/directions handoff for the provider; crash reporting (Crashlytics/Sentry — **nothing** today); analytics; remote config/feature flags; email transactional service beyond Firebase's default templates.

### BE-16 · Critical — No iOS project
There is no `ios/` directory. `DefaultFirebaseOptions.ios` is entirely placeholder values, and `FirebaseService.initialize()` explicitly checks `apiKey == 'placeholder-apiKey'` and **falls back to simulation mode**. So if an iOS target were added today, the app would launch, appear to work, and silently persist nothing — every ticket, job, and payment lost on restart, with only a `debugPrint` as warning.

**Fix:** `flutter create --platforms=ios .`, `flutterfire configure`, add `Info.plist` usage descriptions (camera, photo library, location when-in-use + always), `GoogleService-Info.plist`. Separately: make simulation-mode fallback **loud** — a persistent in-app banner, not a `debugPrint`, so it can never be mistaken for a working build.

### BE-17 · Critical — Release builds are signed with the debug key
`android/app/build.gradle.kts:41` — `signingConfig = signingConfigs.getByName("debug")` inside the release block (Flutter's default scaffold comment). Play Store will reject this.

Also: app label is lowercase `"fixwaala"`, the launcher icon is the default Flutter icon, `INTERNET` is declared twice, `POST_NOTIFICATIONS` is missing (breaks BE-05 on Android 13+), and `FOREGROUND_SERVICE_LOCATION`/`ACCESS_BACKGROUND_LOCATION` are missing (breaks provider live-tracking the moment the app backgrounds).

**Fix:** Real keystore + `key.properties` (gitignored), proper app label and adaptive icon, dedupe permissions, add the notification and background-location permissions with rationale UI.

### BE-18 · Low — `android/app/google-services.json` and `lib/firebase_options.dart` are committed
These are not secrets in the classic sense (Firebase API keys are public identifiers), but they pin a specific project into the repo with no dev/staging/prod separation. `fixwaalageomatching.bundle` (1.7 MB) is also committed and appears to be a build artifact.

**Fix:** Separate Firebase projects per environment with `--dart-define` flavors; remove the stray bundle from git.

---

# 3. UI

### UI-01 · High — No error state on most async surfaces
`EmptyStateWidget` and `LoadingWidget` exist and are good. But the `hasError` branch is handled in only four places (`_ActiveTicketsView`, `_HistoryTicketsView`, `MatchingScreen`, provider opportunities). Everywhere else — `job_tracking`, `status_update`, `job_details`, `estimate`, `completion`, `provider_profile`, `verification_status`, every admin screen — uses `if (!snapshot.hasData) return LoadingWidget()`. A stream error there produces an **infinite spinner with no message and no retry**.

**Fix:** A shared `AsyncStateBuilder<T>({loading, error, empty, data})` used everywhere, with a retry callback on the error branch. This is the single highest-leverage UI change in the audit.

### UI-02 · High — Loading states are inconsistent
Three different treatments coexist: `LoadingWidget` (pulse), `ShimmerPlaceholder` (built, barely used), and bare `CircularProgressIndicator`. Buttons are inconsistent too — some disable during submit, some don't. `SosScreen._raise` has no error path at all.

**Fix:** Standardise: skeletons for list/content loads, inline spinner for button actions, full-screen loader only for route-level bootstraps. Document in the design-system file.

### UI-03 · High — The design system is defined but not enforced
`AppSpacing` exists; `EdgeInsets.all(24)`, `all(20)`, `all(16)`, `fromLTRB(20,20,20,96)`, `fromLTRB(20,20,20,110)` are all written as raw literals throughout. `AppRadii` exists; `BorderRadius.circular(16)`, `(14)`, `(12)`, `(10)`, `(8)` are hardcoded ~80 times. `AppShadows` exists; ad-hoc `BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)` is copy-pasted in three files.

Card styling is reimplemented from scratch in at least six places (`_TicketCard`, `_TicketHistoryCard`, `_ActiveJobCard`, `_ActionCard`, `_SettingsSection`, `_StatTile`) instead of using `CardTheme` — each with slightly different radius, border alpha, and shadow.

**Fix:** Extract `AppCard`, `AppListTile`, `AppSectionHeader` primitives; replace literals with tokens; add a lint or review checklist. Bottom padding for the floating nav bar is `96` in some lists and `110` in others — pick one and put it in `AppSpacing`.

### UI-04 · Medium — Typography and iconography drift
Screens mix `AppTextStyles.titleMedium` with `Theme.of(context).textTheme.titleMedium` (`provider_review_screen`, `ai_assist_screen`, `admin_login_screen` use the theme; home screens use the tokens). Raw `TextStyle(fontSize: 12)` appears in `ticket_review_screen:161`, `provider_review_screen:143`, and `email_verification_screen:173`.

Icons mix rounded and sharp variants inconsistently (`Icons.schedule` vs `Icons.schedule_rounded`, `Icons.star` vs `Icons.star_rounded` — both appear in the same feature).

**Fix:** One source of truth for text styles (prefer feeding `AppTextStyles` into `ThemeData.textTheme` and reading from the theme). Standardise on the `_rounded` icon family throughout.

### UI-05 · Medium — Screens that need a redesign
- `provider_opportunity_screen.dart` — unreachable dead screen with a `'provider-id-stub'` provider id and a hardcoded `'~1.2 km · Estimated 20 min'` fallback. **Delete it.**
- `inspection_screen.dart` — a demo shim whose only button is labelled "Simulate: estimate received". **Delete it** (the real flow is `status_update` → `provider_inspection_estimate`).
- `provider_verification_review_screen.dart` — renders three fake providers. Rebuild against Firestore (BE-03).
- `ticket_review_screen.dart` — plain `ListTile`s with `contentPadding: zero`; visually the weakest screen in the customer flow, and it's the final confirmation step before submitting.
- `admin_login_screen.dart` / `audit_events_screen.dart` / `active_tickets_screen.dart` — unstyled default Material, visibly disconnected from the rest of the app.

### UI-06 · Medium — Cosmetic content presented as real
The home screen shows five hardcoded "Popular Services" with fabricated prices (`From ₹399`) and ratings (`4.7`), a "20% off your first repair" offer that isn't implemented, two service categories (`Deep Home Cleaning`, and the `kCosmeticOnlyCategoryTiles` set) the app cannot actually fulfil, and a "Trust & Safety" panel claiming "Every provider completes ID and background verification" — which is false (SEC-05).

**Why it matters:** Fabricated prices and an unhonored discount are consumer-protection exposure, not just polish. The verification claim is actively misleading.
**Fix:** Back popular services and offers with real data (or a Remote Config document), remove categories you can't serve, and rewrite the Trust & Safety copy to match what the system actually enforces.

### UI-07 · Low — Visual polish backlog
No image error/placeholder states; provider and customer avatars are generic person icons everywhere (no photo upload); no empty-state illustrations (icon-only); status colors `assigned` and `accepted` are both `AppColors.info` so the stepper shows no visual change on the first transition; `_QuickStatCard` shows `'—'` with no explanation of why; the admin panel has no visual identity at all.

---

# 4. UX

### UX-01 · Critical — Confirming a provider crashes or dead-ends
`provider_review_screen.dart:83`
```dart
Navigator.of(context).pushReplacementNamed(RouteNames.jobTracking);
```
No `arguments`. `JobTrackingScreen` falls through to `activeJobForCustomer(customerId)` — which only works because `JobService` holds every job in memory (BE-01). Once BE-01 is fixed properly, this becomes a guaranteed "No active job right now" dead-end **at the single most important moment in the funnel** — immediately after the customer commits to a provider.

**Fix:** Have `confirmProvider` return the created `Job` and pass `job.jobId` as the route argument.
**Depends on:** must be fixed *with* BE-01.

### UX-02 · High — A provider who rates a customer is sent to the customer home screen
`rating_screen.dart:51` unconditionally does `pushNamedAndRemoveUntil(RouteNames.customerHome)`, including for `RatingDirection.providerToCustomer` (reached from `job_details_screen.dart:268`). The provider's entire navigation stack is replaced with the customer app.

**Fix:** Branch on the signed-in user's role (or on `direction`) for the destination. The same bug is in the "already rated" branch at line 104.

### UX-03 · High — No way to cancel a request
The matching screen's "Cancel" button just pops the route (`matching_screen.dart:137`) — the ticket stays `matching` and keeps broadcasting. There is no cancel action on the ticket card, in My Tickets, or on job tracking. `TicketService.cancelTicket()` exists with zero callers. Customers cannot withdraw a request; providers can only reject at the `assigned` stage.

**Fix:** Real cancel actions with confirmation at each stage, wired to `cancelTicket` / `JobService.cancelJob`, with a stated cancellation policy once money is involved.
**Depends on:** BE-02.

### UX-04 · High — Zero onboarding or first-run guidance
No tutorial, no coach marks, no empty-state education. A new provider lands on a screen with an "online" toggle and no explanation of the trust score, verification, or how opportunities arrive. A new customer sees a search bar that isn't a search bar.

Worse: if a provider toggles online but `providerProfile.liveLocation` is null (location permission denied or not yet fetched), the *entire* opportunities section renders `SizedBox.shrink()` — a blank gap with **no message whatsoever** (`provider_home_screen.dart:347`). The provider has no idea why no jobs are appearing.

**Fix:** Role-specific first-run carousel; explicit permission-rationale UI before requesting location; a diagnostic state ("Location unavailable — tap to enable") in place of the blank; and an onboarding checklist card (complete profile → verify identity → go online).

### UX-05 · High — No communication channel between matched parties
After confirmation the customer sees a name and a live map dot. There is no call button, no chat, no "provider is 2 minutes away" message. Phone numbers are collected at onboarding and never surfaced to either party.

**Why it matters:** This is table-stakes for every field-service marketplace, and it's the most common reason a job fails on arrival (can't find the flat, gate locked, nobody home).
**Fix:** At minimum a masked-call handoff (`url_launcher` + `tel:` with a proxy number) once status is `enRoute`. Ideally in-app chat with canned messages.

### UX-06 · Medium — Forms have avoidable friction
- `create_ticket_screen` accepts an **empty description** and sends it to the AI — no validator, no minimum length, no character counter (`_continue()` has no guard).
- `email_auth_screen` has no password-strength meter and no confirm-password field.
- Phone is `(optional)` in both onboarding flows but is the only realistic contact channel.
- `Validators.email` uses `{2,4}` for the TLD — rejects `.online`, `.digital`, `.technology`.
- `Validators.aadhaar` checks length only; no Verhoeff checksum.
- `provider_inspection_estimate_screen` accepts `0` for both labour and parts, then fails at the service layer with a raw exception string.
- No autofill hints (`AutofillHints.email`, `.newPassword`) anywhere, so password managers don't engage.
- The AI clarifying-question flow forces one question per screen with no way to skip or answer "not sure".
- No `TextInputAction`/focus chaining — every form requires dismissing the keyboard between fields.

### UX-07 · Medium — Raw exception strings shown to users
`estimate_screen:38`, `completion_screen:38`, `status_update_screen:35`, `provider_inspection_estimate_screen:61`, `customer_onboarding_screen:69`, `rating_screen:55`, `report_screen:83` all do `Text('$e')`. Users see `JobTransitionException: Accepting the job is not available while the job is en route` or `Bad state: …`. `AuthService.friendlyMessage` shows the right pattern — it just isn't applied outside auth.

**Fix:** A shared `ErrorMessages.friendly(Object)` covering `JobTransitionException`, `AccountRestrictedException`, `DuplicateRatingException`, `FirebaseException`, and network errors.

### UX-08 · Medium — Navigation gaps
- `providerReview` and `matchingProgress` `pushReplacement` into each other; on expiry the customer bounces between them with no way back to home.
- No back button on `customerHome`/`providerHome` shells (correct) but also no Android hardware-back handling — back exits the app from any tab.
- `ProviderInspectionEstimateScreen` `pop()`s on success back to `status_update`, which still shows the pre-submit action for a frame.
- Deep links / `deeplink.json` exists in `build/` but no `intent-filter` is configured.
- Admin dashboard has no sign-out and no link to verification review.

### UX-09 · Medium — Trust-gated matching leaks more than it should
Before accepting, a provider sees the customer's **full name**, description, photos, and approximate location for every ticket in range. The design protects the exact address but not identity. A hostile actor registering as a provider harvests names + neighbourhoods at scale (and with SEC-01, exact addresses).

**Fix:** Show first name or initials pre-acceptance. Reveal full name at candidate confirmation, address only on assignment (as designed).

### UX-10 · Medium — The 30-second candidate window is too aggressive
`AppConstants.candidateReviewSeconds = 30`. The customer must open the provider's full profile, read reviews, and decide in 30 seconds — and the timer only runs while the screen is open (BE-06). On expiry, all candidates are dropped and the customer is bounced back to searching with no explanation of what happened.

**Fix:** Extend to 2–3 minutes, make it server-enforced, warn at 30s remaining, and on expiry show an explanatory state with a "search again" CTA rather than a silent bounce.

### UX-11 · Low — Usability enhancements worth scheduling
Scheduled/future bookings; repeat-booking from history; provider favourites and blocklist; price transparency before matching (estimate ranges by category); job photos before/after; multi-language (Hindi/regional — `AppPreferencesService.language` exists and does nothing); referral flow; in-app support chat; provider earnings payout schedule; customer saved addresses.

---

# 5. Bugs & Fixes

Findings not already covered above. Priority in brackets.

| ID | Pri | Bug | Location | Fix |
|---|---|---|---|---|
| BUG-01 | Critical | `_accept()` has `try/finally` but **no `catch`** — an `AccountRestrictedException` or Firestore error escapes uncaught. No error UI; the button just re-enables. | `provider_home_screen.dart:1405` | Add `catch` → friendly snackbar. |
| BUG-02 | Critical | `AccountService.allAccounts()` returns `[]` in production (`knownDemoUsers()` returns `const []` when live). Admin moderation is inert. | `account_service.dart:60` | Query the `users` collection. (Also BE-04.) |
| BUG-03 | High | `declineOpportunity()` is an **empty method**. Declining only hides the card locally via `_declined`; the ticket reappears on the next stream emission or app restart. | `matching_service.dart:101` | Persist a per-provider decline record and filter it out of the query. |
| BUG-04 | High | `_NewTicketNotifier` fires a notification for tickets the provider already declined, and re-fires for all tickets whenever the widget remounts (`_seenIds` is per-instance). | `provider_home_screen.dart:1341` | Persist seen ids; respect declines. |
| BUG-05 | High | A provider with **no skills selected** gets `categories == []`, which skips the `whereIn` filter entirely — they receive every category's tickets. | `ticket_service.dart:174` → `geo_broadcast_service.dart:77` | Return an empty stream when `categories.isEmpty`, and require ≥1 skill (onboarding already does; profile editing must too). |
| BUG-06 | High | ETA is `(distanceKm * 2)` minutes — a flat 30 km/h assumption with no traffic, no routing, no mode of transport. Shown to customers as a commitment. | `matching_service.dart:64`, `provider_home_screen.dart:1514` (duplicated) | Use a routing API, or label it clearly as an estimate. Deduplicate the calculation. |
| BUG-07 | High | `_maybeClose` requires `customerRated` but ignores `providerRated`, so a job closes before the provider has rated — and `job_details_screen` still offers "Rate customer" on a closed job. | `job_service.dart:431` | Decide the closure contract and make the UI match. |
| BUG-08 | Medium | Two independent haversine implementations: `LocationService.distanceKm` (atan2) and `Helpers.haversineKm` (asin). `Helpers` is dead code. | `location_service.dart:51`, `helpers.dart:9` | Delete `Helpers.haversineKm`. |
| BUG-09 | Medium | `PaymentService.simulate()` has a hardcoded `Future.delayed(seconds: 2)` in the production path. | `payment_service.dart:81` | Gate behind `kDebugMode` or remove. |
| BUG-10 | Medium | `SelfieCaptureScreen._captureSelfie()` sets `_localPath = '/tmp/selfie.jpg'` — no camera is ever opened, and the path doesn't exist. | `selfie_capture_screen.dart:20` | Real `image_picker` capture + upload. (Also BE-03.) |
| BUG-11 | Medium | Three `Image.network` calls with no `errorBuilder`, `loadingBuilder`, or `cacheWidth`. A dead Cloudinary URL renders a red exception box mid-list. | `job_details_screen:160`, `provider_opportunity_screen:101`, `ticket_review_screen:148` | Shared `RemoteImage` widget. |
| BUG-12 | Medium | `_confirm()` on the candidate card is not debounced — a double-tap can fire `confirmProvider` twice, creating two jobs. | `provider_review_screen.dart:74` | Disable on first tap; add a service-level guard. (See BE-07.) |
| BUG-13 | Medium | `_handleExpired` runs `rejectCandidate` in a sequential `await` loop; each call re-reads the full candidate list (`watchCandidates(...).first`). O(n²) reads. | `provider_review_screen.dart:53` | Batch write; read the list once. |
| BUG-14 | Medium | Stream controllers are never closed: `JobService._controller`, `MatchingService._changes`, `ReportService._changes`, `AccountService._changes`, `ProviderPresenceService._simController`, all three in `AppPreferencesService`. Singletons, so it's bounded — but `dispose()` on `AppPreferencesService` is defined and never called. | multiple | Add lifecycle teardown on sign-out (ties to SEC-03). |
| BUG-15 | Medium | `AiAssistScreen._run()` and `_runFinal()` have no `try/catch`. An unexpected throw leaves `_step` at `loadingInitial` — permanent spinner. | `ai_assist_screen.dart:56` | Wrap and add an error state. (See BE-12.) |
| BUG-16 | Medium | `AdminDashboardScreen`'s `FutureBuilder` never re-fetches. Counts are frozen from first render; suspending an account doesn't update the badge. | `admin_dashboard_screen.dart:21` | Convert to a stream. |
| BUG-17 | Low | `Validators.email` regex `{2,4}` rejects modern TLDs; `Validators.email` returns `null` for empty (documented as "optional") but callers pre-check emptiness inconsistently. | `validators.dart:27` | Relax to `{2,}`; make the contract explicit. |
| BUG-18 | Low | `ProviderReviewScreen` reads `ModalRoute.arguments as String` with a hard cast in `build()` — navigating there without arguments throws. Same pattern in `matching_screen:35`, `provider_profile_screen:48`, `completion_screen:26`, `estimate_screen:28`, `status_update_screen:25`, `job_details_screen:25`, `provider_inspection_estimate_screen:30`. | 8 sites | Null-safe cast + a friendly "couldn't open" state. |
| BUG-19 | Low | `_formatDate` is duplicated verbatim in three files; `_initials` in two; the entire settings/profile tab in two. | see FE-14 | Extract. |
| BUG-20 | Low | 9 `flutter analyze` infos: 6× `unnecessary_underscores`, 1× `use_null_aware_elements`, 1× `curly_braces_in_flow_control_structures`. | various | `dart fix --apply`. |

## Technical debt & missing engineering practice

- **No CI.** No GitHub Actions, no pre-commit hooks. `analyze`/`test` are run by hand.
- **No integration or widget tests.** 77 unit tests cover only in-memory service logic. `widget_test.dart` is the default counter test. Zero coverage of: the Firestore `_live` paths, `firestore.rules`, navigation, forms, or the end-to-end ticket→match→job→payment→rating journey.
- **No rules tests.** Given SEC-01, this is the highest-value test suite to add.
- **`Handoff/project-status.md` is stale** (dated 2026-07-25) — it lists as open several bugs that have since been fixed (dashboard provider ids), and omits everything found here. Replace it with this document as the source of truth.
- **No `CHANGELOG`, no `CONTRIBUTING`, no architecture doc.** `README.md` is 19 lines.
- **`build/`, `.dart_tool/`, `.idea/`, and a 1.7 MB `.bundle`** are tracked or partially tracked despite `.gitignore` entries.
- **No environment separation** — one Firebase project for everything.

---

# Master backlog

Ordered by dependency, then severity. **P0 = release-blocking.**

## P0 — Release blockers (must land before any deploy)

| # | Item | Refs |
|---|---|---|
| 1 | Rewrite `firestore.rules` with per-document ownership + admin custom claim; add rules-emulator test suite | SEC-01 |
| 2 | Scope all three Firestore listeners to the signed-in user; add indexes | BE-01 |
| 3 | Real admin auth (custom claim) + `/admin/*` route guard + admin sign-out; delete demo credentials | SEC-02 |
| 4 | Fix Sign Out — call `signOut()`, tear down listeners, clear caches | SEC-03 |
| 5 | Move Gemini behind a server endpoint; rotate the leaked key; unbundle `.env` | SEC-04 |
| 6 | Remove/relabel all "verified" badges until real KYC exists | SEC-05 |
| 7 | Persist reports, safety alerts, account status, audit log to Firestore; make SOS actually reach an admin | BE-04 |
| 8 | Fix `confirmProvider` → `jobTracking` missing route argument | UX-01 |
| 9 | Fix profile save (persist + don't reset controllers) | FE-01, FE-02 |
| 10 | Android release signing config, app label, icon, `POST_NOTIFICATIONS`, background-location permissions | BE-17 |
| 11 | Create the iOS project + FlutterFire config; make simulation-mode fallback loud and visible | BE-16 |
| 12 | Privacy Policy + Terms of Service screens (store requirement) | FE-06 |

## P1 — Core functionality gaps

13. Ticket lifecycle mirroring + cancel flows (BE-02, UX-03)
14. FCM push notifications + Cloud Functions triggers (BE-05)
15. Move geo-broadcast expansion and candidate-lease expiry server-side (BE-06)
16. Transactions/batches for matching; debounce confirm (BE-07, BUG-12)
17. Rebuild Module 2 verification end-to-end (BE-03)
18. Address capture + reverse geocoding (BE-08)
19. Shared `AsyncStateBuilder` — error states everywhere (UI-01)
20. `ErrorMessages.friendly()` — stop showing raw exceptions (UX-07)
21. `currentUserStream` — kill the `FutureBuilder`-in-`build` pattern (FE-03)
22. Persist preferences via `shared_preferences` (BE-09)
23. Wire the 12 dead `onTap: () {}` targets (FE-06)
24. Fix decline persistence, skills filter, notification dedup (BUG-03, BUG-04, BUG-05)
25. Communication channel between matched parties (UX-05)

## P2 — Quality, polish, and correctness

26. FE-14 refactor: extract shared profile/settings/tile widgets, split home screens
27. Design-system enforcement: tokens, `AppCard`, typography source-of-truth (UI-03, UI-04)
28. Dark-mode color audit (FE-12)
29. Accessibility pass (FE-13)
30. Responsive/adaptive shell for both roles (FE-11)
31. Web compatibility for image upload (FE-09)
32. Form validation and friction fixes (UX-06)
33. Delete dead screens; rebuild weak ones (UI-05)
34. Replace fabricated pricing/offers/trust copy with real data (UI-06)
35. Onboarding + permission rationale + provider diagnostics (UX-04)
36. Remaining bugs BUG-06 through BUG-20
37. Pull-to-refresh, loading standardisation (FE-10, UI-02)
38. Extend candidate window; explain expiry (UX-10)
39. Identity minimisation pre-acceptance (UX-09)

## P3 — Platform, scale, and process

40. CI (analyze + test + build on PR)
41. Integration tests for the full journey; widget tests for critical screens
42. Crashlytics + analytics (BE-15)
43. Geohash-based server-side radius queries (BE-14)
44. Real payment gateway + platform fee + payout ledger (BE-13, BE-15)
45. Environment separation (dev/staging/prod Firebase projects) (BE-18)
46. Phone OTP verification (BE-15)
47. Localization (UX-11)
48. Repo hygiene: untrack build artifacts, docs, `dart fix --apply` (BUG-20)

---

# Workstream allocation — 6 parallel agents

Split to minimise file overlap. **The one hard sequencing constraint:** Agent F's home-screen refactor (FE-14) touches the two files that Agents A and D also need. Resolve this by having **Agent F land the extraction in the first day**, before A and D begin their home-screen work — or by having F skip `customer_home_screen.dart`/`provider_home_screen.dart` restructuring until A and D's P0 items are merged. The plan below assumes **F goes first on extraction**, and A/D start with their non-home-screen items.

---

## Agent A — Security & Access Control
**Primary responsibility:** Everything that decides who can read, write, or do what. The release-blocking security surface.

**Owns:** `firestore.rules`, `firestore.indexes.json`, `lib/core/routes/app_router.dart`, `lib/features/auth/services/auth_service.dart`, `lib/features/admin_panel/services/admin_service.dart`, `lib/core/constants/app_constants.dart`, new `functions/` (auth/claims), new `test/rules/`

**Tasks:**
- **SEC-01** Rewrite `firestore.rules`: per-document ownership for `users`/`tickets`/`jobs`/`payments`/`ratings`; public-profile projection for providers; redacted broadcast projection for matching tickets; move `exactLocation` to a restricted subcollection; immutable-field and status-transition validation.
- **SEC-01b** Rules-emulator test suite (`@firebase/rules-unit-testing`) — one denial test per rule above. This is the acceptance gate for the whole workstream.
- **SEC-02** Admin custom claim (Cloud Function + admin SDK script), `RouteGuard` in `onGenerateRoute` rejecting `/admin/*` without it, real `loginWithCredentials`, admin sign-out on the dashboard, delete `demoAdminEmail`/`demoAdminPassword`.
- **SEC-03** Fix Sign Out in both home screens (coordinate with F on the extracted `SettingsTab`): `await signOut()`, cancel all service listeners, clear static caches, confirmation dialog.
- **SEC-04** Cloud Function proxy for Gemini (auth via ID token); remove `.env` from `pubspec.yaml` assets; rotate the key; document the new config path.
- **FE-03** `AuthService.currentUserStream` — the shared primitive that removes the `FutureBuilder`-in-`build` anti-pattern app-wide. **Deliver this early**; Agents C, D, E all consume it.
- **BE-14** Composite indexes required by Agent B's scoped queries.

**Workload:** ~Large. Highest risk, highest blocking factor.
**Depends on:** none. **Blocks:** B (rules ↔ scoped queries must land together), C (admin claim), and everyone (via `currentUserStream`).
**Deliverables:** Hardened `firestore.rules` + passing rules test suite; deployed claim-setting function; guarded admin routes; working sign-out; Gemini proxy function + rotated key; `currentUserStream` merged to `main` within the first 2 days.

---

## Agent B — Data Layer & Server-Side Business Logic
**Primary responsibility:** Firestore access patterns, the ticket/job state machine, and moving timer-driven logic off the client.

**Owns:** `lib/features/service_lifecycle/services/job_service.dart`, `lib/features/customer_ticket/services/ticket_service.dart`, `lib/features/payment/services/payment_service.dart`, `lib/features/ratings/services/rating_service.dart`, `lib/features/trust_gated_matching/services/matching_service.dart`, `lib/features/geo_broadcast/services/*`, `functions/` (triggers)

**Tasks:**
- **BE-01** Scope all three collection listeners to the signed-in user; re-subscribe on auth change; index jobs by customer/provider id to kill the linear scans (FE-15).
- **BE-02** Ticket-status mirroring from `JobStatus` transitions (prefer a Firestore trigger on `jobs/{id}`); wire `cancelTicket`.
- **BE-06** Move geo-broadcast radius expansion and candidate-lease expiry to scheduled/triggered Cloud Functions.
- **BE-07** `runTransaction`/`WriteBatch` for `confirmProvider`; field-level `update()` instead of whole-doc `set()`; server-side transition validation.
- **BE-10** `onError` on the payment and rating listeners; replace the debug-only `permission-denied` swallow with a surfaced error path.
- **BE-11** Remove the `_memStore[id]!` null assertion; delete the two `try/catch` workarounds it caused.
- **BE-14** Geohash field on `tickets.approximateLocation` + bounded server-side range query.
- **BUG-03** Persist provider declines. **BUG-05** Empty-skills guard. **BUG-07** Job-closure contract. **BUG-09** Remove the hardcoded payment delay. **BUG-13** Batch the expiry loop.
- **UX-01** `confirmProvider` returns the created `Job`; hand the id to Agent D for the navigation fix.

**Workload:** ~Large.
**Depends on:** A (rules must permit the new scoped queries — pair on the contract on day 1). **Blocks:** D (ticket lifecycle → history UI), E (notification triggers).
**Deliverables:** Per-user scoped listeners + indexes; ticket lifecycle reaching `closed`; deployed broadcast/expiry/mirroring functions; transactional matching; error-handled listeners.

---

## Agent C — Admin, Moderation, Verification & Safety
**Primary responsibility:** Everything behind the admin panel, plus Module 2 end-to-end. Largely self-contained.

**Owns:** `lib/features/admin_panel/**`, `lib/features/reports_safety/**`, `lib/features/provider_verification/**`

**Tasks:**
- **BE-04** Firestore-back `ReportService`, `AccountService`, `AdminService` (`reports/`, `safetyAlerts/`, `accountStatus/`, `auditEvents/`) with live listeners.
- **BUG-02** Rewrite `AccountService.allAccounts()` to query the `users` collection (it returns `[]` in production today).
- **SOS escalation** — real-time admin alert (FCM to an admin topic, coordinate with E), plus local emergency numbers surfaced directly on the SOS screen. Add error handling to `SosScreen._raise`.
- **BE-03 / SEC-05** Rebuild provider verification: entry point from onboarding + provider profile; real capture and upload (coordinate with F on the shared upload widget); wire `submitForAdminReview`; admin queue backed by `users where verificationStatus == pending`; implement `reviewProviderVerification` with an audit event; link it from the admin dashboard. **Until real KYC lands, remove every "verified" badge** — including the unconditional one at `provider_home_screen.dart:927` (coordinate with F).
- **UI-05** Delete `provider_opportunity_screen.dart` and `inspection_screen.dart` (and their route entries — coordinate with A on `app_router.dart`). Rebuild `provider_verification_review_screen.dart`. Restyle admin login / audit events / active tickets to the design system.
- **BUG-16** Convert the admin dashboard `FutureBuilder` to a stream. **UX-08** Admin sign-out + verification link.

**Workload:** ~Large but low-conflict — it owns three feature directories almost exclusively.
**Depends on:** A (admin claim, rules for the new collections). **Blocks:** nothing.
**Deliverables:** Persistent moderation + audit trail; functional account management against real users; SOS that reaches an admin; a complete verification flow with an honest (or absent) trust badge.

---

## Agent D — Customer Journey
**Primary responsibility:** The end-to-end customer flow — create → AI assist → review → match → confirm → track → pay → rate.

**Owns:** `lib/features/customer_ticket/screens/**`, `lib/features/ai_assist/**`, `lib/features/geo_broadcast/screens/**`, `lib/features/trust_gated_matching/screens/**`, `lib/features/payment/screens/**`, `lib/features/ratings/screens/**`, `lib/features/service_lifecycle/screens/` (customer-facing: `job_tracking`, `estimate`, `completion`)

**Tasks:**
- **UX-01** Pass `job.jobId` into `jobTracking` after confirmation (consumes B's return value). Highest-priority item in this stream.
- **UX-02** Role-correct destination after rating (both the submit and already-rated branches).
- **UX-03** Cancel-request flows: matching screen, ticket card, My Tickets — wired to `cancelTicket`, with confirmation.
- **FE-04 / FE-05** Fix the History query and the duplicate active-ticket card.
- **BE-08** Address capture: default to the saved profile address, "use current location" via `reverseGeocode`, override field; persist `addressLine`.
- **BE-12 / BUG-15** AI-assist error states, retry, manual-category fallback, `try/catch` around `_run`/`_runFinal`.
- **UX-06** Description validator + counter on create-ticket; skip/"not sure" on clarifying questions; autofill hints; focus chaining.
- **UX-10** Extend the candidate window; warn at 30s; explanatory expiry state instead of a silent bounce.
- **UX-09** First-name-only pre-acceptance identity.
- **UI-05** Redesign `ticket_review_screen`.
- **BUG-12** Debounce confirm. **BUG-18** Null-safe route-argument casts across the 8 sites.

**Workload:** ~Large.
**Depends on:** B (BE-02 for history to be observable; `confirmProvider` return value), A (`currentUserStream`), F (`AsyncStateBuilder`, `ErrorMessages`, `RemoteImage`).
**Deliverables:** A customer journey with no dead-ends, working cancel, real addresses, honest AI failure handling, and a populated history tab.

---

## Agent E — Provider Journey & Notifications
**Primary responsibility:** The provider side of the marketplace, plus the notification backbone for both roles.

**Owns:** `lib/features/service_lifecycle/screens/` (provider-facing: `active_jobs`, `job_details`, `status_update`, `provider_inspection_estimate`), `lib/features/provider_dashboard/**`, `lib/core/services/notification_service.dart`, `lib/core/services/location_service.dart`, `lib/features/geo_broadcast/services/provider_presence_service.dart`, `android/app/src/main/AndroidManifest.xml`

**Tasks:**
- **BE-05** FCM integration end-to-end: `firebase_messaging`, token registration, topic subscription by role, Cloud Function triggers on ticket create and candidate create (coordinate with B on the triggers). Wire `AppPreferencesService.notificationsEnabled` to actually gate delivery.
- **BE-17** `AndroidManifest`: add `POST_NOTIFICATIONS` (+ runtime request), `FOREGROUND_SERVICE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` with rationale UI; dedupe `INTERNET`; fix the app label. Release signing config + keystore documentation.
- **BE-16** Create the iOS project, run `flutterfire configure`, add `Info.plist` usage descriptions and `GoogleService-Info.plist`. Make the simulation-mode fallback a **visible in-app banner**, not a `debugPrint`.
- **BUG-01** `catch` on `_accept()` with a friendly error. **BUG-04** Notification dedup across remounts + declines.
- **UX-04** Provider diagnostics: replace the blank `SizedBox.shrink()` when location is unavailable with an actionable state; permission-rationale UI before requesting location; onboarding checklist card (profile → verify → go online).
- **UX-05** Masked-call handoff (`url_launcher` + `tel:`) once status is `enRoute`, both directions.
- **BUG-06** Deduplicate and honestly label the ETA calculation (two copies today).
- **FE-11** Adaptive/wide layout for `ProviderHomeScreen` (consumes F's `AdaptiveScaffold`).
- Provider profile editing for skills/availability (collected at onboarding, currently uneditable).

**Workload:** ~Large.
**Depends on:** B (triggers), F (`AdaptiveScaffold`, extracted profile/settings widgets), A (`currentUserStream`).
**Deliverables:** Working push notifications on Android and iOS; a buildable, signable release artifact for both platforms; an iOS project; a provider who is never left staring at a blank screen wondering why no jobs arrive.

---

## Agent F — Design System, Shared Widgets & Platform Hygiene
**Primary responsibility:** The shared foundation everyone else builds on. **Front-loaded — deliver the primitives in the first 2 days.**

**Owns:** `lib/core/theme/**`, `lib/core/widgets/**`, `lib/core/utils/**`, `lib/home/**` (extraction only), `.github/workflows/`, `README.md`, `.gitignore`, `analysis_options.yaml`

**Phase 1 — deliver first, everyone is blocked on these:**
- **UI-01** `AsyncStateBuilder<T>({loading, error, empty, data, onRetry})`.
- **UX-07** `ErrorMessages.friendly(Object)` covering `JobTransitionException`, `AccountRestrictedException`, `DuplicateRatingException`, `FirebaseException`, network errors.
- **BUG-11** `RemoteImage` widget with `errorBuilder`/`loadingBuilder`/`cacheWidth`.
- **FE-14** Extract `ProfileTab`, `SettingsTab`, `ProfileTile`, `ThemeOptionSelector`, `RelativeTime.format()`, `initialsOf()` — deduplicating ~600 lines across the two home screens and three other files. Split `customer_home_screen.dart` and `provider_home_screen.dart` into `home/<role>/tabs/*.dart`. **Merge this before A/D/E touch those files.**
- **FE-11** `AdaptiveScaffold` (NavigationRail ≥900px, floating nav below) extracted from the customer shell.
- **FE-09** Cross-platform image upload: `XFile` + `readAsBytes` in `CloudinaryService` and a shared `PhotoPicker` widget (unblocks C's selfie capture and D's ticket photos on web).

**Phase 2:**
- **UI-03** `AppCard`, `AppListTile`, `AppSectionHeader`; replace raw spacing/radius/shadow literals with tokens; single bottom-padding constant for the floating nav.
- **UI-04** Feed `AppTextStyles` into `ThemeData.textTheme`; standardise on `_rounded` icons; remove raw `TextStyle`s.
- **FE-12** Dark-mode color audit across the 17 flagged sites.
- **FE-13** Accessibility pass: label every interactive icon, `Semantics` on the rating control, WCAG AA contrast check (the sage `#8FAF93` on white fails at ~2.1:1), 200% text-scale verification.
- **FE-10** `RefreshIndicator` on primary scrollables. **UI-02** Standardise loading treatments.
- **FE-06** `StaticContentScreen` + Privacy Policy, Terms of Service, About, Help content (**P0 — store requirement**); Change Password flow.
- **UI-06** Replace fabricated popular-service pricing, the unimplemented offer, and the false Trust & Safety copy with real or removed content.
- **BE-09** Implement `StorageService` + `AppPreferencesService` persistence via `shared_preferences`.
- **FE-07 / FE-08** Real search (or an honest CTA); pass the tapped category through to ticket creation.
- **P3 hygiene:** GitHub Actions CI (`analyze` + `test` + `build apk` on PR), `dart fix --apply`, untrack `build/`/`.idea/`/`.bundle`, rewrite `README.md`, retire the stale `Handoff/project-status.md`.

**Workload:** ~Large, heavily front-loaded.
**Depends on:** none. **Blocks:** D and E (Phase 1 primitives), A/D/E (home-screen extraction — must merge first).
**Deliverables (Phase 1, day 2): `AsyncStateBuilder`, `ErrorMessages`, `RemoteImage`, `AdaptiveScaffold`, extracted profile/settings widgets, cross-platform `PhotoPicker`.** Then: a consistently-tokenised, accessible, dark-mode-correct UI; legal pages; persisted preferences; green CI on every PR.

---

## Sequencing summary

```
Day 0-2   F: Phase 1 primitives + home-screen extraction  ──┐
          A: currentUserStream + rules contract with B     ──┤ (everyone else's foundation)
                                                             │
Day 2+    A: rules, admin claim, route guard, Gemini proxy   │
          B: scoped listeners, ticket lifecycle, functions   │
          C: moderation persistence, verification rebuild   ◄─┤
          D: customer journey fixes                        ◄─┤
          E: FCM, platform config, iOS project             ◄─┘
          F: Phase 2 design-system + legal pages + CI
```

**Cross-agent contracts to agree on day 1:**
1. **A ↔ B:** the exact rules-to-query contract (which fields each role may read; the redacted broadcast projection shape).
2. **B ↔ D:** `confirmProvider` returns `Job` (fixes UX-01).
3. **B ↔ E:** Cloud Function trigger payload shape for notifications.
4. **F → all:** `AsyncStateBuilder` and `ErrorMessages` APIs, published before Phase 2 starts.
5. **C ↔ F:** shared `PhotoPicker` interface for selfie + ticket photos.
6. **A ↔ C:** admin claim shape, used both in the route guard and in the moderation collection rules.

**Definition of done for the P0 gate:** rules test suite green; a second signed-in account provably cannot read another user's ticket, address, or job; sign-out verified to end the session across restart; a signed release APK builds; Privacy Policy and Terms reachable from both roles; no "verified" badge appears for an unverified provider.
