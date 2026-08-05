import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/provider_public_profile.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import '../../features/auth/services/auth_service.dart';

/// Owns `providerPublicProfiles/{uid}` — the only view of another user's
/// account the rules allow a customer to see.
///
/// `users/{uid}` carries phone, address, pincode, and live GPS, so it is
/// readable by its owner alone. A customer choosing between candidates still
/// has to see who they are considering, so each provider publishes a redacted
/// copy of themselves here and everyone else reads that.
///
/// The provider being their own publisher only works because the rules do not
/// take their word for [ProviderPublicProfile.isVerified]: a write is rejected
/// unless the flag matches `users/{uid}.isVerified`, which is administrator-set
/// and cannot be self-assigned. Every other field is the provider's own to
/// state — a fake name or skill list is a moderation problem, not a hole in
/// the trust badge.
class ProviderDirectoryService {
  ProviderDirectoryService._();
  static final ProviderDirectoryService instance = ProviderDirectoryService._();

  bool get _live => FirebaseService.instance.isInitialized;

  /// Last projection written, per user, so the redundant writes below are
  /// skipped. A provider's own document changes every few seconds while they
  /// are online — the live GPS write — and none of those changes affect the
  /// public projection.
  final Map<String, String> _lastPublished = {};

  @visibleForTesting
  void resetForTesting() => _lastPublished.clear();

  /// The subset of [user] that is safe to publish.
  ///
  /// Built by naming what may be published rather than by removing what may
  /// not, so a field added to [AppUser] later cannot leak here by default.
  Map<String, dynamic> _projectionOf(AppUser user) {
    final profile = user.providerProfile;
    return {
      'id': user.id,
      'name': user.name ?? 'Provider',
      'isVerified': user.isVerified,
      'createdAt': user.createdAt.toIso8601String(),
      'skills': (profile?.skills ?? const []).map((s) => s.name).toList(),
      'experienceYears': profile?.experienceYears,
      'serviceArea': profile?.serviceArea,
    };
  }

  /// Republishes the signed-in provider's public profile if it has changed.
  ///
  /// Called from the account's own live listener, so it also reconciles a
  /// badge granted in the admin website: the flag lands on `users/{uid}`, the
  /// provider's own device sees the change, and the mirror follows. Until that
  /// device next opens the app the mirror simply reads `false` — the profile
  /// screen under-claims rather than over-claims, which is the safe direction.
  Future<void> publishSelf(AppUser user) async {
    if (!_live || user.role != UserRole.provider) return;

    final projection = _projectionOf(user);
    final fingerprint = projection.toString();
    if (_lastPublished[user.id] == fingerprint) return;

    try {
      await FirebaseService.instance.firestore
          .collection('providerPublicProfiles')
          .doc(user.id)
          .set(projection);
      _lastPublished[user.id] = fingerprint;
    } catch (error) {
      // Never block the session on this. The profile screen degrades to a
      // nameless candidate; the confirm flow reads the candidate lease and
      // keeps working.
      debugPrint('[ProviderDirectory] Could not publish public profile: $error');
    }
  }

  /// Drops the cached fingerprints so the next sign-in republishes.
  void endSession() => _lastPublished.clear();

  /// The public profile for [providerId], or null if none has been published.
  Future<ProviderPublicProfile?> fetch(String providerId) async {
    if (!_live) {
      final user = await AuthService.instance.getUserById(providerId);
      if (user == null) return null;
      final profile = user.providerProfile;
      return ProviderPublicProfile(
        id: user.id,
        name: user.name ?? 'Provider',
        isVerified: user.isVerified,
        createdAt: user.createdAt,
        skills: profile?.skills ?? const [],
        experienceYears: profile?.experienceYears,
        serviceArea: profile?.serviceArea,
      );
    }

    final doc = await FirebaseService.instance.firestore
        .collection('providerPublicProfiles')
        .doc(providerId)
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return ProviderPublicProfile.fromMap(data);
  }
}
