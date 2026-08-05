/// Travel-time estimate shown alongside a provider's distance.
///
/// The same `(distanceKm * 2)` expression was written out in two places —
/// `MatchingService.acceptOpportunity` and the provider's opportunity card —
/// so the number could drift between the two screens showing it.
///
/// It is a straight-line distance divided by an assumed average speed: no
/// routing, no traffic, no mode of transport. Present it as an estimate, never
/// as a commitment.
class EtaEstimate {
  EtaEstimate._();

  /// Assumed average urban travel speed.
  static const double assumedSpeedKmh = 30;

  static int minutesFor(double distanceKm) =>
      (distanceKm / assumedSpeedKmh * 60).round().clamp(1, 999);

  /// Label that makes the uncertainty explicit.
  static String labelFor(double distanceKm) =>
      'approx. ${minutesFor(distanceKm)} min away';
}
