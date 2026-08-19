import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import 'enums.dart';

/// A customer's onboarding profile — collected once, right after email
/// verification, before they can use the app.
class CustomerProfile {
  final String? addressLabel; // e.g. "Home", "Work"
  final String? addressLine;
  final String? city;
  final String? pincode;

  const CustomerProfile({
    this.addressLabel,
    this.addressLine,
    this.city,
    this.pincode,
  });

  factory CustomerProfile.fromMap(Map<String, dynamic> map) => CustomerProfile(
    addressLabel: map['addressLabel'] as String?,
    addressLine: map['addressLine'] as String?,
    city: map['city'] as String?,
    pincode: map['pincode'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'addressLabel': addressLabel,
    'addressLine': addressLine,
    'city': city,
    'pincode': pincode,
  };
}

/// A provider's onboarding profile — skills, experience, and availability.
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

/// A Fixwaala account. One document per user in Firestore's `users`
/// collection, keyed by the Firebase Auth uid.
class AppUser {
  final String id;
  final String email;
  final String? phone;
  final UserRole role;
  final String? name;
  final String? photoUrl;
  final bool emailVerified;
  final bool onboardingComplete;
  final AccountStatus accountStatus;

  /// Whether an administrator has manually reviewed and approved this
  /// provider. Written **only** by the admin website — the app seeds it to
  /// `false` at registration and never writes it again. Drives the "Verified"
  /// badge customers see when choosing a provider.
  final bool isVerified;

  final CustomerProfile? customerProfile;
  final ProviderProfile? providerProfile;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.phone,
    this.name,
    this.photoUrl,
    this.emailVerified = false,
    this.onboardingComplete = false,
    this.accountStatus = AccountStatus.active,
    this.isVerified = false,
    this.customerProfile,
    this.providerProfile,
    this.updatedAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      role: UserRole.values.byName(map['role'] as String),
      name: map['name'] as String?,
      photoUrl: map['photoUrl'] as String?,
      emailVerified: map['emailVerified'] as bool? ?? false,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      accountStatus: AccountStatus.values.byName(
        map['accountStatus'] as String? ?? 'active',
      ),
      isVerified: map['isVerified'] as bool? ?? false,
      customerProfile: map['customerProfile'] != null
          ? CustomerProfile.fromMap(
              Map<String, dynamic>.from(map['customerProfile'] as Map),
            )
          : null,
      providerProfile: map['providerProfile'] != null
          ? ProviderProfile.fromMap(
              Map<String, dynamic>.from(map['providerProfile'] as Map),
            )
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'phone': phone,
    'role': role.name,
    'name': name,
    'photoUrl': photoUrl,
    'emailVerified': emailVerified,
    'onboardingComplete': onboardingComplete,
    'accountStatus': accountStatus.name,
    // Seeded false at creation; only the admin website updates it thereafter.
    'isVerified': isVerified,
    if (customerProfile != null) 'customerProfile': customerProfile!.toMap(),
    if (providerProfile != null) 'providerProfile': providerProfile!.toMap(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
  };

  AppUser copyWith({
    String? phone,
    String? name,
    String? photoUrl,
    bool? emailVerified,
    bool? onboardingComplete,
    AccountStatus? accountStatus,
    bool? isVerified,
    CustomerProfile? customerProfile,
    ProviderProfile? providerProfile,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      email: email,
      role: role,
      createdAt: createdAt,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      accountStatus: accountStatus ?? this.accountStatus,
      isVerified: isVerified ?? this.isVerified,
      customerProfile: customerProfile ?? this.customerProfile,
      providerProfile: providerProfile ?? this.providerProfile,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}
