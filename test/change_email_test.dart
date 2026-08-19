import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/auth/services/auth_service.dart';

void main() {
  setUp(() => AuthService.instance.resetForTesting());

  test('changeEmail rejects the wrong current password', () async {
    await AuthService.instance.register(
      name: 'Test User',
      email: 'old@example.com',
      password: 'correct-password',
      role: UserRole.customer,
    );

    expect(
      () => AuthService.instance.changeEmail(
        currentPassword: 'wrong-password',
        newEmail: 'new@example.com',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test("changeEmail updates the signed-in user's email on success", () async {
    await AuthService.instance.register(
      name: 'Test User',
      email: 'old@example.com',
      password: 'correct-password',
      role: UserRole.customer,
    );

    await AuthService.instance.changeEmail(
      currentPassword: 'correct-password',
      newEmail: 'new@example.com',
    );

    final user = await AuthService.instance.currentUser();
    expect(user?.email, 'new@example.com');
  });
}
