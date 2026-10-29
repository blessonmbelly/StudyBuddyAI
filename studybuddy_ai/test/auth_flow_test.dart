import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studybuddy_ai/models/auth_user.dart';
import 'package:studybuddy_ai/screens/home_screen.dart';
import 'package:studybuddy_ai/screens/login_screen.dart';
import 'package:studybuddy_ai/screens/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AuthUser Model Tests', () {
    test('Correctly deserializes backend UserResponse JSON', () {
      final json = {
        'id': 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
        'email': 'student@mit.edu',
        'full_name': 'Ada Lovelace',
        'is_active': true,
        'created_at': '2026-10-28T22:30:00Z',
      };

      final user = AuthUser.fromJson(json);

      expect(user.id, 'a1b2c3d4-e5f6-7890-1234-567890abcdef');
      expect(user.email, 'student@mit.edu');
      expect(user.fullName, 'Ada Lovelace');
      expect(user.isActive, true);
      expect(user.createdAt, DateTime.parse('2026-10-28T22:30:00Z'));
      expect(user.displayName, 'Ada Lovelace');
      expect(user.avatarInitial, 'A');
    });

    test('displayName and avatarInitial fall back safely when fullName is null', () {
      final json = {
        'id': '12345',
        'email': 'grace.hopper@navy.mil',
        'full_name': null,
        'is_active': true,
      };

      final user = AuthUser.fromJson(json);

      expect(user.displayName, 'Grace Hopper');
      expect(user.avatarInitial, 'G');
    });

    test('displayName falls back to Student when email is also empty', () {
      const user = AuthUser(
        id: '0',
        email: '',
        fullName: null,
      );

      expect(user.displayName, 'Student');
      expect(user.avatarInitial, 'S');
    });

    test('toJson and copyWith work as expected', () {
      const user = AuthUser(
        id: '1',
        email: 'test@example.com',
        fullName: 'Test User',
      );

      final updated = user.copyWith(fullName: 'Updated Name');
      expect(updated.fullName, 'Updated Name');
      expect(updated.id, '1');

      final serialized = updated.toJson();
      expect(serialized['full_name'], 'Updated Name');
      expect(serialized['email'], 'test@example.com');
    });
  });

  group('HomeScreen Authentication UI Tests', () {
    testWidgets('Displays authenticated user name and avatar initial', (WidgetTester tester) async {
      const testUser = AuthUser(
        id: 'user-123',
        email: 'blesson@studybuddy.ai',
        fullName: 'Blesson Dev',
      );

      bool logoutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: testUser,
            onLogout: () {
              logoutCalled = true;
            },
            onNavigateTab: (_, {scanMode}) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and greeting display real user details
      expect(find.text('Welcome back, Blesson Dev 👋'), findsOneWidget);
      expect(find.text('B'), findsWidgets); // Avatar initial in circle

      // Tap on avatar to open profile bottom sheet
      await tester.tap(find.text('B').first);
      await tester.pumpAndSettle();

      // Verify bottom sheet shows user profile
      expect(find.text('blesson@studybuddy.ai'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Tap Sign Out
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(logoutCalled, isTrue);
    });
  });

  group('LoginScreen Form Validation Tests', () {
    testWidgets('Validates required email and password', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onLoginSuccess: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Sign In button without entering credentials
      final signInButton = find.text('Sign In');
      expect(signInButton, findsOneWidget);
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Validation errors should appear
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });
  });

  group('RegisterScreen Form Validation Tests', () {
    testWidgets('Validates matching passwords and password length', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            onRegisterSuccess: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      final createAccountBtn = find.text('Create Account');
      expect(createAccountBtn, findsOneWidget);

      // Enter mismatched passwords
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'John Doe'); // Full name
      await tester.enterText(fields.at(1), 'john@example.com'); // Email
      await tester.enterText(fields.at(2), 'password123'); // Password
      await tester.enterText(fields.at(3), 'password999'); // Confirm password

      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });
}
