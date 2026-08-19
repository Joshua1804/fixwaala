import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/user_model.dart';

void main() {
  test('photoUrl round-trips through toMap/fromMap', () {
    final user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      role: UserRole.customer,
      createdAt: DateTime(2026, 1, 1),
      photoUrl: 'https://res.cloudinary.com/demo/image/upload/avatar.jpg',
    );
    final restored = AppUser.fromMap(user.toMap());
    expect(restored.photoUrl, user.photoUrl);
  });

  test('copyWith updates photoUrl without touching other fields', () {
    final user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      role: UserRole.customer,
      createdAt: DateTime(2026, 1, 1),
      name: 'Original Name',
    );
    final updated = user.copyWith(photoUrl: 'https://example.com/p.jpg');
    expect(updated.photoUrl, 'https://example.com/p.jpg');
    expect(updated.name, 'Original Name');
  });
}
