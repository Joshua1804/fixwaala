/// Temporary hold on a ticket while the customer decides whether to accept
/// a candidate provider. Enforced atomically on the backend.
class CandidateLease {
  final String ticketId;
  final String providerId;
  final DateTime leasedAt;
  final DateTime expiresAt;

  const CandidateLease({
    required this.ticketId,
    required this.providerId,
    required this.leasedAt,
    required this.expiresAt,
  });

  Duration get remaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }
}
