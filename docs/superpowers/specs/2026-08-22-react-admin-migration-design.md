# 2026-08-22 — React Admin Portal Migration

Rewrite the Flutter Web admin portal (`lib/admin/`) as a standalone React app,
against the same Firebase project (same Auth, same Firestore data), living
alongside the Flutter codebase in this repo. Full rewrite: all 11 feature
modules ported before cutover, not an incremental module-by-module release.

## Motivation

Reduce web-specific complexity and improve DX/performance by using a
standard React/TypeScript stack for the web-only admin surface, instead of
Flutter Web. The mobile app stays Flutter — untouched.

## Project structure

New top-level `admin-web/` directory, sibling to `lib/`:

```
admin-web/
  src/
    features/        # one folder per admin module (dashboard, users, ...)
    services/         # one Firestore service module per feature
    types/            # shared TS interfaces/enums ported from lib/core/models
    theme/            # Tailwind tokens ported from lib/core/theme
    components/       # shared UI (status badges, category chips, AdminShell)
    auth/             # AdminAuthProvider, useAdminAuth, ProtectedRoute
    routes.tsx
    main.tsx
  package.json
  vite.config.ts
  tailwind.config.ts
```

Not nested inside `lib/`; not a Flutter package. Its own `package.json` /
`node_modules`, independent of the Dart toolchain.

## Tech stack

- **Build tool:** Vite
- **Language:** TypeScript
- **Routing:** React Router (client-side SPA), route table mirrors
  `lib/admin/core/admin_route_names.dart` exactly (`/login`, `/dashboard`,
  `/users`, `/users/:id`, `/admins`, `/tickets`, `/tickets/:id`, `/jobs`,
  `/jobs/:id`, `/payments`, `/payments/:id`, `/reports`, `/reports/:id`,
  `/safety-alerts`, `/ratings`, `/announcements`, `/settings`, `/media`,
  `/audit-log`, `/monitoring`)
- **UI:** Tailwind CSS + shadcn/ui
- **Backend access:** Firebase JS SDK (`firebase/auth`, `firebase/firestore`)
  called directly from service modules — no custom backend layer, matching
  the current Flutter admin's architecture. Same Firebase project as mobile.

## Auth

Port `AdminAuthService` / `AdminAuthGate` (`lib/admin/core/admin_auth_service.dart`,
`admin_auth_gate.dart`) as:

- `AdminAuthProvider` (React context) wrapping `onAuthStateChanged`. On every
  emission, force-refreshes the ID token (`getIdTokenResult(true)`) and
  checks `claims.admin === true`, exposing state
  `checking | signedOut | forbidden(email) | signedIn(email, uid)`.
- `useAdminAuth()` hook for consuming the state.
- `ProtectedRoute` wrapper gating every route except `/login`.
- Sign-in: `signInWithEmailAndPassword`, then check the fresh token's
  `admin` claim; if absent, sign out immediately and surface an
  "access denied" error distinct from a bad-password error — same behavior
  as today, so a non-admin account never stays authenticated against the
  admin app.

Claim provisioning is unchanged: still granted only via
`scripts/admin/grant_admin_claim.js` (Firebase Admin SDK, service-account
key, run locally). The `admins` feature module stays read-only.

## Routing & layout

`routes.tsx` defines the route table above using React Router. An
`AdminShell` component (sidebar + topbar chrome) wraps every authenticated
route, replacing Flutter's `AdminShell`. Detail routes read their ID from
the URL param (`useParams()`) instead of `RouteSettings.arguments`.

## Data layer & domain models

One TypeScript service module per feature, directly porting each Dart
service's Firestore queries (`getDocs`, `onSnapshot`, `.count()` where used):

| Dart service | TS service |
|---|---|
| `admin_dashboard_service.dart` | `services/adminDashboardService.ts` |
| `admin_user_service.dart` | `services/adminUserService.ts` |
| `admin_directory_service.dart` | `services/adminDirectoryService.ts` |
| `admin_ticket_job_service.dart` | `services/adminTicketJobService.ts` |
| `admin_payment_service.dart` | `services/adminPaymentService.ts` |
| `admin_moderation_service.dart` | `services/adminModerationService.ts` |
| `announcement_service.dart` | `services/announcementService.ts` |
| `platform_settings_service.dart` | `services/platformSettingsService.ts` |
| `admin_audit_service.dart` | `services/adminAuditService.ts` |
| `admin_monitoring_service.dart` | `services/adminMonitoringService.ts` |

Domain models/enums ported to `types/` as TS interfaces + enums, sourced
from `lib/core/models/` (`enums.dart`, `user_model.dart`) and the mobile
feature models the admin app currently reuses (`ticket_model.dart`,
`job_model.dart`, `payment_model.dart`, `report_model.dart`,
`rating_model.dart`).

Same Firestore collections as today, unchanged: `users`,
`providerPublicProfiles`, `admins`, `tickets`, `openTickets`, `jobs`,
`payments`, `reports`, `safetyAlerts`, `ratings`, `announcements`,
`platformSettings`, `auditEvents`, `deviceTokens`.

## Feature modules (full parity — 11 modules)

Each ported screen-for-screen, same Firestore reads/writes and same audit
logging on mutations:

1. **dashboard** — stat cards (users, tickets, jobs, reports, safety alerts,
   payments, device tokens)
2. **users** — paginated/searchable/filterable list + detail
3. **admins** — read-only list of accounts with the `admin` claim
4. **moderation** — reports (open/under-review/resolved/rejected), safety
   alerts, low-star rating moderation
5. **payments** — filterable list + detail (pending/processing/success/failed)
6. **tickets_jobs** — ticket list/detail, job list/detail
7. **audit** — read-only, newest-first feed of `auditEvents`
8. **content** — announcements CRUD (info/warning/critical priority)
9. **media** — browse ticket photos (Cloudinary URLs referenced via
   `tickets.imageUrls`; no delete capability, same as today)
10. **settings** — platform config (maintenance mode, support contact, min
    app version, review window, broadcast radii)
11. **monitoring** — Firestore collection health/count check

## Shared UI/theme

`lib/core/theme/` (`app_colors.dart`, `app_spacing.dart`,
`app_text_styles.dart`, `app_radii.dart`) ported to Tailwind theme tokens in
`tailwind.config.ts`. Small shared widgets (`service_category_ui.dart`,
`ticket_status_ui.dart`, `job_status_ui.dart`) become reusable React
components under `components/`.

## Out of scope

- **Cloud Functions** — none are called by the admin portal today (confirmed:
  no `httpsCallable` usage under `lib/admin/`); none are touched by this
  migration.
- **Firebase Hosting / deployment** — explicitly deferred. No `hosting` key
  exists in `firebase.json` today and none is added as part of this design;
  the app runs via `npm run dev` (local) / `vite build` (produces a
  deployable `dist/`, but wiring it to Firebase Hosting is a later,
  separate decision).
- **Admin claim granting UI** — stays out-of-band via
  `scripts/admin/grant_admin_claim.js`; the `admins` module remains
  read-only, same as the Flutter version.
- **Mobile app** — untouched; stays Flutter, no shared code with
  `admin-web/` beyond both talking to the same Firebase project.

## Testing

Type-checking (`tsc --noEmit`) as the automated gate. No existing test
suite covers `lib/admin/` today, so no behavioral regression tests are
carried over; manual QA per module against the same Firestore data the
Flutter admin currently reads, comparing screen-for-screen output.
