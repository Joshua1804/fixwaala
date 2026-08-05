# Admin website

A Flutter Web app, separate from the Android app but living in the same
repository so it can share models, theming, and the Firebase project.
Everything it does reads and writes the same live Firestore data the
Android app uses — there is no separate database or staging environment.

**It is meant to run locally, not to be deployed publicly.** There is no
Firebase Hosting deploy step, no public URL, and no attempt to make the
build available on the internet. An admin runs it on their own machine with
`flutter run`, signs in with an account that holds the `admin` custom claim,
and everything they do lands directly in the same Firestore project the
mobile app reads from.

## Running it

```bash
flutter run -t lib/admin/main_admin.dart -d chrome
```

That's a separate entry point from the mobile app's `lib/main.dart` — same
Flutter project, same `pubspec.yaml`, different `main()`. To build a static
copy instead of running one live:

```bash
flutter build web -t lib/admin/main_admin.dart -o build/admin_web
```

`build/admin_web` can then be served locally (`python3 -m http.server` from
inside it, or any static file server) — still not meant to be put on a
public host.

## Signing in for the first time

Nobody can sign in until at least one account holds the `admin` custom
claim, and nothing in the website itself can grant that — it needs the
Firebase Admin SDK, which needs either a Cloud Function (this project stays
on the free Spark plan, which cannot deploy those at all) or a trusted
machine with a service-account key.

1. Sign up for a normal account through the **Android app** first (the
   website has no sign-up flow — it's an internal tool, not a public one).
2. Follow [`scripts/admin/README.md`](../scripts/admin/README.md) to grant
   that account the `admin` claim.
3. Sign in at the website with those same credentials.

## What it can do

Every feature below is a real, working Firestore read/write — see
[docs/ADMIN_DATA_CONTRACT.md](ADMIN_DATA_CONTRACT.md) for the exact fields
each screen touches, and `lib/admin/features/` for the code.

| Area | Screens |
|---|---|
| **Dashboard** | Platform-wide counts (users, tickets, jobs, payments, reports, safety alerts), computed via Firestore aggregation queries — no document downloads for a number. |
| **Users** | Browse/search/filter customers and providers; edit name/phone; suspend, restrict, or reactivate an account; grant/revoke the Verified badge; delete a profile. |
| **Admins** | Read-only directory of who holds admin access, with copyable commands for granting/revoking it (the actual grant happens outside the browser — see below). |
| **Tickets & Jobs** | Every ticket and job on the platform, filterable by status, with force-cancel for a stuck one. |
| **Payments** | Every simulated payment, with a dispute workflow (open → resolved/refunded) distinct from the payment's own success/failure status. |
| **Reports** | User-filed reports, with a resolve/reject workflow and an admin note. |
| **Safety alerts** | Live (not paginated) SOS feed — see the code comment on why. |
| **Ratings** | Surfaces low-star reviews for moderation; can delete a rating outright. |
| **Announcements** | Create/edit/publish/unpublish in-app banners. |
| **Platform settings** | Maintenance mode, support contact, matching tunables — see the caveat below. |
| **Media** | Browse photos attached to tickets. |
| **Audit log** | Every mutating action taken through this website, who did it, and when — immutable once written. |
| **Monitoring** | Cloud Functions deployment status, and raw document counts per collection as an operational sanity check. |

## Architecture notes

**Separate services, not reused mobile-app services.** The Android app's
`TicketService`, `JobService`, etc. are all scoped to the signed-in user's
own records (`queriesForUser`), because that's what the app's rules and UX
need. An admin needs the opposite — cross-user, paginated, filtered — so
`lib/admin/features/*/services/` are purpose-built rather than reusing those
classes. What *is* shared: the data models (`Ticket`, `Job`, `AppUser`,
`PaymentRecord`, `Rating`, `Report`, `SafetyAlert`), the enums, the design
tokens (`AppColors`, `AppTextStyles`, spacing/radii), and `FirebaseService`.

**Separate theme.** `lib/admin/core/admin_theme.dart` reuses the same colors
and typography as the mobile app's `AppTheme`, but not its button sizing —
`AppTheme`'s `minimumSize: Size(double.infinity, 52)` is tuned for full-width
mobile CTAs and would make every compact toolbar button and table action in
a dense desktop dashboard stretch edge-to-edge. Same identity, different
control sizing for a different form factor.

**Each screen owns its chrome.** `AdminShell` (the side-nav + top bar) wraps
every screen individually via the router, rather than the app having one
persistent scaffold — the same each-route-owns-its-nav pattern the mobile
app uses for its bottom nav.

**Client-side pagination cursors.** List screens use Firestore's
`startAfterDocument` cursor pagination (Previous/Next), not offset-based
paging — that's the only pagination model Firestore actually supports
efficiently.

## Known limitations

- **No Cloud Functions.** Everything that would need one (real push
  notifications for announcements, server-side asset management for
  Cloudinary media) doesn't exist. See the Monitoring screen and
  [docs/RELEASE.md](RELEASE.md).
- **`platformSettings` and `announcements` are not yet consumed by the
  Android app.** They're fully functional to create and edit here, but
  wiring the mobile app to read them live is a separate, not-yet-done
  integration — the settings screen says so explicitly.
- **No full-text search.** User search is exact-email or name-prefix —
  Firestore has no full-text index without a third-party service
  (Algolia/Typesense). See `AdminUserService.search`.
- **Media management stops at what Firestore knows about.** Photos are
  Cloudinary URLs referenced from tickets; this screen browses those
  references. It cannot list or delete orphaned Cloudinary assets directly —
  that needs a signed server-side request with Cloudinary's API secret,
  which must never be compiled into a client, admin or otherwise.
- **Audit log shows the most recent 200 events**, client-filtered by search
  term. A high-volume platform would want server-side pagination here too;
  this project's actual volume doesn't currently justify the complexity.
- **User deletion is two steps.** The website deletes the Firestore profile;
  `scripts/admin/delete_user.js` deletes the Firebase Auth login. Two
  scripts exist for the same reason granting admin access does — the
  Admin SDK operation can't run in the browser.
