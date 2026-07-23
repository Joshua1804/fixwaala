import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/user_model.dart';
import 'package:fixwaala/core/routes/route_names.dart';
import 'package:fixwaala/features/auth/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService.instance.resetForTesting();
  });

  group('Registration', () {
    test('creates an unverified, un-onboarded customer account', () async {
      final user = await AuthService.instance.register(
        name: 'Priya Sharma',
        email: 'priya@example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      expect(user.role, UserRole.customer);
      expect(user.emailVerified, isFalse);
      expect(user.onboardingComplete, isFalse);
      expect(user.email, 'priya@example.com');
    });

    test('creates a provider account with the provider role', () async {
      final user = await AuthService.instance.register(
        name: 'Ravi Kumar',
        email: 'ravi@example.com',
        password: 'password123',
        role: UserRole.provider,
      );
      expect(user.role, UserRole.provider);
    });

    test('rejects registering as admin', () async {
      expect(
        () => AuthService.instance.register(
          name: 'Sneaky',
          email: 'sneaky@example.com',
          password: 'password123',
          role: UserRole.admin,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a duplicate email', () async {
      await AuthService.instance.register(
        name: 'First',
        email: 'dup@example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      expect(
        () => AuthService.instance.register(
          name: 'Second',
          email: 'dup@example.com',
          password: 'differentpass',
          role: UserRole.provider,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('email matching is case-insensitive for duplicates', () async {
      await AuthService.instance.register(
        name: 'First',
        email: 'Case@Example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      expect(
        () => AuthService.instance.register(
          name: 'Second',
          email: 'case@example.com',
          password: 'password123',
          role: UserRole.customer,
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('Login', () {
    test('succeeds with correct credentials', () async {
      await AuthService.instance.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'correct-password',
        role: UserRole.customer,
      );
      await AuthService.instance.signOut();

      final user = await AuthService.instance.login(
        email: 'priya@example.com',
        password: 'correct-password',
      );
      expect(user.email, 'priya@example.com');
    });

    test('fails with wrong password', () async {
      await AuthService.instance.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'correct-password',
        role: UserRole.customer,
      );
      expect(
        () => AuthService.instance.login(
          email: 'priya@example.com',
          password: 'wrong-password',
        ),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'wrong-password'),
        ),
      );
    });

    test('fails for an unknown email', () async {
      expect(
        () => AuthService.instance.login(
          email: 'nobody@example.com',
          password: 'whatever',
        ),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'user-not-found'),
        ),
      );
    });
  });

  group('Password reset', () {
    test('throws for an unknown email', () {
      expect(
        () => AuthService.instance.sendPasswordResetEmail('nobody@example.com'),
        throwsA(isA<AuthException>()),
      );
    });

    test('succeeds silently for a known email', () async {
      await AuthService.instance.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      await AuthService.instance.sendPasswordResetEmail('priya@example.com');
      // No exception thrown = success.
    });
  });

  group('Email verification gating', () {
    test('an unverified user is routed to email verification', () async {
      await AuthService.instance.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      expect(
        await AuthService.instance.resolveInitialRoute(),
        RouteNames.emailVerification,
      );
    });

    test('simulateVerifyEmail unlocks progression to onboarding', () async {
      await AuthService.instance.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      AuthService.instance.simulateVerifyEmail();
      expect(
        await AuthService.instance.resolveInitialRoute(),
        RouteNames.customerOnboarding,
      );
    });
  });

  group('Role-based routing (the customer/provider same-page bug)', () {
    test(
      'a verified, onboarded customer routes to the customer home',
      () async {
        await AuthService.instance.register(
          name: 'Priya',
          email: 'customer@example.com',
          password: 'password123',
          role: UserRole.customer,
        );
        AuthService.instance.simulateVerifyEmail();
        await AuthService.instance.completeOnboarding(
          customerProfile: const CustomerProfile(addressLine: '221B Baker St'),
        );
        expect(
          await AuthService.instance.resolveInitialRoute(),
          RouteNames.customerHome,
        );
      },
    );

    test(
      'a verified, onboarded provider routes to the provider home',
      () async {
        await AuthService.instance.register(
          name: 'Ravi',
          email: 'provider@example.com',
          password: 'password123',
          role: UserRole.provider,
        );
        AuthService.instance.simulateVerifyEmail();
        await AuthService.instance.completeOnboarding(
          providerProfile: const ProviderProfile(
            skills: [ServiceCategory.plumber],
          ),
        );
        expect(
          await AuthService.instance.resolveInitialRoute(),
          RouteNames.providerHome,
        );
      },
    );

    test(
      'customer and provider destinations are never the same route',
      () async {
        await AuthService.instance.register(
          name: 'Priya',
          email: 'customer2@example.com',
          password: 'password123',
          role: UserRole.customer,
        );
        AuthService.instance.simulateVerifyEmail();
        await AuthService.instance.completeOnboarding(
          customerProfile: const CustomerProfile(),
        );
        final customerRoute = await AuthService.instance.resolveInitialRoute();
        await AuthService.instance.signOut();

        await AuthService.instance.register(
          name: 'Ravi',
          email: 'provider2@example.com',
          password: 'password123',
          role: UserRole.provider,
        );
        AuthService.instance.simulateVerifyEmail();
        await AuthService.instance.completeOnboarding(
          providerProfile: const ProviderProfile(),
        );
        final providerRoute = await AuthService.instance.resolveInitialRoute();

        expect(customerRoute, isNot(equals(providerRoute)));
        expect(customerRoute, RouteNames.customerHome);
        expect(providerRoute, RouteNames.providerHome);
      },
    );

    test(
      'a verified but not-yet-onboarded provider is routed to provider onboarding, not customer onboarding',
      () async {
        await AuthService.instance.register(
          name: 'Ravi',
          email: 'provider3@example.com',
          password: 'password123',
          role: UserRole.provider,
        );
        AuthService.instance.simulateVerifyEmail();
        expect(
          await AuthService.instance.resolveInitialRoute(),
          RouteNames.providerOnboarding,
        );
      },
    );
  });

  group('Session', () {
    test('no signed-in user routes to role selection', () async {
      expect(
        await AuthService.instance.resolveInitialRoute(),
        RouteNames.roleSelection,
      );
    });

    test('signOut clears the current user', () async {
      await AuthService.instance.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'password123',
        role: UserRole.customer,
      );
      expect(await AuthService.instance.currentUser(), isNotNull);
      await AuthService.instance.signOut();
      expect(await AuthService.instance.currentUser(), isNull);
      expect(
        await AuthService.instance.resolveInitialRoute(),
        RouteNames.roleSelection,
      );
    });
  });

  group('friendlyMessage', () {
    test('maps known auth error codes to readable text', () {
      expect(
        AuthService.friendlyMessage(
          AuthException('email-already-in-use', 'raw'),
        ),
        'An account already exists for that email.',
      );
      expect(
        AuthService.friendlyMessage(AuthException('wrong-password', 'raw')),
        'Incorrect email or password.',
      );
    });
  });
}
