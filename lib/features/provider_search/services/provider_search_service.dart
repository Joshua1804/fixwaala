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

  return all.where((p) => p.name.toLowerCase().contains(trimmed)).toList();
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
