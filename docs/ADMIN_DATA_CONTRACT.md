# Admin website data contract

The admin module was removed from the mobile app and rebuilt as a separate
website at [`lib/admin/`](../lib/admin/) — see
[docs/ADMIN_WEB.md](ADMIN_WEB.md) for what it does and how to run it. This
document is the Firestore side of that split: what each collection means,
who writes what, and why the rules are shaped the way they are.

**The split, in one line:** the app *creates* records and reads its own; the
website *reads everything and resolves*. `firestore.rules` enforces exactly
this — it is not a convention, it is the deployed policy.

## Authentication

`admin` is a **Firebase custom claim**, never a role in the app. `UserRole` has
only `customer` and `provider`; nothing the app or the website ships can
grant the claim to itself. It is granted out of band by
[`scripts/admin/grant_admin_claim.js`](../scripts/admin/README.md), a script
run locally with a service-account key — the Admin SDK operation that sets
custom claims cannot run anywhere else on this project's current (Spark)
Firebase plan.

Every rule below keys off `request.auth.token.admin == true`.

## Collections

### `users/{uid}`
Owner-readable only — it carries phone, address, pincode, and live GPS.

| Field | Written by | Notes |
|---|---|---|
| `isVerified` | **Website only** | The "Verified" badge. Seeded `false` at registration; rules forbid self-assignment, so a provider cannot award it to themselves. Set from the user's detail screen in the website. |
| `accountStatus` | **Website only** | `active` \| `restricted` \| `suspended`. Rules forbid self-assignment. The app reads it and blocks actions. |
| everything else | Owner, or the website via its user-detail editor | Rules also freeze `role` and `createdAt`. |

> The app enforces `accountStatus` client-side as a UX guard only. The real
> boundary is the rules — treat the client check as advisory. It also means a
> suspension takes effect on that user's *next* session, not mid-session.

The website's own "Delete" action removes this document (and, for a
provider, `providerPublicProfiles/{uid}`) but cannot delete the underlying
Firebase Auth login — that needs
[`scripts/admin/delete_user.js`](../scripts/admin/README.md), the same
Admin-SDK boundary as granting the claim.

### `providerPublicProfiles/{uid}`
Read-only mirror of the safe subset of a provider's account: `id`, `name`,
`isVerified`, `createdAt`, `skills`, `experienceYears`, `serviceArea`. This is
what a customer sees when they open a candidate's profile, because
`users/{uid}` is owner-only.

**Each provider publishes their own**, from their account's live listener
(`ProviderDirectoryService.publishSelf`). The website does not write it.

That is safe because the rules do not take the provider's word for
`isVerified`: a write is rejected unless the flag equals
`users/{uid}.isVerified`, which they cannot self-assign. Every other field is
theirs to state — a fake name is a moderation problem, a self-awarded badge
would be a hole in the trust model.

> **Granting the badge.** Set `isVerified` on `users/{uid}` from the
> website's user detail screen. The mirror updates the next time that
> provider's device has the app open, so a badge granted while they are
> offline is not visible to customers yet. It under-claims rather than
> over-claims, which is the safe direction.

### `admins/{uid}`
Read-only directory of who holds the `admin` claim, shown on the website's
**Admins** screen. **Nothing client-side can write this collection —
`allow write: if false` unconditionally.** It is written only by
`grant_admin_claim.js`, using the Admin SDK, in the same run that sets the
actual custom claim — so the directory and the claim never drift apart on
their own. `uid`, `email`, `displayName?`, `grantedAt`, `grantedBy`.

### `platformSettings/{docId}`
A single document, `config`, of admin-editable tunables (maintenance mode,
support contact, search radii, minimum app version). Read by any signed-in
user, written only by the website.

**The Android app does not read this yet.** It still compiles
`AppConstants` in at build time; wiring the app to read this document live is
a follow-up integration, not something this collection's existence implies
is already done.

### `announcements/{id}`
Admin-authored banners: `id`, `title`, `body`, `active`, `priority`
(`info|warning|critical`), `audience` (`all|customer|provider`), `createdAt`,
`updatedAt?`, `expiresAt?`, `createdByAdminId`. Read by any signed-in user,
written only by the website.

This is the closest thing to "notification management" the current
architecture supports without a deployed push backend — see
[docs/RELEASE.md](RELEASE.md) on why Cloud Functions (and therefore real
push) need the Blaze plan. **The mobile app does not render these as banners
yet** — same follow-up-integration caveat as `platformSettings`.

### `reports/{reportId}`
Created by the reporter, resolved on the website.

`id`, `reporterId`, `againstUserId?`, `ticketId?`, `jobId?`, `reason`,
`description`, `evidenceUrls[]`, `severity` (`low|medium|high`), `status`
(`open|underReview|resolved|rejected`), `adminNote?`, `resolvedByAdminId?`,
`createdAt`, `updatedAt?`

Rules: create requires `reporterId == uid` **and** `status == 'open'`. The
reporter can read their own; update and delete are admin-only.

### `safetyAlerts/{alertId}`
**SOS. Treat as the highest-priority queue.** The website's Safety Alerts
screen is a live stream (not paginated) specifically because of this.

`id`, `userId`, `ticketId?`, `jobId?`, `resolved`, `resolvedByAdminId?`,
`raisedAt`, `resolvedAt?`

Rules: create requires `userId == uid`. Resolution is admin-only.

> The app tells the user this queue is **not monitored 24/7** and puts national
> emergency numbers (112 / 100 / 108) above the SOS button. Do not change that
> copy without changing the staffing behind it.

### `auditEvents/{eventId}`
Admin-create, admin-read, **nobody can update or delete** — an audit trail
that could be edited by the people it watches is not one. The app neither
writes nor reads it.

Actual shape (written by every mutating action in the website — see
`AdminAuditService.log()`): `id`, `actorAdminId`, `actorAdminEmail`,
`action` (e.g. `user.set_account_status`, `payment.set_dispute`),
`targetType`, `targetId`, `details` (a free-form map), `createdAt`.

### `openTickets/{ticketId}`
The redacted broadcast projection — what an unassigned provider may see.
Published by the ticket's own customer.

**Rules reject any write containing `exactLocation`, `addressLine`,
`customerName`, or `phone`.** The redaction is enforced server-side, not
trusted to the client. Carries `customerFirstName` only.

The website does not use this projection — `isAdmin()` grants full read on
`tickets` itself, so the Tickets screen shows the real address, useful for
dispute resolution.

### `jobs`, `ratings`
Readable by the two parties (`customerId` / `providerId`); `ratings` are
world-readable because reputation is public by design. Admin has full
read/write on both — the website's Jobs screen can force-cancel a stuck job,
and its Ratings screen can delete an abusive review outright (`allow update,
delete: if isAdmin();`).

Rating document ids are `{jobId}_{fromUserId}` — deterministic, so one rater
gets one rating per job as a write conflict rather than a race.

`jobs` carries `customerPhone` / `providerPhone`, denormalised so the two
parties can contact each other without either reading the other's user doc.

### `payments/{paymentId}`
Readable by the two parties; admin has full read/write. Carries the usual
simulated-charge fields (`amount`, `method`, `status`, `processedAt`,
`failureReason?`) plus four **admin-only moderation fields** the website's
Payments screen manages: `disputeStatus`
(`none|disputed|resolved|refunded`), `disputeNote?`, `disputeUpdatedAt?`,
`disputeUpdatedByAdminId?`. A job party can update their own payment record
but the rules force those four fields `unchanged()` for anyone but
`isAdmin()` — a customer or provider cannot self-declare or clear a dispute.

### `deviceTokens/{token}`
FCM registration. `userId`, `token`, `platform`, `updatedAt`. Owner-managed;
admin-readable. Dead tokens are pruned server-side on send failure — which
currently means never, since the pruning function isn't deployed (Spark
plan; see docs/RELEASE.md). The website's Monitoring screen shows a raw
count as a rough proxy for push reach.

## What the website implements

All of this is live in [`lib/admin/`](../lib/admin/) — see
[docs/ADMIN_WEB.md](ADMIN_WEB.md) for the full feature list and how to run
it. In summary, mapped to the sections above:

1. **User management** — browse/search/filter `users`, edit profile fields,
   suspend/restrict/reactivate, grant/revoke `isVerified`, delete.
2. **Moderation queue** — `reports`, filterable by status, with a
   resolve/reject workflow.
3. **Safety queue** — live `safetyAlerts where resolved == false`.
4. **Ratings moderation** — surfaces low-star ratings, can delete outright.
5. **Marketplace oversight** — `tickets` and `jobs` across every user, with
   force-cancel.
6. **Payment disputes** — the `disputeStatus` workflow above.
7. **Content** — `announcements` CRUD, `platformSettings` editor.
8. **Media** — browse ticket-attached photos (Cloudinary URLs stored on the
   ticket; see docs/ADMIN_WEB.md for why full Cloudinary asset management is
   out of reach without a server).
9. **Audit log** — reads `auditEvents`, written by every action above.
10. **Dashboard & Monitoring** — aggregate counts via Firestore's `count()`/
    `sum()` queries, plus Cloud Functions deployment status.

There is no "verification review" evidence-collection queue — the app has no
Aadhaar or selfie capture, so there is nothing besides the account itself to
review. Verification is a judgment call an admin makes and records with
`isVerified`, not a document review workflow.

## Indexes

`firestore.indexes.json` declares the composites the website's filtered list
screens need — `users (role, createdAt)`, `tickets (status, createdAt)`,
`jobs (status, createdAt)`, `payments (disputeStatus, processedAt)`,
`announcements (active, createdAt)`, `auditEvents (actorAdminId, createdAt)`,
among others alongside the ones the mobile app already relied on.
