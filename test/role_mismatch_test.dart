import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/auth/screens/email_auth_screen.dart';

void main() {
  group('roleMismatchMessage', () {
    test('returns null when the account role matches the login page', () {
      expect(
        roleMismatchMessage(
          loginPageRole: UserRole.customer,
          accountRole: UserRole.customer,
        ),
        isNull,
      );
    });

    test('flags a provider account signing in on the customer page', () {
      final message = roleMismatchMessage(
        loginPageRole: UserRole.customer,
        accountRole: UserRole.provider,
      );
      expect(message, isNotNull);
      expect(message, contains('Provider'));
    });

    test('flags a customer account signing in on the provider page', () {
      final message = roleMismatchMessage(
        loginPageRole: UserRole.provider,
        accountRole: UserRole.customer,
      );
      expect(message, isNotNull);
      expect(message, contains('Customer'));
    });
  });
}
