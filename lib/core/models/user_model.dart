import 'enums.dart';

class AppUser {
  final String id;
  final String phone;
  final UserRole role;
  final String? name;
  final String? email;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.name,
    this.email,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      phone: map['phone'] as String,
      role: UserRole.values.byName(map['role'] as String),
      name: map['name'] as String?,
      email: map['email'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'phone': phone,
        'role': role.name,
        'name': name,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };
}

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}
