/// Small display helpers that were previously copy-pasted per screen —
/// `_formatDate` existed verbatim in three files and `_initials` in two.
library;

/// Human-friendly relative timestamps ("2h ago", "Yesterday").
class RelativeTime {
  RelativeTime._();

  static String format(DateTime dt, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(dt);

    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Up to two uppercase initials for an avatar placeholder. Returns `'?'` for
/// a name that carries no letters, so the avatar is never blank.
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
