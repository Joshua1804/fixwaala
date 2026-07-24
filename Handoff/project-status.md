# Fixwaala — Project Status

Last updated: 2026-07-25

Legend: ✅ Complete · 🟡 In Progress · ⛔ Pending

Each module below maps to a numbered module comment already used throughout the codebase (`route_names.dart`, service docstrings). Status reflects actual working behavior, not just UI presence — a screen that renders but reads from a stub service is marked In Progress or Pending, not Complete.

---

## Module 1 — Auth ✅

Email/password sign-up & login, email verification, password reset, role-based initial routing.

- Firebase Auth + Firestore `users` collection, live and working.
- Falls back to a full in-memory simulation when Firebase isn't configured (`AuthService._live`).
- Covered by `test/auth_service_test.dart`.

No known gaps.

---

## Module 2 — Provider Verification 🟡

Aadhaar entry, selfie capture, verification status screen.

- UI flow complete; status persists to the user's Firestore doc (`verificationStatus` field).
- **Gap:** `verifyAadhaarSandbox()` always returns `true` (hardcoded sandbox stub) and `uploadSelfie()` returns a fixed placeholder URL — no real Aadhaar API or Firebase Storage integration. Verification always "succeeds" by construction.
- `verification_status_screen.dart` reads its status via `snapshot.data ?? pending` with no `hasError` check (same silent-failure pattern flagged below).

---

## Module 3 — Customer Ticket ✅

Create ticket, ticket review, My Tickets (active/history).

- `TicketService` fully Firestore-backed (`tickets` collection) with in-memory fallback.
- Composite indexes for `(customerId, createdAt)` and `(status, createdAt)` deployed to the live project.

No known gaps.

---

## Module 4 — AI Assist 🟡

Auto-categorization + safety-keyword flagging + guided follow-up questions on a ticket description.

- Keyword-rule classifier (`classifyByRules`) is fully functional today — this is what the app actually uses.
- **Gap:** `classifyWithAi()` (real LLM/Vertex-AI call) is a TODO stub that just calls the rule engine. No remote AI integration exists yet.

---

## Module 5 — Geo-Broadcast ⛔

Expanding-radius (5→10→15km) provider discovery + push notification when a ticket is created.

- **Not implemented.** `GeoBroadcastService.findEligibleProviders()` returns `const []` and `notifyProviders()` is a no-op — both are TODO stubs.
- The app currently works around this entirely: providers browse all `status == matching` tickets directly (`TicketService.watchMatchingTickets()`) instead of receiving a geo-filtered candidate broadcast. Functional for a demo, but the actual Module 5 feature (skill/verification/availability/proximity filtering) does not exist.

---

## Module 6 — Trust-Gated Matching 🟡

Provider accepts a ticket → candidate lease → customer reviews & confirms/rejects the candidate.

- Core accept/confirm/reject flow works and (as of this session) correctly creates a `Job` and updates the ticket's status to `assigned` on confirmation.
- **Gap:** `MatchingService`'s active candidate lease (`_activeLease`/`_activeProvider`) is in-memory only — lost if the app restarts mid-flow.
- **Known bug:** identity fallbacks can tag a job with a non-real owner instead of the actual signed-in user:
  - `matching_service.dart:62` — `customerId: customer?.id ?? 'demo-customer'`
  - `provider_home_screen.dart` `_OpportunityTicketCardState._accept()` — falls back to `AppConstants.demoProviderId` if the signed-in provider doesn't resolve in time.

---

## Module 7 — Service Job Lifecycle ✅

Full provider-driven state machine (assigned → accepted → en route → arrived → checked in → inspecting → estimate → work in progress → completion → completed), customer approve/reject-estimate and confirm-completion actions.

- `JobService` fully Firestore-backed (`jobs` collection) this session: in-memory cache for synchronous reads, write-through persistence, live listener for cross-session/device sync.
- Firestore rules deployed (`allow write: if isSignedIn();` on `jobs`) after an earlier stricter per-field rule was found causing permanent write denial.
- Covered by `test/job_lifecycle_test.dart` (all transition/guard-rail cases).
- **Known regression to fix:** the live listener (`job_service.dart:52`, `_col.snapshots().listen(...)`) has no `onError` handler — a stream error here would silently hang every job-watching screen (`job_tracking`, `status_update`, `job_details`, `estimate`, `completion`) on a loading spinner forever, with no console signal.

---

## Module 8 — Payment ✅ (simulated)

Simulated payment with controlled success/failure/retry paths — explicitly no real gateway, no real money, by design.

- `PaymentService` Firestore-backed (`payments` collection) this session.
- Covered by `test/payment_test.dart`.

No known gaps for its intended scope (simulation).

---

## Module 9 — Ratings & Reputation ✅

Star rating + review, one rating per (job, rater) pair enforced.

- `RatingService` Firestore-backed (`ratings` collection) this session.
- Covered by `test/rating_duplicate_test.dart`.

No known gaps.

---

## Module 10 — Provider Dashboard / Trust Score 🟡

Dashboard, Earnings, Performance, Trust Score screens; `AnalyticsService` aggregates completed jobs, earnings, response/arrival times, category mix, peak hours from the (now-persisted) Job/Payment/Rating data.

- `AnalyticsService` and `TrustScoreCalculator` logic are correct and complete — they derive everything live from persisted data, so earnings/history/trust score now survive reload.
- **Known bug:** `provider_dashboard_screen.dart:19`, `earnings_screen.dart:19`, `trust_score_screen.dart:19`, `performance_screen.dart:19`, `active_jobs_screen.dart:28` all hardcode `String get _providerId => AppConstants.demoProviderId;` — **a real signed-in provider always sees the demo account's data, never their own.** Each has a `// NOTE: uses a shared demo provider id` comment, so this was a known, deliberate placeholder that still needs wiring to `AuthService.instance.currentUser()`.
- Covered by `test/trust_score_test.dart` (calculator logic only, not the screen wiring above).

---

## Module 11 — Reports & Safety 🟡

Report/dispute submission, SOS emergency alert during an active job.

- Full business logic works within a session: submitting a report or SOS correctly flags the linked `Job` (`hasOpenReport`/`hasSafetyAlert`).
- **Gap:** `ReportService` is pure in-memory (`_reports`, `_safetyAlerts` lists, no Firestore) — reports and SOS alerts vanish on reload and never reach an admin on a different device/session.
- Covered by `test/report_status_test.dart` (in-memory logic only).

---

## Module 12 — Admin Panel 🟡

Dashboard, provider-verification review, reports management, active tickets, safety alerts, account management, audit log.

- All screens exist and function against their respective services within a session.
- **Gap:** `AccountService` (restrict/suspend/restore) and `AdminService` (audit log) are pure in-memory — moderation actions are lost on reload, never persisted or synced.
- `AdminService.reviewProviderVerification()` is an explicit no-op stub (comment: "Owned by Module 2", never actually wired to Module 2's verification status update).
- Covered by `test/account_restriction_test.dart` (in-memory logic only).

---

## Cross-cutting infrastructure

| Item | Status |
|---|---|
| Firebase project (`fixwaala`) connected, real Auth + Firestore | ✅ Live |
| `firestore.rules` deployed (users/tickets/jobs/payments/ratings) | ✅ Deployed |
| `firestore.indexes.json` deployed (tickets composite indexes) | ✅ Deployed |
| Firebase Storage (selfie/ticket images) | ⛔ Not integrated — URLs are placeholders |
| Push notifications (FCM) | ⛔ Not integrated |
| UI design system (deep-green/sage/gold, tokens, floating nav) | ✅ Complete |
| Settings tab (profile edit, theme, notifications) | ✅ Complete |

## Test coverage snapshot

`test/`: `auth_service_test`, `job_lifecycle_test`, `payment_test`, `rating_duplicate_test`, `report_status_test`, `account_restriction_test`, `trust_score_test`, `widget_test`. All 62 tests passing.

**Not covered:** the Firestore `_live` code paths in any service (tests only exercise the in-memory fallback), `firestore.rules` itself (no rules-emulator test), and the full ticket → matching → job → payment → rating integration path end-to-end.
