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

  const ProviderProfile({
    this.skills = const [],
    this.experienceYears,
    this.serviceArea,
    this.availability,
  });

  factory ProviderProfile.fromMap(Map<String, dynamic> map) => ProviderProfile(
    skills: (map['skills'] as List<dynamic>? ?? [])
        .map((s) => ServiceCategory.values.byName(s as String))
        .toList(),
    experienceYears: map['experienceYears'] as int?,
    serviceArea: map['serviceArea'] as String?,
    availability: map['availability'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'skills': skills.map((s) => s.name).toList(),
    'experienceYears': experienceYears,
    'serviceArea': serviceArea,
    'availability': availability,
  };
}

/// A Fixwaala account. One document per user in Firestore's `users`
/// collection, keyed by the Firebase Auth uid.
class AppUser {
  final String id;
  final String email;
  final String? phone;
  final UserRole role;
  final String? name;
  final bool emailVerified;
  final bool onboardingComplete;
  final AccountStatus accountStatus;
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
    this.emailVerified = false,
    this.onboardingComplete = false,
    this.accountStatus = AccountStatus.active,
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
      emailVerified: map['emailVerified'] as bool? ?? false,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      accountStatus: AccountStatus.values.byName(
        map['accountStatus'] as String? ?? 'active',
      ),
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
    'emailVerified': emailVerified,
    'onboardingComplete': onboardingComplete,
    'accountStatus': accountStatus.name,
    if (customerProfile != null) 'customerProfile': customerProfile!.toMap(),
    if (providerProfile != null) 'providerProfile': providerProfile!.toMap(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
  };

  AppUser copyWith({
    String? phone,
    String? name,
    bool? emailVerified,
    bool? onboardingComplete,
    AccountStatus? accountStatus,
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
      emailVerified: emailVerified ?? this.emailVerified,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      accountStatus: accountStatus ?? this.accountStatus,
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
