import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../ai_assist/models/clarifying_qa.dart';

class Ticket {
  final String id;
  final String customerId;
  final String customerName;
  final String description;
  final List<String> imageUrls;
  final ServiceCategory category;
  final ProblemComplexity complexity;
  final GeoPoint approximateLocation;
  final GeoPoint? exactLocation;
  final String? addressLine;
  final TicketStatus status;
  final String? assignedProviderId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ClarifyingQa> clarifyingQa;
  final String? aiSummary;
  final List<String> recommendedEquipment;
  final double broadcastRadiusKm;
  final DateTime? candidateWindowExpiresAt;

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
    this.customerName = '',
    this.exactLocation,
    this.addressLine,
    this.assignedProviderId,
    this.updatedAt,
    this.clarifyingQa = const [],
    this.aiSummary,
    this.recommendedEquipment = const [],
    this.broadcastRadiusKm = AppConstants.initialSearchRadiusKm,
    this.candidateWindowExpiresAt,
  });

  /// Whether this ticket is still "live" (not yet finished or cancelled).
  bool get isActive =>
      status != TicketStatus.completed &&
      status != TicketStatus.paid &&
      status != TicketStatus.closed &&
      status != TicketStatus.cancelled &&
      status != TicketStatus.failed;

  Ticket copyWith({
    TicketStatus? status,
    String? assignedProviderId,
    GeoPoint? exactLocation,
    DateTime? updatedAt,
    double? broadcastRadiusKm,
    DateTime? candidateWindowExpiresAt,
    bool clearCandidateWindowExpiresAt = false,
  }) {
    return Ticket(
      id: id,
      customerId: customerId,
      customerName: customerName,
      description: description,
      imageUrls: imageUrls,
      category: category,
      complexity: complexity,
      approximateLocation: approximateLocation,
      status: status ?? this.status,
      createdAt: createdAt,
      exactLocation: exactLocation ?? this.exactLocation,
      addressLine: addressLine,
      assignedProviderId: assignedProviderId ?? this.assignedProviderId,
      updatedAt: updatedAt ?? DateTime.now(),
      clarifyingQa: clarifyingQa,
      aiSummary: aiSummary,
      recommendedEquipment: recommendedEquipment,
      broadcastRadiusKm: broadcastRadiusKm ?? this.broadcastRadiusKm,
      candidateWindowExpiresAt: clearCandidateWindowExpiresAt
          ? null
          : (candidateWindowExpiresAt ?? this.candidateWindowExpiresAt),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerId': customerId,
    'customerName': customerName,
    'description': description,
    'imageUrls': imageUrls,
    'category': category.name,
    'complexity': complexity.name,
    'approximateLocation': fs.GeoPoint(
      approximateLocation.latitude,
      approximateLocation.longitude,
    ),
    'status': status.name,
    if (assignedProviderId != null) 'assignedProviderId': assignedProviderId,
    if (addressLine != null && addressLine!.trim().isNotEmpty)
      'addressLine': addressLine,
    'createdAt': fs.Timestamp.fromDate(createdAt),
    'updatedAt': fs.Timestamp.fromDate(updatedAt ?? DateTime.now()),
    if (exactLocation != null)
      'exactLocation': fs.GeoPoint(
        exactLocation!.latitude,
        exactLocation!.longitude,
      ),
    'clarifyingQa': clarifyingQa.map((qa) => qa.toMap()).toList(),
    if (aiSummary != null && aiSummary!.trim().isNotEmpty)
      'aiSummary': aiSummary,
    'recommendedEquipment': recommendedEquipment,
    'broadcastRadiusKm': broadcastRadiusKm,
    if (candidateWindowExpiresAt != null)
      'candidateWindowExpiresAt': fs.Timestamp.fromDate(
        candidateWindowExpiresAt!,
      ),
  };

  /// The redacted view of this ticket that online providers are allowed to
  /// see while it is still matching, stored at `openTickets/{id}`.
  ///
  /// Deliberately omits `exactLocation`, `addressLine`, and `customerName`.
  /// A ticket has to be discoverable by nearby providers, but the full
  /// document carries the customer's precise home coordinates — the exact
  /// thing the product promises not to reveal until a provider is confirmed.
  /// Providers get an approximate location and the problem details, nothing
  /// that identifies or locates the household.
  ///
  /// Keep this field set in sync with `expireLeasesForTicket` in
  /// `functions/scheduled.js`, which rebuilds the same `openTickets/{id}`
  /// projection server-side after a candidate lease expires. The two are
  /// maintained independently in two different languages, so a field added
  /// to one and not the other will silently drift.
  Map<String, dynamic> toBroadcastMap() => {
    'id': id,
    'customerId': customerId,
    // First name only until someone is actually assigned. The full name was
    // previously visible to every provider in range on every open ticket,
    // which let anyone who registered as a provider harvest names and
    // neighbourhoods at scale.
    'customerFirstName': customerFirstName,
    'description': description,
    'imageUrls': imageUrls,
    'category': category.name,
    'complexity': complexity.name,
    'approximateLocation': fs.GeoPoint(
      approximateLocation.latitude,
      approximateLocation.longitude,
    ),
    'status': status.name,
    'createdAt': fs.Timestamp.fromDate(createdAt),
    'updatedAt': fs.Timestamp.fromDate(updatedAt ?? DateTime.now()),
    'clarifyingQa': clarifyingQa.map((qa) => qa.toMap()).toList(),
    if (aiSummary != null && aiSummary!.trim().isNotEmpty)
      'aiSummary': aiSummary,
    'recommendedEquipment': recommendedEquipment,
    'broadcastRadiusKm': broadcastRadiusKm,
  };

  /// The customer's given name, for display before assignment.
  String get customerFirstName {
    final trimmed = customerName.trim();
    if (trimmed.isEmpty) return 'Customer';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  factory Ticket.fromMap(Map<String, dynamic> map) {
    final approxLoc = map['approximateLocation'];
    final exactLoc = map['exactLocation'];
    return Ticket(
      id: map['id'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName:
          map['customerName'] as String? ??
          map['customerFirstName'] as String? ??
          '',
      description: map['description'] as String? ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      category: ServiceCategory.values.byNameOrDefault(
        map['category'] as String?,
        ServiceCategory.unknown,
      ),
      complexity: ProblemComplexity.values.byNameOrDefault(
        map['complexity'] as String?,
        ProblemComplexity.low,
      ),
      approximateLocation: approxLoc is fs.GeoPoint
          ? GeoPoint(approxLoc.latitude, approxLoc.longitude)
          : const GeoPoint(0, 0),
      exactLocation: exactLoc is fs.GeoPoint
          ? GeoPoint(exactLoc.latitude, exactLoc.longitude)
          : null,
      addressLine: map['addressLine'] as String?,
      status: TicketStatus.values.byNameOrDefault(
        map['status'] as String?,
        TicketStatus.draft,
      ),
      assignedProviderId: map['assignedProviderId'] as String?,
      createdAt: map['createdAt'] is fs.Timestamp
          ? (map['createdAt'] as fs.Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                DateTime.now(),
      updatedAt: map['updatedAt'] is fs.Timestamp
          ? (map['updatedAt'] as fs.Timestamp).toDate()
          : null,
      clarifyingQa: (map['clarifyingQa'] as List<dynamic>? ?? [])
          .map((m) => ClarifyingQa.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      aiSummary: map['aiSummary'] as String?,
      recommendedEquipment: List<String>.from(
        map['recommendedEquipment'] ?? [],
      ),
      broadcastRadiusKm:
          (map['broadcastRadiusKm'] as num?)?.toDouble() ??
          AppConstants.initialSearchRadiusKm,
      candidateWindowExpiresAt: map['candidateWindowExpiresAt'] is fs.Timestamp
          ? (map['candidateWindowExpiresAt'] as fs.Timestamp).toDate()
          : null,
    );
  }
}
