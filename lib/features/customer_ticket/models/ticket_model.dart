import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';

class Ticket {
  final String id;
  final String customerId;
  final String description;
  final List<String> imageUrls;
  final ServiceCategory category;
  final ProblemComplexity complexity;
  final GeoPoint approximateLocation;
  final GeoPoint? exactLocation; // Revealed only after provider confirmed.
  final String? addressLine;
  final TicketStatus status;
  final String? assignedProviderId;
  final DateTime createdAt;

  const Ticket({
    required this.id,
    required this.customerId,
    required this.description,
    required this.imageUrls,
    required this.category,
    required this.complexity,
    required this.approximateLocation,
    required this.status,
    required this.createdAt,
    this.exactLocation,
    this.addressLine,
    this.assignedProviderId,
  });
}
