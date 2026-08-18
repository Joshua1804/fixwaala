# Bug/Feature Punch List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the eight reported bugs/gaps in the Fixwaala Flutter app (overflow, dead notifications button, silent cross-role login, fake search, missing manual location, missing mid-job check-ins, weak analytics, incomplete profile editing) without regressing existing flows.

**Architecture:** Each item is an isolated change against the existing `lib/core` (shared services/widgets), `lib/features/*` (screens/services), and `lib/home/*` (home shells) structure. No new backend/Cloud Function is introduced — item 2 (notifications) reuses the existing `announcements` Firestore collection that the admin web app already writes and that `firestore.rules` already allows any signed-in user to read.

**Tech Stack:** Flutter/Dart, Firebase (Auth + Firestore), `flutter_map`/`geolocator`/`geocoding` for maps, new dependency `fl_chart` for analytics charts.

## Global Constraints

- Follow existing patterns: services are singletons (`Service._(); static final instance = Service._();`), models have `fromMap`/`toMap`/`copyWith`, screens read the current user via `AuthService.instance.currentUserStream` (not the one-shot `currentUser()` future) wherever the UI must reflect live edits.
- No new backend/Cloud Function work. `providerPublicProfiles` and `announcements` are read-only from the client side except where already established.
- Keep `AppUser.copyWith`/`ProviderProfile.copyWith` semantics consistent: a `null` argument means "keep existing value", never "clear it" (matches existing code).
- Run `flutter analyze` after every task; it must be clean (no new warnings/errors) before committing.
- Where a task touches logic with no UI dependency (filtering, matching, role-mismatch detection), add a unit test under `test/`, matching the existing test style (`test/auth_service_test.dart`, `test/location_service_test.dart`, etc. — plain `package:test`/`flutter_test`, no widget pumping unless the codebase already does it for that area).

---

### Task 1: Fix AI ticket assist bottom overflow

**Files:**
- Modify: `lib/features/ai_assist/screens/ai_assist_screen.dart:287-353` (`_buildResultStep`)

**Interfaces:** None — self-contained UI fix, no new public API.

- [ ] **Step 1: Reproduce the overflow understanding by reading the current layout**

Confirm the bug: `_buildResultStep()` returns a `Padding > Column` (not scrollable) that uses `const Spacer()` before the final `PrimaryButton`. `Spacer` requires the `Column` to be inside a bounded/unconstrained-free flex context; here the `Column`'s children (safety card + category chips + summary + equipment chips) can exceed the screen height, and `Spacer` cannot shrink below zero, so the `Column` overflows and Flutter paints the diagonal warning stripes at the bottom.

- [ ] **Step 2: Rewrite `_buildResultStep` to scroll and drop the unbounded `Spacer`**

Replace the method body in `lib/features/ai_assist/screens/ai_assist_screen.dart`:

```dart
  Widget _buildResultStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_final?.safetyFlagged ?? false)
            Card(
              color: AppColors.error.withValues(alpha: 0.08),
              child: const ListTile(
                leading: Icon(Icons.warning, color: AppColors.error),
                title: Text('Potential safety concern detected'),
                subtitle: Text(
                  'Please move to a safe distance. Consider emergency services if urgent.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Suggested category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ServiceCategory.values
                .where((c) => c != ServiceCategory.unknown)
                .map(
                  (c) => ChoiceChip(
                    label: Text(c.name),
                    selected: (_override ?? _final?.category) == c,
                    onSelected: (_) => setState(() => _override = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Confidence: ${((_final?.confidence ?? 0) * 100).toStringAsFixed(0)}%',
          ),
          if ((_final?.summary ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_final!.summary),
          ],
          if ((_final?.recommendedEquipment ?? const []).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recommended tools/parts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _final!.recommendedEquipment
                  .map((e) => Chip(label: Text(e)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
          PrimaryButton(label: 'Confirm', onPressed: _confirm),
        ],
      ),
    );
  }
```

Only two things changed: the outer widget is `SingleChildScrollView` instead of a bare `Padding`, and `const Spacer()` became `const SizedBox(height: 32)`.

- [ ] **Step 3: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/ai_assist/screens/ai_assist_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manual check**

Run the app (`flutter run`), reach AI ticket assist with a description likely to trigger many recommended-equipment chips (e.g. "water leaking under the sink, pipe burst"), confirm the result screen scrolls instead of showing the overflow stripes, and the Confirm button is reachable at the bottom.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_assist/screens/ai_assist_screen.dart
git commit -m "fix: scroll AI assist result screen instead of overflowing"
```

---

### Task 2: Fix profile name/phone not reflecting on home screens

**Files:**
- Modify: `lib/home/customer_home_screen.dart` (greeting `FutureBuilder` around line 256)
- Modify: `lib/home/provider_home_screen.dart` (greeting `FutureBuilder` around line 209)

**Interfaces:**
- Consumes: `AuthService.instance.currentUserStream` — `Stream<AppUser?>`, already defined in `lib/features/auth/services/auth_service.dart:371`.

- [ ] **Step 1: Confirm the two call sites**

`grep -n "AuthService.instance.currentUser()" lib/home/customer_home_screen.dart lib/home/provider_home_screen.dart` — the greeting header on each home screen uses `FutureBuilder<AppUser?>(future: AuthService.instance.currentUser(), ...)`, a one-shot fetch that never re-runs when `ProfileTab` saves an edit, unlike `profile_settings_scaffold.dart` which already uses `currentUserStream`.

- [ ] **Step 2: Switch `provider_home_screen.dart`'s greeting to the stream**

In `lib/home/provider_home_screen.dart`, find:

```dart
                          Expanded(
                            child: FutureBuilder<AppUser?>(
                              future: AuthService.instance.currentUser(),
                              builder: (context, snapshot) {
                                final name = snapshot.data?.name ?? 'Provider';
```

Replace with:

```dart
                          Expanded(
                            child: StreamBuilder<AppUser?>(
                              stream: AuthService.instance.currentUserStream,
                              builder: (context, snapshot) {
                                final name = snapshot.data?.name ?? 'Provider';
```

(The rest of the builder body is unchanged — same `snapshot.data` access pattern works for both `AsyncSnapshot` from a `Future` or a `Stream`.)

- [ ] **Step 3: Switch `customer_home_screen.dart`'s greeting to the stream**

Find the equivalent `FutureBuilder<AppUser?>(future: AuthService.instance.currentUser(), ...)` around line 256 (the greeting header, not the search bar or category grid) and apply the same `FutureBuilder` → `StreamBuilder`, `future:` → `stream: AuthService.instance.currentUserStream` change.

Leave the other two `AuthService.instance.currentUser()` call sites in `customer_home_screen.dart` (lines ~631, ~844) alone unless they also drive a name/phone/photo display that must update live — check each: if it's a one-off action (e.g. "which id do I attach to this navigation") a one-shot future is correct and should not change. Only convert call sites that render editable profile fields.

- [ ] **Step 4: Verify with `flutter analyze`**

Run: `flutter analyze lib/home/`
Expected: `No issues found!`

- [ ] **Step 5: Manual check**

Sign in as a provider, open Settings → edit name → save. Navigate back to the provider home screen without restarting the app; the greeting ("Hi \<new name\>! 👋") must reflect the new name immediately. Repeat for the customer home screen.

- [ ] **Step 6: Commit**

```bash
git add lib/home/customer_home_screen.dart lib/home/provider_home_screen.dart
git commit -m "fix: home screen greetings live-update after profile edits"
```

---

### Task 3: Cross-role login redirect prompt

**Files:**
- Modify: `lib/features/auth/screens/email_auth_screen.dart`
- Test: `test/role_mismatch_test.dart`

**Interfaces:**
- Produces: top-level function `String? roleMismatchMessage({required UserRole loginPageRole, required UserRole accountRole})` in `email_auth_screen.dart`, returning `null` when they match, or a message describing the mismatch — kept pure/testable, called from the widget's `_submit`.

- [ ] **Step 1: Write the failing test for the pure mismatch check**

Create `test/role_mismatch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/auth/screens/email_auth_screen.dart';

void main() {
  group('roleMismatchMessage', () {
    test('returns null when the account role matches the login page', () {
      expect(
        roleMismatchMessage(
          loginPageRole: UserRole.customer,
          accountRole: UserRole.customer,
        ),
        isNull,
      );
    });

    test('flags a provider account signing in on the customer page', () {
      final message = roleMismatchMessage(
        loginPageRole: UserRole.customer,
        accountRole: UserRole.provider,
      );
      expect(message, isNotNull);
      expect(message, contains('Provider'));
    });

    test('flags a customer account signing in on the provider page', () {
      final message = roleMismatchMessage(
        loginPageRole: UserRole.provider,
        accountRole: UserRole.customer,
      );
      expect(message, isNotNull);
      expect(message, contains('Customer'));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/role_mismatch_test.dart`
Expected: FAIL — `roleMismatchMessage` is not defined.

- [ ] **Step 3: Add the pure function and wire it into `_submit`**

In `lib/features/auth/screens/email_auth_screen.dart`, add near the top (after imports, before the `EmailAuthScreen` class):

```dart
/// Human-readable label for a role, matching how it's used in copy
/// elsewhere in the auth flow ("Create your provider account", etc.).
String _roleLabel(UserRole role) =>
    role == UserRole.provider ? 'Provider' : 'Customer';

/// Null when [accountRole] matches the role of the login page the user is
/// on ([loginPageRole]); otherwise a message explaining the mismatch, for
/// the "wrong login page" dialog shown after a successful sign-in.
String? roleMismatchMessage({
  required UserRole loginPageRole,
  required UserRole accountRole,
}) {
  if (loginPageRole == accountRole) return null;
  return 'This is a ${_roleLabel(accountRole)} account, but you signed in '
      'on the ${_roleLabel(loginPageRole)} page.';
}
```

Then update `_submit` so the login branch checks for a mismatch before navigating:

```dart
      } else {
        final user = await AuthService.instance.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        final mismatch = roleMismatchMessage(
          loginPageRole: role,
          accountRole: user.role,
        );
        if (mismatch != null) {
          final goToCorrectPage = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Wrong sign-in page'),
              content: Text(
                '$mismatch Go to the ${_roleLabel(user.role)} sign-in page instead?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Continue anyway'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Take me there'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (goToCorrectPage == true) {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.emailAuth,
              arguments: user.role,
            );
            return;
          }
        }
        final destination = await AuthService.instance.resolveInitialRoute();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(destination, (route) => false);
      }
```

Note `login(...)`'s return value is now captured into `user` (previously discarded) — this is required to read `user.role` for the comparison.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/role_mismatch_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/auth/screens/email_auth_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Manual check**

Register a provider account. Sign out. From role selection, tap "Customer" (opens the customer-flavored login page), then sign in with the provider's credentials. Confirm the "Wrong sign-in page" dialog appears, "Take me there" lands back on the login page pre-set to Provider, and "Continue anyway" proceeds straight to the provider home screen.

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/screens/email_auth_screen.dart test/role_mismatch_test.dart
git commit -m "feat: warn and offer redirect when login page role doesn't match the account"
```

---

### Task 4: Notifications button → admin announcements

**Files:**
- Create: `lib/core/models/announcement.dart`
- Create: `lib/core/services/announcement_feed_service.dart`
- Create: `lib/features/notifications/screens/notifications_screen.dart`
- Modify: `lib/core/routes/route_names.dart`
- Modify: `lib/core/routes/app_router.dart`
- Modify: `lib/home/provider_home_screen.dart` (bell `IconButton`, ~line 234)
- Modify: `lib/home/customer_home_screen.dart` (bell `IconButton`, ~line 280)
- Test: `test/announcement_feed_test.dart`

**Interfaces:**
- Produces: `Announcement` model (mirrors `lib/admin/features/content/models/announcement.dart` field-for-field: `id`, `title`, `body`, `active`, `priority` (`AnnouncementPriority`: `info`/`warning`/`critical`), `audience` (`AnnouncementAudience`: `all`/`customer`/`provider`), `createdAt`, `updatedAt`, `expiresAt`, `createdByAdminId`), with `factory Announcement.fromMap(Map<String, dynamic>)`.
- Produces: `AnnouncementFeedService.instance.watchFor(UserRole role)` → `Stream<List<Announcement>>`, and the pure helper `List<Announcement> visibleAnnouncements(List<Announcement> all, {required UserRole viewerRole, required DateTime now})` used by both the service and the test.
- Produces: `NotificationsScreen` (no constructor args — reads the signed-in user's role via `AuthService.instance.currentUserStream`).
- Produces: `RouteNames.notifications = '/notifications'`.

The admin app's `Announcement`/`AnnouncementService` (under `lib/admin/`) are left untouched — the admin website keeps writing to `announcements/{id}` exactly as today. This task adds a read-only, non-admin-scoped mirror so `lib/home/` and `lib/features/` don't import from `lib/admin/`.

- [ ] **Step 1: Write the failing test for the visibility filter**

Create `test/announcement_feed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/announcement.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/services/announcement_feed_service.dart';

Announcement _announcement({
  required String id,
  AnnouncementAudience audience = AnnouncementAudience.all,
  bool active = true,
  DateTime? expiresAt,
  DateTime? createdAt,
}) {
  return Announcement(
    id: id,
    title: 'Title $id',
    body: 'Body $id',
    active: active,
    priority: AnnouncementPriority.info,
    audience: audience,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    createdByAdminId: 'admin_1',
    expiresAt: expiresAt,
  );
}

void main() {
  final now = DateTime(2026, 6, 1);

  test('excludes inactive announcements', () {
    final result = visibleAnnouncements(
      [_announcement(id: '1', active: false)],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('excludes expired announcements', () {
    final result = visibleAnnouncements(
      [_announcement(id: '1', expiresAt: DateTime(2026, 1, 1))],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('includes "all" audience for both roles', () {
    final announcement = _announcement(id: '1');
    for (final role in [UserRole.customer, UserRole.provider]) {
      final result = visibleAnnouncements(
        [announcement],
        viewerRole: role,
        now: now,
      );
      expect(result, [announcement]);
    }
  });

  test('excludes provider-only announcements for a customer viewer', () {
    final result = visibleAnnouncements(
      [_announcement(id: '1', audience: AnnouncementAudience.provider)],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('sorts newest first', () {
    final older = _announcement(id: 'old', createdAt: DateTime(2026, 1, 1));
    final newer = _announcement(id: 'new', createdAt: DateTime(2026, 5, 1));
    final result = visibleAnnouncements(
      [older, newer],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, [newer, older]);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/announcement_feed_test.dart`
Expected: FAIL — `package:fixwaala/core/models/announcement.dart` and `announcement_feed_service.dart` don't exist yet.

- [ ] **Step 3: Create the shared `Announcement` model**

Create `lib/core/models/announcement.dart` (field-for-field copy of `lib/admin/features/content/models/announcement.dart`, minus the admin-only write helpers):

```dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

enum AnnouncementPriority { info, warning, critical }

enum AnnouncementAudience { all, customer, provider }

/// Read-only client mirror of the admin-authored banner stored at
/// `announcements/{id}`. The admin website (`lib/admin/features/content/`)
/// owns writes; this app only ever reads.
class Announcement {
  final String id;
  final String title;
  final String body;
  final bool active;
  final AnnouncementPriority priority;
  final AnnouncementAudience audience;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final String createdByAdminId;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.active,
    required this.priority,
    required this.audience,
    required this.createdAt,
    required this.createdByAdminId,
    this.updatedAt,
    this.expiresAt,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    active: map['active'] as bool? ?? false,
    priority: AnnouncementPriority.values.byName(
      map['priority'] as String? ?? 'info',
    ),
    audience: AnnouncementAudience.values.byName(
      map['audience'] as String? ?? 'all',
    ),
    createdAt: _dateFrom(map['createdAt']),
    updatedAt: map['updatedAt'] == null ? null : _dateFrom(map['updatedAt']),
    expiresAt: map['expiresAt'] == null ? null : _dateFrom(map['expiresAt']),
    createdByAdminId: map['createdByAdminId'] as String? ?? '',
  );
}

DateTime _dateFrom(Object? value) {
  if (value is fs.Timestamp) return value.toDate();
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
```

- [ ] **Step 4: Create `AnnouncementFeedService` with the pure filter + Firestore stream**

Create `lib/core/services/announcement_feed_service.dart`:

```dart
import '../models/announcement.dart';
import '../models/enums.dart';
import 'firebase_service.dart';

/// [all] filtered down to what [viewerRole] should see right now: active,
/// not expired, and targeted at their role (or everyone). Newest first.
///
/// Pure so it's unit-testable without Firestore, and reused by both
/// [AnnouncementFeedService.watchFor] and the notifications screen if it
/// ever needs to re-filter a cached list.
List<Announcement> visibleAnnouncements(
  List<Announcement> all, {
  required UserRole viewerRole,
  required DateTime now,
}) {
  final visible = all.where((a) {
    if (!a.active) return false;
    if (a.expiresAt != null && a.expiresAt!.isBefore(now)) return false;
    if (a.audience == AnnouncementAudience.all) return true;
    return (a.audience == AnnouncementAudience.customer &&
            viewerRole == UserRole.customer) ||
        (a.audience == AnnouncementAudience.provider &&
            viewerRole == UserRole.provider);
  }).toList();
  visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return visible;
}

/// Read-only access to admin announcements for the customer/provider apps.
class AnnouncementFeedService {
  AnnouncementFeedService._();
  static final AnnouncementFeedService instance = AnnouncementFeedService._();

  bool get _live => FirebaseService.instance.isInitialized;

  /// Announcements visible to [role], live-updating as the admin
  /// website publishes/unpublishes them. Empty when not running against a
  /// real Firebase project (there is no simulated announcement fixture data).
  Stream<List<Announcement>> watchFor(UserRole role) {
    if (!_live) return Stream.value(const []);
    return FirebaseService.instance.firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => visibleAnnouncements(
            snap.docs.map((d) => Announcement.fromMap(d.data())).toList(),
            viewerRole: role,
            now: DateTime.now(),
          ),
        );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/announcement_feed_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Add the route**

In `lib/core/routes/route_names.dart`, add under "Static content" (or a new small section):

```dart
  // Notifications (admin announcements)
  static const notifications = '/notifications';
```

In `lib/core/routes/app_router.dart`, add the import:

```dart
import '../../features/notifications/screens/notifications_screen.dart';
```

and a case (near the Module 11 block is fine):

```dart
      case RouteNames.notifications:
        return _page(const NotificationsScreen(), settings);
```

- [ ] **Step 7: Build the `NotificationsScreen`**

Create `lib/features/notifications/screens/notifications_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/models/announcement.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/announcement_feed_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/services/auth_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<AppUser?>(
        stream: AuthService.instance.currentUserStream,
        builder: (context, userSnap) {
          final role = userSnap.data?.role;
          if (role == null) {
            return const LoadingWidget(label: 'Loading...');
          }
          return StreamBuilder<List<Announcement>>(
            stream: AnnouncementFeedService.instance.watchFor(role),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const LoadingWidget(label: 'Loading notifications...');
              }
              final announcements = snap.data!;
              if (announcements.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  subtitle: 'Announcements from the Fixwaala team will show up here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: announcements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _AnnouncementCard(announcement: announcements[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  Color get _accent => switch (announcement.priority) {
    AnnouncementPriority.critical => AppColors.error,
    AnnouncementPriority.warning => AppColors.warning,
    AnnouncementPriority.info => AppColors.info,
  };

  IconData get _icon => switch (announcement.priority) {
    AnnouncementPriority.critical => Icons.error_rounded,
    AnnouncementPriority.warning => Icons.warning_rounded,
    AnnouncementPriority.info => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _accent.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(announcement.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(announcement.body, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Wire both bell icons**

In `lib/home/provider_home_screen.dart`, replace:

```dart
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
```

with:

```dart
                          IconButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed(RouteNames.notifications),
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
```

(Add `import '../core/routes/route_names.dart';` to `provider_home_screen.dart` if it isn't already imported.)

In `lib/home/customer_home_screen.dart`, apply the same change to its `Semantics > IconButton(onPressed: () {}, icon: Icon(Icons.notifications_outlined, ...))` around line 283.

- [ ] **Step 9: Verify with `flutter analyze`**

Run: `flutter analyze lib/`
Expected: `No issues found!`

- [ ] **Step 10: Manual check**

In the admin web app, create an announcement with audience "All" and one with audience "Provider". Sign into the mobile app as a customer: tapping the bell shows only the "All" one. Sign in as a provider: tapping the bell shows both.

- [ ] **Step 11: Commit**

```bash
git add lib/core/models/announcement.dart lib/core/services/announcement_feed_service.dart lib/features/notifications/screens/notifications_screen.dart lib/core/routes/route_names.dart lib/core/routes/app_router.dart lib/home/provider_home_screen.dart lib/home/customer_home_screen.dart test/announcement_feed_test.dart
git commit -m "feat: wire notifications button to admin announcements"
```

---

### Task 5: Real search bar on customer home

**Files:**
- Create: `lib/features/provider_search/services/provider_search_service.dart`
- Create: `lib/features/provider_search/screens/provider_search_results_screen.dart`
- Modify: `lib/home/customer_home_screen.dart` (search bar block, ~line 301-361)
- Modify: `lib/core/routes/route_names.dart`
- Modify: `lib/core/routes/app_router.dart`
- Test: `test/provider_search_test.dart`

**Interfaces:**
- Produces: top-level pure function `List<ProviderPublicProfile> matchProviders(List<ProviderPublicProfile> all, String query)` — category-name match takes priority over name-prefix match; empty/whitespace query returns `[]`.
- Produces: `ProviderSearchService.instance.search(String query)` → `Future<List<ProviderPublicProfile>>`, backed by two Firestore queries (`skills array-contains` for a category hit, `name` range query for a prefix hit) merged via `matchProviders`-equivalent server-side filtering (see Step 3).
- Produces: `RouteNames.providerSearchResults = '/search/results'`, screen takes `query` as a `String` route argument.
- Consumes: `ProviderPublicProfile` (`lib/core/models/provider_public_profile.dart`, already has `id`, `name`, `isVerified`, `skills: List<ServiceCategory>`, `experienceYears`, `serviceArea`), `ServiceCategoryUi.label`/`icon` (`lib/core/widgets/service_category_ui.dart`).

- [ ] **Step 1: Write the failing test for the pure matcher**

Create `test/provider_search_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/provider_public_profile.dart';
import 'package:fixwaala/features/provider_search/services/provider_search_service.dart';

ProviderPublicProfile _provider(
  String id,
  String name, {
  List<ServiceCategory> skills = const [],
}) {
  return ProviderPublicProfile(
    id: id,
    name: name,
    isVerified: false,
    createdAt: DateTime(2026, 1, 1),
    skills: skills,
  );
}

void main() {
  final providers = [
    _provider('1', 'Ramesh Kumar', skills: [ServiceCategory.plumber]),
    _provider('2', 'Anita Sharma', skills: [ServiceCategory.electrician]),
    _provider('3', 'Ravi Plumber', skills: [ServiceCategory.plumber]),
  ];

  test('empty query returns nothing', () {
    expect(matchProviders(providers, ''), isEmpty);
    expect(matchProviders(providers, '   '), isEmpty);
  });

  test('category-name query returns everyone with that skill', () {
    final result = matchProviders(providers, 'plumber');
    expect(result.map((p) => p.id), containsAll(['1', '3']));
    expect(result.map((p) => p.id), isNot(contains('2')));
  });

  test('category query is case-insensitive', () {
    final result = matchProviders(providers, 'PLUMBER');
    expect(result.map((p) => p.id), containsAll(['1', '3']));
  });

  test('name query returns providers whose name contains it', () {
    final result = matchProviders(providers, 'ramesh');
    expect(result.map((p) => p.id), ['1']);
  });

  test('a name that also happens to contain a category word still name-matches', () {
    final result = matchProviders(providers, 'ravi');
    expect(result.map((p) => p.id), ['3']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/provider_search_test.dart`
Expected: FAIL — `provider_search_service.dart` doesn't exist.

- [ ] **Step 3: Create `ProviderSearchService` with the pure matcher + Firestore-backed search**

Create `lib/features/provider_search/services/provider_search_service.dart`:

```dart
import '../../../core/models/enums.dart';
import '../../../core/models/provider_public_profile.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/service_category_ui.dart';

/// [all] filtered by [query]: a category name (e.g. "plumber") matches every
/// provider with that skill; anything else is treated as a name search
/// (case-insensitive substring match). An empty/whitespace query matches
/// nothing — the caller should show a prompt, not the whole directory.
List<ProviderPublicProfile> matchProviders(
  List<ProviderPublicProfile> all,
  String query,
) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return const [];

  final categoryHit = ServiceCategory.values
      .where((c) => c != ServiceCategory.unknown)
      .where(
        (c) =>
            c.name.toLowerCase() == trimmed ||
            ServiceCategoryUi.label(c).toLowerCase() == trimmed,
      )
      .firstOrNull;

  if (categoryHit != null) {
    return all.where((p) => p.skills.contains(categoryHit)).toList();
  }

  return all
      .where((p) => p.name.toLowerCase().contains(trimmed))
      .toList();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Searches `providerPublicProfiles` for [query] using [matchProviders]'s
/// rules. Firestore has no case-insensitive/substring text search, so this
/// pulls the (small, redacted) provider directory client-side and filters
/// in memory — acceptable at the app's current scale, matching how
/// `ProviderDirectoryService.fetch` already reads single documents.
class ProviderSearchService {
  ProviderSearchService._();
  static final ProviderSearchService instance = ProviderSearchService._();

  bool get _live => FirebaseService.instance.isInitialized;

  Future<List<ProviderPublicProfile>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    if (!_live) return const [];

    final snap = await FirebaseService.instance.firestore
        .collection('providerPublicProfiles')
        .get();
    final all = snap.docs
        .map((d) => ProviderPublicProfile.fromMap(d.data()))
        .toList();
    return matchProviders(all, query);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/provider_search_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Add the route**

In `lib/core/routes/route_names.dart`:

```dart
  // Provider search
  static const providerSearchResults = '/search/results';
```

In `lib/core/routes/app_router.dart`, import and add:

```dart
import '../../features/provider_search/screens/provider_search_results_screen.dart';
```

```dart
      case RouteNames.providerSearchResults:
        return _page(const ProviderSearchResultsScreen(), settings);
```

- [ ] **Step 6: Build the results screen**

Create `lib/features/provider_search/screens/provider_search_results_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/models/provider_public_profile.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../services/provider_search_service.dart';

class ProviderSearchResultsScreen extends StatefulWidget {
  const ProviderSearchResultsScreen({super.key});

  @override
  State<ProviderSearchResultsScreen> createState() =>
      _ProviderSearchResultsScreenState();
}

class _ProviderSearchResultsScreenState
    extends State<ProviderSearchResultsScreen> {
  late final String _query;
  Future<List<ProviderPublicProfile>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    _query =
        ModalRoute.of(context)?.settings.arguments as String? ?? '';
    _future = ProviderSearchService.instance.search(_query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "$_query"')),
      body: FutureBuilder<List<ProviderPublicProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingWidget(label: 'Searching...');
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              subtitle: 'Try a service like "Plumber" or a provider\'s name.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ProviderResultCard(
              provider: results[i],
            ),
          );
        },
      ),
    );
  }
}

class _ProviderResultCard extends StatelessWidget {
  final ProviderPublicProfile provider;
  const _ProviderResultCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).pushNamed(
          RouteNames.candidateProviderProfile,
          arguments: provider.id,
        ),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(provider.name, style: AppTextStyles.titleMedium),
        subtitle: Text(
          provider.skills.map(ServiceCategoryUi.label).join(', '),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: provider.isVerified
            ? const Icon(Icons.verified_rounded, color: AppColors.primary)
            : null,
      ),
    );
  }
}
```

- [ ] **Step 7: Replace the fake search bar in `customer_home_screen.dart`**

The current block (around line 301-361) is a `GestureDetector` styled as a text field that navigates to `RouteNames.createTicket` on any tap. Replace the `GestureDetector`/`Container` combination with a real `TextField` inside the same `Container` decoration, submitting to the results screen:

```dart
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search "Plumber", "Electrician", a name…',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                        style: AppTextStyles.bodyMedium,
                        onSubmitted: (value) {
                          if (value.trim().isEmpty) return;
                          Navigator.of(context).pushNamed(
                            RouteNames.providerSearchResults,
                            arguments: value.trim(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
```

This drops the decorative mic icon (voice search was never implemented — it opened nothing) and the outer `Semantics`/`GestureDetector` wrapper, since a real `TextField` is already accessible and interactive on its own.

- [ ] **Step 8: Verify with `flutter analyze`**

Run: `flutter analyze lib/`
Expected: `No issues found!`

- [ ] **Step 9: Manual check**

As a customer, type "plumber" into the search bar and submit — confirm the results screen lists every registered plumber. Type a specific provider's name — confirm only that provider appears. Tapping a result opens their profile.

- [ ] **Step 10: Commit**

```bash
git add lib/features/provider_search/ lib/home/customer_home_screen.dart lib/core/routes/route_names.dart lib/core/routes/app_router.dart test/provider_search_test.dart
git commit -m "feat: real provider/category search on the customer home screen"
```

---

### Task 6: Provider manual base location (settings map picker)

**Files:**
- Modify: `lib/core/models/user_model.dart` (`ProviderProfile`)
- Create: `lib/features/provider_dashboard/screens/provider_location_screen.dart`
- Modify: `lib/core/widgets/profile/settings_tab.dart`
- Modify: `lib/core/widgets/profile/profile_settings_scaffold.dart`
- Modify: `lib/core/routes/route_names.dart`
- Modify: `lib/core/routes/app_router.dart`
- Test: `test/provider_profile_location_test.dart`

**Interfaces:**
- Produces: `ProviderProfile.baseLocation` (`GeoPoint?`) and `ProviderProfile.baseAddress` (`String?`), read/written through the existing `fromMap`/`toMap`/`copyWith`.
- Consumes: `LocationService.instance.reverseGeocode(GeoPoint)` (`lib/core/services/location_service.dart:69`), `AuthService.instance.updateProviderProfile(ProviderProfile)` (`lib/features/auth/services/auth_service.dart:333`), `flutter_map`'s `FlutterMap`/`TileLayer`/`Marker` (already used in `lib/features/service_lifecycle/widgets/live_tracking_map.dart`).

- [ ] **Step 1: Write the failing test for the new `ProviderProfile` fields round-tripping**

Create `test/provider_profile_location_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/user_model.dart';

void main() {
  test('baseLocation and baseAddress round-trip through toMap/fromMap', () {
    const profile = ProviderProfile(
      baseLocation: GeoPoint(12.9716, 77.5946),
      baseAddress: 'Koramangala, Bengaluru',
    );

    final restored = ProviderProfile.fromMap(profile.toMap());

    expect(restored.baseLocation?.latitude, 12.9716);
    expect(restored.baseLocation?.longitude, 77.5946);
    expect(restored.baseAddress, 'Koramangala, Bengaluru');
  });

  test('baseLocation is independent of liveLocation', () {
    const profile = ProviderProfile(
      liveLocation: GeoPoint(1, 1),
      baseLocation: GeoPoint(2, 2),
    );
    final updated = profile.copyWith(liveLocation: const GeoPoint(3, 3));

    expect(updated.liveLocation?.latitude, 3);
    expect(updated.baseLocation?.latitude, 2);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/provider_profile_location_test.dart`
Expected: FAIL — `baseLocation`/`baseAddress` are not defined on `ProviderProfile`.

- [ ] **Step 3: Add the fields to `ProviderProfile`**

In `lib/core/models/user_model.dart`, add to the `ProviderProfile` class (fields, constructor, `fromMap`, `toMap`, `copyWith`):

```dart
class ProviderProfile {
  final List<ServiceCategory> skills;
  final int? experienceYears;
  final String? serviceArea;
  final String? availability;
  final bool online;
  final GeoPoint? liveLocation;
  final DateTime? locationUpdatedAt;

  /// Manually set by the provider in Settings — a fixed base/service-area
  /// pin, distinct from [liveLocation] (auto-updated by the GPS stream while
  /// online, used for live job matching/tracking). Never overwritten by the
  /// GPS watcher.
  final GeoPoint? baseLocation;
  final String? baseAddress;

  const ProviderProfile({
    this.skills = const [],
    this.experienceYears,
    this.serviceArea,
    this.availability,
    this.online = false,
    this.liveLocation,
    this.locationUpdatedAt,
    this.baseLocation,
    this.baseAddress,
  });

  factory ProviderProfile.fromMap(Map<String, dynamic> map) {
    final liveLoc = map['liveLocation'];
    final locationUpdatedAt = map['locationUpdatedAt'];
    final baseLoc = map['baseLocation'];
    return ProviderProfile(
      skills: (map['skills'] as List<dynamic>? ?? [])
          .map((s) => ServiceCategory.values.byName(s as String))
          .toList(),
      experienceYears: map['experienceYears'] as int?,
      serviceArea: map['serviceArea'] as String?,
      availability: map['availability'] as String?,
      online: map['online'] as bool? ?? false,
      liveLocation: liveLoc is fs.GeoPoint
          ? GeoPoint(liveLoc.latitude, liveLoc.longitude)
          : null,
      locationUpdatedAt: locationUpdatedAt is fs.Timestamp
          ? locationUpdatedAt.toDate()
          : null,
      baseLocation: baseLoc is fs.GeoPoint
          ? GeoPoint(baseLoc.latitude, baseLoc.longitude)
          : null,
      baseAddress: map['baseAddress'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'skills': skills.map((s) => s.name).toList(),
    'experienceYears': experienceYears,
    'serviceArea': serviceArea,
    'availability': availability,
    'online': online,
    if (liveLocation != null)
      'liveLocation': fs.GeoPoint(
        liveLocation!.latitude,
        liveLocation!.longitude,
      ),
    if (locationUpdatedAt != null)
      'locationUpdatedAt': fs.Timestamp.fromDate(locationUpdatedAt!),
    if (baseLocation != null)
      'baseLocation': fs.GeoPoint(
        baseLocation!.latitude,
        baseLocation!.longitude,
      ),
    if (baseAddress != null) 'baseAddress': baseAddress,
  };

  ProviderProfile copyWith({
    List<ServiceCategory>? skills,
    int? experienceYears,
    String? serviceArea,
    String? availability,
    bool? online,
    GeoPoint? liveLocation,
    DateTime? locationUpdatedAt,
    GeoPoint? baseLocation,
    String? baseAddress,
  }) {
    return ProviderProfile(
      skills: skills ?? this.skills,
      experienceYears: experienceYears ?? this.experienceYears,
      serviceArea: serviceArea ?? this.serviceArea,
      availability: availability ?? this.availability,
      online: online ?? this.online,
      liveLocation: liveLocation ?? this.liveLocation,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      baseLocation: baseLocation ?? this.baseLocation,
      baseAddress: baseAddress ?? this.baseAddress,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/provider_profile_location_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Add the route**

`lib/core/routes/route_names.dart`:

```dart
  static const providerLocation = '/provider/location';
```

`lib/core/routes/app_router.dart` — import and case:

```dart
import '../../features/provider_dashboard/screens/provider_location_screen.dart';
```

```dart
      case RouteNames.providerLocation:
        return _page(const ProviderLocationScreen(), settings);
```

- [ ] **Step 6: Build the map picker screen**

Create `lib/features/provider_dashboard/screens/provider_location_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/models/user_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';

class ProviderLocationScreen extends StatefulWidget {
  const ProviderLocationScreen({super.key});

  @override
  State<ProviderLocationScreen> createState() =>
      _ProviderLocationScreenState();
}

class _ProviderLocationScreenState extends State<ProviderLocationScreen> {
  final _mapController = MapController();
  GeoPoint? _selected;
  String? _address;
  bool _resolvingAddress = false;
  bool _saving = false;
  bool _loadingInitial = true;

  static const _fallbackCenter = GeoPoint(12.9716, 77.5946); // Bengaluru

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final user = await AuthService.instance.currentUser();
    final existing = user?.providerProfile?.baseLocation ??
        user?.providerProfile?.liveLocation;
    setState(() {
      _selected = existing ?? _fallbackCenter;
      _address = user?.providerProfile?.baseAddress;
      _loadingInitial = false;
    });
  }

  Future<void> _onTap(GeoPoint point) async {
    setState(() {
      _selected = point;
      _resolvingAddress = true;
      _address = null;
    });
    final address = await LocationService.instance.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _address = address;
      _resolvingAddress = false;
    });
  }

  Future<void> _save() async {
    final point = _selected;
    if (point == null || _saving) return;
    setState(() => _saving = true);
    final user = await AuthService.instance.currentUser();
    final existingProfile = user?.providerProfile ?? const ProviderProfile();
    await AuthService.instance.updateProviderProfile(
      existingProfile.copyWith(
        baseLocation: point,
        baseAddress: _address,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial || _selected == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final selected = _selected!;
    return Scaffold(
      appBar: AppBar(title: const Text('Set your location')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: ll.LatLng(selected.latitude, selected.longitude),
                initialZoom: 15,
                onTap: (_, point) =>
                    _onTap(GeoPoint(point.latitude, point.longitude)),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fixwaala.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: ll.LatLng(selected.latitude, selected.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tap the map to drop a pin at your base location.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resolvingAddress
                      ? 'Resolving address...'
                      : (_address ?? 'No address resolved yet'),
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Save location',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Add a Settings entry point**

`SettingsTab` is shared between customer and provider, instantiated from a single call site in `lib/core/widgets/profile/profile_settings_scaffold.dart` (both `lib/home/customer_home_screen.dart` and `lib/home/provider_home_screen.dart` reach it indirectly through `ProfileSettingsScaffold`, which already has the signed-in `user` in scope inside its `AsyncStateBuilder.stream` builder). Add an optional flag so only providers see the row — no change to `ProfileSettingsScaffold`'s own constructor is needed, since `user.role` is already available where `SettingsTab` is built.

In `lib/core/widgets/profile/settings_tab.dart`, update the constructor:

```dart
class SettingsTab extends StatelessWidget {
  final String notificationsSubtitle;
  final Future<void> Function() onSignOut;

  /// Providers only — shows the "Set your location" row.
  final bool showLocationSetting;

  const SettingsTab({
    super.key,
    required this.notificationsSubtitle,
    required this.onSignOut,
    this.showLocationSetting = false,
  });
```

And in `build()`, right after the "Account" section's `ProfileTile`s (after the "Change Password" tile), add:

```dart
        if (showLocationSetting) ...[
          const SizedBox(height: 12),
          ProfileTile(
            icon: Icons.map_outlined,
            label: 'Set your location',
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.providerLocation),
          ),
        ],
```

In `lib/core/widgets/profile/profile_settings_scaffold.dart`, add the import `import '../../models/enums.dart';` alongside the existing `import '../../models/user_model.dart';`, then update the `SettingsTab(...)` call site inside `build()`'s `data:` callback (it currently reads `SettingsTab(notificationsSubtitle: widget.notificationsSubtitle, onSignOut: _handleSignOut)`):

```dart
              SettingsTab(
                notificationsSubtitle: widget.notificationsSubtitle,
                onSignOut: _handleSignOut,
                showLocationSetting: user?.role == UserRole.provider,
              ),
```

This one call site serves both roles — `user` is the customer's or provider's own account depending on who is signed in, so no separate customer/provider wiring is needed.

- [ ] **Step 8: Verify with `flutter analyze`**

Run: `flutter analyze lib/`
Expected: `No issues found!`

- [ ] **Step 9: Manual check**

As a provider, open Settings → "Set your location" → tap a spot on the map → confirm the address resolves and "Save location" persists (re-open the screen; the pin should start where it was last saved, not at the fallback center).

- [ ] **Step 10: Commit**

```bash
git add lib/core/models/user_model.dart lib/features/provider_dashboard/screens/provider_location_screen.dart lib/core/widgets/profile/settings_tab.dart lib/core/widgets/profile/profile_settings_scaffold.dart lib/core/routes/route_names.dart lib/core/routes/app_router.dart test/provider_profile_location_test.dart
git commit -m "feat: provider can set a manual base location on a map in Settings"
```

---

### Task 7: Mid-job checkpoint prompts

**Files:**
- Create: `lib/core/widgets/mid_job_checkpoint.dart`
- Modify: `lib/features/service_lifecycle/screens/job_tracking_screen.dart` (customer side)
- Modify: `lib/features/service_lifecycle/screens/job_details_screen.dart` (provider side)
- Test: `test/mid_job_checkpoint_test.dart`

**Interfaces:**
- Produces: `MidJobCheckpoint.maybeShow(BuildContext context, {required Job job, required String currentUserId, required String otherPartyId})` — a static method that shows the dialog at most once per `job.jobId` per app session, only when `job.status == JobStatus.workInProgress`.
- Produces: pure helper `bool shouldShowCheckpoint({required JobStatus status, required String jobId, required Set<String> alreadyShown})`, used by both `maybeShow` and the test.

- [ ] **Step 1: Write the failing test for the pure trigger logic**

Create `test/mid_job_checkpoint_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/widgets/mid_job_checkpoint.dart';

void main() {
  test('shows only when status is workInProgress', () {
    for (final status in JobStatus.values) {
      final result = shouldShowCheckpoint(
        status: status,
        jobId: 'job_1',
        alreadyShown: {},
      );
      expect(result, status == JobStatus.workInProgress);
    }
  });

  test('does not show twice for the same job', () {
    final shown = <String>{};
    expect(
      shouldShowCheckpoint(
        status: JobStatus.workInProgress,
        jobId: 'job_1',
        alreadyShown: shown,
      ),
      isTrue,
    );
    shown.add('job_1');
    expect(
      shouldShowCheckpoint(
        status: JobStatus.workInProgress,
        jobId: 'job_1',
        alreadyShown: shown,
      ),
      isFalse,
    );
  });

  test('a different job can still show its own checkpoint', () {
    final shown = {'job_1'};
    expect(
      shouldShowCheckpoint(
        status: JobStatus.workInProgress,
        jobId: 'job_2',
        alreadyShown: shown,
      ),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/mid_job_checkpoint_test.dart`
Expected: FAIL — `mid_job_checkpoint.dart` doesn't exist.

- [ ] **Step 3: Build the shared checkpoint widget**

Create `lib/core/widgets/mid_job_checkpoint.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../routes/route_names.dart';

/// True the first time a job reaches [JobStatus.workInProgress] — false on
/// every other status, and false again for a job already in [alreadyShown]
/// (an app-session-scoped dedupe set, not persisted — reopening the app
/// after a genuinely long job re-asking once is acceptable; re-asking on
/// every rebuild of the tracking screen is not).
bool shouldShowCheckpoint({
  required JobStatus status,
  required String jobId,
  required Set<String> alreadyShown,
}) {
  if (status != JobStatus.workInProgress) return false;
  return !alreadyShown.contains(jobId);
}

/// "Is everything going okay?" nudge shown once per job, to whichever side
/// (customer or provider) is looking at the job around the point work
/// actually starts. "No" hands off to the existing Report flow instead of
/// building a new escalation path.
class MidJobCheckpoint {
  MidJobCheckpoint._();

  static final Set<String> _shown = {};

  static void maybeShow(
    BuildContext context, {
    required String jobId,
    required JobStatus status,
    required String otherPartyId,
  }) {
    if (!shouldShowCheckpoint(
      status: status,
      jobId: jobId,
      alreadyShown: _shown,
    )) {
      return;
    }
    _shown.add(jobId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Is everything going okay?'),
          content: const Text(
            'Just checking in now that work is underway.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Yes, all good'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).pushNamed(
                  RouteNames.report,
                  arguments: {
                    'jobId': jobId,
                    'againstUserId': otherPartyId,
                  },
                );
              },
              child: const Text('No, report an issue'),
            ),
          ],
        ),
      );
    });
  }

  /// Test-only: clears the dedupe set between test cases.
  static void resetForTesting() => _shown.clear();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/mid_job_checkpoint_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Wire it into the customer job tracking screen**

In `lib/features/service_lifecycle/screens/job_tracking_screen.dart`, `_JobTrackingContent` is a `StatelessWidget` — convert its `build` call site to trigger the checkpoint. Since it's stateless and rebuilds on every `StreamBuilder` tick, call `MidJobCheckpoint.maybeShow` directly in `build` — the dedupe set in `MidJobCheckpoint` makes repeat calls a no-op:

Add the import:

```dart
import '../../../core/widgets/mid_job_checkpoint.dart';
```

At the top of `_JobTrackingContent.build`, before the `return ListView(...)`:

```dart
  @override
  Widget build(BuildContext context) {
    MidJobCheckpoint.maybeShow(
      context,
      jobId: job.jobId,
      status: job.status,
      otherPartyId: job.providerId,
    );

    const trackableStatuses = {
```

- [ ] **Step 6: Wire it into the provider job details screen**

Read `lib/features/service_lifecycle/screens/job_details_screen.dart`'s top-level `build` method to find where it has the resolved `job` and `context` together (it already reads `job.customerId` around line 282 for the rating flow, so `job` is in scope there). Add the same import and call `MidJobCheckpoint.maybeShow(context, jobId: job.jobId, status: job.status, otherPartyId: job.customerId)` at the start of the widget that builds once `job` is available (mirror Task 7 Step 5's placement — call it at the top of the `build` method for the inner widget that has `job` as a field, immediately before its `return`).

- [ ] **Step 7: Verify with `flutter analyze`**

Run: `flutter analyze lib/`
Expected: `No issues found!`

- [ ] **Step 8: Manual check**

Drive a job through to `workInProgress` on both a customer and a provider device/session. Confirm each side sees the "Is everything going okay?" dialog exactly once (not on every rebuild), "Yes, all good" dismisses it, and "No, report an issue" opens the Report screen pre-filled with the job and the other party.

- [ ] **Step 9: Commit**

```bash
git add lib/core/widgets/mid_job_checkpoint.dart lib/features/service_lifecycle/screens/job_tracking_screen.dart lib/features/service_lifecycle/screens/job_details_screen.dart test/mid_job_checkpoint_test.dart
git commit -m "feat: mid-job check-in prompt for both customer and provider"
```

---

### Task 8: Analytics charts with fl_chart

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/provider_dashboard/screens/performance_screen.dart`

**Interfaces:** None new — `ProviderAnalytics` (`lib/features/provider_dashboard/models/analytics_model.dart`) is unchanged; this is a rendering-layer swap only.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under `dependencies:`, add near the other UI/util packages:

```yaml
  fl_chart: ^0.69.0
```

Run: `flutter pub get`
Expected: resolves cleanly, `pubspec.lock` updates.

- [ ] **Step 2: Read the current hand-rolled chart widgets**

`lib/features/provider_dashboard/screens/performance_screen.dart` renders "weekly job trend, popular service categories, and peak demand hours" with hand-rolled bars per its own doc comment. Read the full file to find the three private chart-drawing widgets (their exact names — likely something like `_WeeklyTrendChart`, `_CategoryDistributionChart`, `_PeakHoursChart` or similar, confirm via `grep -n "^class _" lib/features/provider_dashboard/screens/performance_screen.dart`) and note exactly what data each currently consumes (`a.weeklyJobs`, `a.categoryDistribution`, `a.peakDemandHours` from `ProviderAnalytics`).

- [ ] **Step 3: Replace the weekly trend widget with an `fl_chart` `LineChart`**

Replace the body of the weekly-trend private widget with:

```dart
import 'package:fl_chart/fl_chart.dart';
// (add to the top imports alongside the existing ones)
```

```dart
class _WeeklyTrendChart extends StatelessWidget {
  final List<int> weeklyJobs; // 7 entries, oldest first
  const _WeeklyTrendChart({required this.weeklyJobs});

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY = (weeklyJobs.isEmpty
            ? 1
            : weeklyJobs.reduce((a, b) => a > b ? a : b))
        .toDouble()
        .clamp(1, double.infinity);
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY + 1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Text(days[i], style: AppTextStyles.bodySmall);
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < weeklyJobs.length; i++)
                  FlSpot(i.toDouble(), weeklyJobs[i].toDouble()),
              ],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the category distribution widget with a `PieChart`**

```dart
class _CategoryDistributionChart extends StatelessWidget {
  final Map<String, int> categoryDistribution;
  const _CategoryDistributionChart({required this.categoryDistribution});

  static const _palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.info,
    AppColors.warning,
    AppColors.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = categoryDistribution.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _palette[i % _palette.length],
                    title:
                        '${(entries[i].value / total * 100).round()}%',
                    radius: 60,
                    titleStyle: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(entries[i].key, style: AppTextStyles.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Replace the peak-hours widget with a `BarChart`**

```dart
class _PeakHoursChart extends StatelessWidget {
  final Map<int, int> peakDemandHours; // hour (0-23) -> job count
  const _PeakHoursChart({required this.peakDemandHours});

  @override
  Widget build(BuildContext context) {
    final maxY = (peakDemandHours.values.isEmpty
            ? 1
            : peakDemandHours.values.reduce((a, b) => a > b ? a : b))
        .toDouble()
        .clamp(1, double.infinity);
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}h',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var hour = 0; hour < 24; hour++)
              BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: (peakDemandHours[hour] ?? 0).toDouble(),
                    color: AppColors.accent,
                    width: 6,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Update call sites to pass the same data these widgets already receive**

Wherever `performance_screen.dart` currently instantiates the old hand-rolled chart widgets (passing `a.weeklyJobs`, `a.categoryDistribution`, `a.peakDemandHours`), the constructor call sites are unchanged — only the class bodies were replaced — so no further edits are needed there. Delete the old private hand-rolled bar-drawing widget classes/methods entirely (do not leave them dead in the file).

- [ ] **Step 7: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/provider_dashboard/`
Expected: `No issues found!`

- [ ] **Step 8: Manual check**

As a provider with completed job history (or seeded demo data), open Performance — confirm the weekly trend line, category pie chart with legend, and peak-hours bar chart all render with real tooltips/proportions instead of the old flat bars.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/provider_dashboard/screens/performance_screen.dart
git commit -m "feat: real charts (fl_chart) on the provider performance screen"
```

---

### Task 9: Profile photo upload

**Files:**
- Modify: `lib/core/models/user_model.dart` (`AppUser`)
- Modify: `lib/features/auth/services/auth_service.dart` (`updateProfile`)
- Modify: `lib/core/widgets/profile/profile_tab.dart`
- Modify: `lib/core/widgets/profile/profile_settings_scaffold.dart` (`onSave` closure)
- Modify: `lib/home/customer_home_screen.dart` and `lib/home/provider_home_screen.dart` (greeting avatar rendering)
- Test: `test/app_user_photo_test.dart`

**Interfaces:**
- Produces: `AppUser.photoUrl` (`String?`), threaded through `fromMap`/`toMap`/`copyWith`.
- Modifies: `AuthService.instance.updateProfile({String? name, String? phone, String? photoUrl})`.
- Consumes: `CloudinaryService.instance.uploadImage(File)` → `Future<String?>` (`lib/core/services/cloudinary_service.dart:40`), `image_picker`'s `ImagePicker().pickImage(source: ImageSource.gallery)`.

- [ ] **Step 1: Write the failing test for `photoUrl` round-tripping**

Create `test/app_user_photo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/user_model.dart';

void main() {
  test('photoUrl round-trips through toMap/fromMap', () {
    final user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      role: UserRole.customer,
      createdAt: DateTime(2026, 1, 1),
      photoUrl: 'https://res.cloudinary.com/demo/image/upload/avatar.jpg',
    );
    final restored = AppUser.fromMap(user.toMap());
    expect(restored.photoUrl, user.photoUrl);
  });

  test('copyWith updates photoUrl without touching other fields', () {
    final user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      role: UserRole.customer,
      createdAt: DateTime(2026, 1, 1),
      name: 'Original Name',
    );
    final updated = user.copyWith(photoUrl: 'https://example.com/p.jpg');
    expect(updated.photoUrl, 'https://example.com/p.jpg');
    expect(updated.name, 'Original Name');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/app_user_photo_test.dart`
Expected: FAIL — `photoUrl` is not a parameter of `AppUser`.

- [ ] **Step 3: Add `photoUrl` to `AppUser`**

In `lib/core/models/user_model.dart`, add the field, constructor param, `fromMap`, `toMap`, and `copyWith` entries:

```dart
  final String? photoUrl;
```

(field, alongside `name`)

```dart
    this.photoUrl,
```

(constructor, alongside `this.name`)

```dart
      photoUrl: map['photoUrl'] as String?,
```

(`fromMap`, alongside `name:`)

```dart
    'photoUrl': photoUrl,
```

(`toMap`, alongside `'name': name,`)

```dart
  AppUser copyWith({
    String? phone,
    String? name,
    String? photoUrl,
    bool? emailVerified,
    ...
```

and inside the returned `AppUser(...)`:

```dart
      photoUrl: photoUrl ?? this.photoUrl,
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/app_user_photo_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Extend `AuthService.updateProfile` to accept and persist `photoUrl`**

In `lib/features/auth/services/auth_service.dart`, update the signature and body:

```dart
  Future<AppUser> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }

    final trimmedName = name?.trim();
    final trimmedPhone = phone?.trim();

    final updated = current.copyWith(
      name: trimmedName,
      phone: trimmedPhone,
      photoUrl: photoUrl,
      updatedAt: DateTime.now(),
    );
    _currentUser = updated;
    _userChanges.add(updated);

    if (!_live) {
      _userDb[updated.id] = updated;
      return updated;
    }

    await FirebaseService.instance.firestore
        .collection('users')
        .doc(updated.id)
        .update({
          'name': ?trimmedName,
          'phone': ?trimmedPhone,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'updatedAt': DateTime.now().toIso8601String(),
        });
    return updated;
  }
```

- [ ] **Step 6: Wire photo picking + upload into `ProfileTab`**

In `lib/core/widgets/profile/profile_tab.dart`, add the picker behind the existing avatar `Container`. Add imports:

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../remote_image.dart';
import '../../services/cloudinary_service.dart';
```

Add state to `_ProfileTabState`:

```dart
  bool _uploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final user = widget.user;
    if (user == null || _uploadingPhoto) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    final url = await CloudinaryService.instance.uploadImage(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo. Try again.')),
      );
      return;
    }
    try {
      await widget.onSave(user.name ?? '', user.phone ?? '');
    } catch (_) {
      // onSave only persists name/phone here; photo is persisted directly
      // below regardless, so a name/phone save failure must not block it.
    }
  }
```

This calls `widget.onSave`, but `onSave`'s signature only carries `name`/`phone` (see `ProfileTab`'s constructor) — it has no way to carry `photoUrl` through to `AuthService.updateProfile`. Change `onSave`'s signature so photo can flow through it instead of adding a second, redundant write path:

```dart
  final Future<void> Function(String name, String phone, String? photoUrl) onSave;
```

And rewrite `_pickAndUploadPhoto` to call it directly with the new URL (dropping the failed approach above):

```dart
  Future<void> _pickAndUploadPhoto() async {
    final user = widget.user;
    if (user == null || _uploadingPhoto) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    final url = await CloudinaryService.instance.uploadImage(File(picked.path));
    if (!mounted) return;

    if (url == null) {
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo. Try again.')),
      );
      return;
    }

    try {
      await widget.onSave(user.name ?? '', user.phone ?? '', url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessages.friendly(error))),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }
```

Also update `_handleSave` (the existing name/phone save) to pass `null` for `photoUrl` (no change intended):

```dart
      await widget.onSave(
        widget.nameController.text.trim(),
        widget.phoneController.text.trim(),
        null,
      );
```

Replace the avatar `Container`/`Icon` with a tappable avatar that shows the photo when present:

```dart
              GestureDetector(
                onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: user?.photoUrl != null
                          ? RemoteImage(
                              url: user!.photoUrl!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
```

(Replaces the existing plain `Container` avatar at the top of `build()`; check `lib/core/widgets/remote_image.dart`'s actual constructor parameter names before using — adjust `url`/`fit` to match if they differ.)

- [ ] **Step 7: Update the one `ProfileTab` call site**

`ProfileTab` is instantiated once, from `lib/core/widgets/profile/profile_settings_scaffold.dart` (shared by both roles — see Task 6 Step 7's note on this same file). Update its `onSave` closure inside `build()`'s `data:` callback from:

```dart
                onSave: (name, phone) async {
                  await AuthService.instance.updateProfile(
                    name: name,
                    phone: phone,
                  );
                },
```

to:

```dart
                onSave: (name, phone, photoUrl) async {
                  await AuthService.instance.updateProfile(
                    name: name,
                    phone: phone,
                    photoUrl: photoUrl,
                  );
                },
```

- [ ] **Step 8: Show the photo in the home greetings**

In both `customer_home_screen.dart` and `provider_home_screen.dart`, the greeting's leading `Container`/`Icon(Icons.person_rounded, ...)` (already touched in Task 2) should prefer `user.photoUrl` the same way as Step 6 above — wrap in the same photo-or-icon pattern using `RemoteImage`.

- [ ] **Step 9: Verify with `flutter analyze`**

Run: `flutter analyze lib/`
Expected: `No issues found!`

- [ ] **Step 10: Manual check**

Open Profile, tap the avatar, pick a photo — confirm it uploads, saves, and immediately shows both in the profile screen and (thanks to Task 2's stream fix) on the home screen greeting without restarting.

- [ ] **Step 11: Commit**

```bash
git add lib/core/models/user_model.dart lib/features/auth/services/auth_service.dart lib/core/widgets/profile/profile_tab.dart lib/core/widgets/profile/profile_settings_scaffold.dart lib/home/customer_home_screen.dart lib/home/provider_home_screen.dart test/app_user_photo_test.dart
git commit -m "feat: profile photo upload via Cloudinary"
```

---

### Task 10: Email change flow

**Files:**
- Create: `lib/features/auth/screens/change_email_screen.dart`
- Modify: `lib/features/auth/services/auth_service.dart` (new `changeEmail` method)
- Modify: `lib/core/widgets/profile/settings_tab.dart` (new "Change email" row)
- Modify: `lib/core/routes/route_names.dart`
- Modify: `lib/core/routes/app_router.dart`
- Test: `test/change_email_test.dart`

**Interfaces:**
- Produces: `AuthService.instance.changeEmail({required String currentPassword, required String newEmail})` → `Future<void>`. Live mode: `reauthenticateWithCredential` (via `EmailAuthProvider.credential`) then `verifyBeforeUpdateEmail(newEmail)` — the Firestore `users/{uid}.email` field is intentionally **not** updated by this call; it's updated by `login()`'s existing doc-sync path once the user next signs in with the new, now-verified address (matches how `emailVerified` already syncs lazily on login, per the existing comment in `login()`). Simulation mode: validates against `_passwords`, then updates the in-memory user's email directly (no real verification step to model).

- [ ] **Step 1: Write the failing test for the simulation-mode path**

Create `test/change_email_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/auth/services/auth_service.dart';

void main() {
  setUp(() => AuthService.instance.resetForTesting());

  test('changeEmail rejects the wrong current password', () async {
    await AuthService.instance.register(
      name: 'Test User',
      email: 'old@example.com',
      password: 'correct-password',
      role: UserRole.customer,
    );

    expect(
      () => AuthService.instance.changeEmail(
        currentPassword: 'wrong-password',
        newEmail: 'new@example.com',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('changeEmail updates the signed-in user\'s email on success', () async {
    await AuthService.instance.register(
      name: 'Test User',
      email: 'old@example.com',
      password: 'correct-password',
      role: UserRole.customer,
    );

    await AuthService.instance.changeEmail(
      currentPassword: 'correct-password',
      newEmail: 'new@example.com',
    );

    final user = await AuthService.instance.currentUser();
    expect(user?.email, 'new@example.com');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/change_email_test.dart`
Expected: FAIL — `changeEmail` is not defined on `AuthService`.

- [ ] **Step 3: Implement `changeEmail` on `AuthService`**

In `lib/features/auth/services/auth_service.dart`, add near `updateProfile`:

```dart
  // ── Email change ────────────────────────────────────────────────

  /// Changes the signed-in user's email. Requires re-entering the current
  /// password (Firebase requires recent re-authentication before an email
  /// change; simulation mode mirrors that requirement for consistency).
  ///
  /// Live mode sends a verification link to [newEmail] and does **not**
  /// flip `users/{uid}.email` yet — Firebase only updates its own record
  /// once the link is clicked, and this app has no server-side listener for
  /// that. `login()` already reconciles `emailVerified` lazily against
  /// Firebase's live value on next sign-in; the same reconciliation needs to
  /// cover `email` once this ships (tracked as follow-up, not blocking this
  /// change — see docs/superpowers/specs/2026-08-18-punch-list-design.md).
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final trimmedEmail = newEmail.trim().toLowerCase();
    final current = _currentUser;
    if (current == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }

    if (!_live) {
      if (_passwords[current.id] != currentPassword) {
        throw AuthException('wrong-password', 'Incorrect password.');
      }
      final updated = current.copyWith(updatedAt: DateTime.now());
      final withNewEmail = AppUser(
        id: updated.id,
        email: trimmedEmail,
        role: updated.role,
        createdAt: updated.createdAt,
        phone: updated.phone,
        name: updated.name,
        photoUrl: updated.photoUrl,
        emailVerified: updated.emailVerified,
        onboardingComplete: updated.onboardingComplete,
        accountStatus: updated.accountStatus,
        isVerified: updated.isVerified,
        customerProfile: updated.customerProfile,
        providerProfile: updated.providerProfile,
        updatedAt: DateTime.now(),
      );
      _userDb[withNewEmail.id] = withNewEmail;
      _currentUser = withNewEmail;
      _userChanges.add(withNewEmail);
      return;
    }

    final auth = FirebaseService.instance.auth;
    final fUser = auth.currentUser;
    if (fUser == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }
    final credential = fb_auth.EmailAuthProvider.credential(
      email: current.email,
      password: currentPassword,
    );
    await fUser.reauthenticateWithCredential(credential);
    await fUser.verifyBeforeUpdateEmail(trimmedEmail);
  }
```

(`AppUser` has no `copyWith` support for changing `email` by design — it's an identity field everywhere else in the app — so simulation mode constructs a new `AppUser` directly here rather than adding an `email` param to the general-purpose `copyWith`, keeping that guard everywhere else.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/change_email_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Verify with `flutter analyze`**

Run: `flutter analyze lib/features/auth/services/auth_service.dart`
Expected: `No issues found!`

- [ ] **Step 6: Add the route**

`lib/core/routes/route_names.dart`:

```dart
  static const changeEmail = '/auth/change-email';
```

`lib/core/routes/app_router.dart` — import and case:

```dart
import '../../features/auth/screens/change_email_screen.dart';
```

```dart
      case RouteNames.changeEmail:
        return _page(const ChangeEmailScreen(), settings);
```

- [ ] **Step 7: Build `ChangeEmailScreen`**, mirroring `password_reset_screen.dart`'s structure

Create `lib/features/auth/screens/change_email_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthService.instance.changeEmail(
        currentPassword: _passwordController.text,
        newEmail: _newEmailController.text,
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _sent ? _buildSentState() : _buildForm(),
      ),
    );
  }

  Widget _buildSentState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.mark_email_read_rounded,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        Text('Verify your new email', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to ${_newEmailController.text.trim()}. '
          'Your email changes once you click it.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Back to Settings',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.alternate_email_rounded,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm your password, then enter the new email address.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'New email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              return Validators.email(v);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Send verification link',
            loading: _submitting,
            useGradient: true,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Add the Settings row**

In `lib/core/widgets/profile/settings_tab.dart`, add next to the existing "Change Password" `ProfileTile` in the "Account" section:

```dart
        ProfileTile(
          icon: Icons.alternate_email_rounded,
          label: 'Change Email',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.changeEmail),
        ),
        const SizedBox(height: 8),
        const ProfileTile(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: null,
        ),
```

- [ ] **Step 9: Verify with `flutter analyze`**

Run: `flutter analyze lib/`
Expected: `No issues found!`

- [ ] **Step 10: Manual check**

As a signed-in user, Settings → Change Email → enter current password + new email → submit. Confirm the "verify your new email" confirmation screen appears, and (in live/Firebase mode) a verification email arrives at the new address. Signing in again with the old email should still work until the link is clicked (Firebase behavior — not something this app can change).

- [ ] **Step 11: Commit**

```bash
git add lib/features/auth/screens/change_email_screen.dart lib/features/auth/services/auth_service.dart lib/core/widgets/profile/settings_tab.dart lib/core/routes/route_names.dart lib/core/routes/app_router.dart test/change_email_test.dart
git commit -m "feat: change-email flow with re-auth and verification"
```

---

## Final full-suite check (run once, after all tasks)

- [ ] Run: `flutter analyze`
  Expected: `No issues found!`
- [ ] Run: `flutter test`
  Expected: all tests pass, including every new file added above alongside the pre-existing suite (`auth_service_test.dart`, `geo_broadcast_test.dart`, `job_lifecycle_test.dart`, `location_service_test.dart`, `matching_service_test.dart`, `payment_test.dart`, `rating_duplicate_test.dart`, `report_status_test.dart`, `trust_score_test.dart`, `widget_test.dart`).
- [ ] Launch the app (`flutter run`) and walk the manual-check steps from Tasks 1, 3, 4, 5, 6, 7, 8, 9, 10 in one pass, customer and provider role each, to confirm nothing regressed against the other's flow (e.g. Task 2's stream change doesn't break the splash-screen routing, Task 9's `ProfileTab.onSave` signature change is applied at both call sites, not just one).
