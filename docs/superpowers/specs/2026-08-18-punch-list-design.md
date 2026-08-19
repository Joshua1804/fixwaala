# 2026-08-18 — Bug/feature punch list

Eight items reported against the running app. Each is scoped independently;
they touch disjoint files except where noted.

## 1. AI ticket assist — bottom overflow

`_buildResultStep()` in `lib/features/ai_assist/screens/ai_assist_screen.dart`
renders unbounded content (safety card, category chips, summary, equipment
chips) inside a plain `Column` with a `Spacer()` and no scroll container.
When the equipment list is long, content exceeds the viewport and Flutter
renders its yellow/black overflow indicator.

**Fix:** wrap the column in `SingleChildScrollView`; replace `Spacer()` with
a fixed `SizedBox` before the Confirm button so the button sits after
content instead of relying on unbounded flex space.

## 2. Provider notifications button

`Icons.notifications_outlined` `IconButton` in `provider_home_screen.dart`
(and the equivalent in `customer_home_screen.dart`) has `onPressed: () {}`.

There's already an `announcements` Firestore collection
(`lib/admin/features/content/models/announcement.dart`,
`AnnouncementService`), written by admins via the admin web app, readable by
any signed-in user per `firestore.rules`, with an `audience` field
(`all` / `customer` / `provider`) — built for exactly this, per its own doc
comment: *"The mobile app does not render these yet."*

**Fix:**
- Add a shared, non-admin read path for announcements (the model/read query
  move to or are mirrored in `lib/core/`, so customer/provider features don't
  import from `lib/admin/`).
- New `NotificationsScreen` (or shared widget) listing active, non-expired
  announcements matching the viewer's role (`audience == all || audience ==
  <role>`), sorted newest first, with priority styling (info/warning/critical).
- Wire both bell icons to push to it.

## 3. Cross-role login redirect

`EmailAuthScreen` already resolves the correct home route after login via
`AuthService.resolveInitialRoute()`, which reads the account's real role from
Firestore — not the role the login page was opened with. So a
provider logging in from the customer card already lands in the right place
silently.

**Fix:** after a successful (non-register) login, compare the resolved
account role to the `role` route argument the screen was opened with. On
mismatch, before navigating, show a dialog: *"This is a \[Provider/Customer\]
account. Go to the \[Provider/Customer\] sign-in page instead?"* — "Go there"
pops back to role selection pre-routed to the correct login page; "Continue
anyway" proceeds to the normal resolved route.

## 4. Customer search bar

Currently a fake button (`GestureDetector` styled as a search field) that
opens "create ticket" — `customer_home_screen.dart`.

**Fix:** replace with a real `TextField`. On input, query
`providerPublicProfiles`:
- If the text matches a known service category name (plumber, electrician,
  carpenter — case-insensitive), filter `skills array-contains <category>`.
- Otherwise treat it as a name search: `orderBy('name').startAt/endAt` prefix
  match.
Results render in a list (name, category chips, verified badge) navigating
into the existing `ProviderProfileScreen`. Debounce input; empty query shows
nothing (or recent/popular categories — reuse existing home-grid categories).

## 5. Provider base location (settings)

New settings entry: "Set your location" opens a full-screen `flutter_map`
(already a dependency, pattern established in
`lib/features/service_lifecycle/widgets/live_tracking_map.dart`) centered on
the provider's last known position. The provider drags/taps to place a pin;
`LocationService.reverseGeocode` shows the resolved address; "Save" persists.

This is distinct from `ProviderProfile.liveLocation` (auto-updated by GPS
while online, used for live job matching/tracking). Add a new field,
`ProviderProfile.baseLocation` (`GeoPoint?`) + `baseAddress` (`String?`), so
the manual pin never gets silently overwritten by the GPS stream.

## 6. Mid-job checkpoints

When a `Job.status` transitions to `JobStatus.workInProgress`, show a
one-time dialog to both the customer and the provider on their respective
tracking/status screens: *"Is everything going okay?"* with two actions:
- **"Yes, all good"** — dismiss, mark shown (so it doesn't reappear on
  rebuild) via a per-job local flag.
- **"No, report an issue"** — navigate to the existing `ReportScreen`,
  pre-filled with `jobId` and the other party's id (reusing the existing
  entry point documented in `report_screen.dart`).

Shown once per job per side (not a recurring timer) — keyed off the status
transition, tracked via a simple `Set<jobId>` / local flag so re-entering the
screen doesn't re-trigger it.

## 7. Analytics — real charts

Add `fl_chart` to `pubspec.yaml`. In
`lib/features/provider_dashboard/screens/performance_screen.dart`, replace
the hand-rolled bar-drawing widgets with:
- Weekly job trend → `LineChart` or grouped `BarChart`.
- Category distribution → `PieChart`.
- Peak demand hours → `BarChart` with 24 buckets.
Keep the existing `AnalyticsService`/`ProviderAnalytics` data shape — this is
a rendering-layer change only, no data model changes.

## 8. Profile customization

- **Name/phone propagation bug:** `customer_home_screen.dart` and
  `provider_home_screen.dart` greet the user via
  `FutureBuilder(future: AuthService.instance.currentUser())` — a one-shot
  fetch — instead of `AuthService.instance.currentUserStream`, which
  `profile_settings_scaffold.dart` already uses correctly. Edits made in the
  profile screen don't show up on the home greeting until restart. **Fix:**
  switch both call sites to `StreamBuilder` on `currentUserStream`.
- **Profile photo:** add `photoUrl` (`String?`) to `AppUser`. Wire
  `image_picker` (pick from gallery/camera) → existing `CloudinaryService
  .uploadImage` → `AuthService.updateProfile(photoUrl: ...)`. Show the avatar
  (falling back to the current icon placeholder) in `ProfileTab` and
  anywhere else identity renders (home greetings, job cards where relevant).
- **Email change:** add a "Change email" row in Settings (next to the
  existing stubbed "Change Password" row) opening a small flow: re-enter
  current password → Firebase `reauthenticateWithCredential` →
  `verifyBeforeUpdateEmail(newEmail)` → confirmation that a verification link
  was sent to the new address, mirroring the existing
  `password_reset_screen.dart` pattern for structure/error handling.

## Out of scope

- A full push-notification fan-out backend for announcements (existing FCM
  push for job events is untouched; this only adds in-app rendering of
  already-stored announcements).
- Password change flow (already explicitly deferred elsewhere in the code).
