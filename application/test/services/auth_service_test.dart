import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:application/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  const String tEmail = 'test@example.com';
  const String tPassword = 'password123';

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    
    authService = AuthService(auth: mockAuth);

    when(() => mockUserCredential.user).thenReturn(mockUser);
  });

  group('registerUser', () {
    test('returns a User upon successful registration', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: tEmail,
            password: tPassword,
          )).thenAnswer((_) async => mockUserCredential);

      final result = await authService.registerUser(tEmail, tPassword);

      expect(result, mockUser);
      verify(() => mockAuth.createUserWithEmailAndPassword(
            email: tEmail,
            password: tPassword,
          )).called(1);
    });

    final Map<String, String> errorTests = {
      'email-already-in-use': 'An account already exists with that email',
      'weak-password': 'The password provided is too weak',
      'invalid-email': 'Please enter a valid email address',
      'network-request-failed': 'Connection error',
      'operation-not-allowed': 'Email/password sign up is not enabled',
      'too-many-requests': 'Too many attempts. Try again later',
      'unhandled-error': 'Sign up failed: unhandled-error',
    };

    errorTests.forEach((code, expectedMessage) {
      test('throws an Exception with the message "$expectedMessage" if Firebase returns "$code"', () async {
        when(() => mockAuth.createUserWithEmailAndPassword(
              email: tEmail,
              password: tPassword,
            )).thenThrow(FirebaseAuthException(code: code));

        expect(
          () => authService.registerUser(tEmail, tPassword),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'messaggio di errore',
              contains(expectedMessage),
            ),
          ),
        );
      });
    });
  });

  group('signIn', () {
    test('returns a User upon successful login', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: tEmail,
            password: tPassword,
          )).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signIn(email: tEmail, password: tPassword);

      expect(result, mockUser);
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: tEmail,
            password: tPassword,
          )).called(1);
    });

    final Map<String, String> errorTests = {
      'invalid-credential': 'Email or password is incorrect',
      'user-not-found': 'Email or password is incorrect',
      'wrong-password': 'Email or password is incorrect',
      'invalid-email': 'Please enter a valid email address',
      'network-request-failed': 'Connection error',
      'operation-not-allowed': 'Email/password login is not enabled',
      'too-many-requests': 'Too many attempts. Try again later',
      'user-disabled': 'This account has been disabled',
      'unhandled-error': 'Login failed: unhandled-error',
    };

    errorTests.forEach((code, expectedMessage) {
      test('throws an Exception with the message "$expectedMessage" if Firebase returns "$code"', () async {
        when(() => mockAuth.signInWithEmailAndPassword(
              email: tEmail,
              password: tPassword,
            )).thenThrow(FirebaseAuthException(code: code));

        expect(
          () => authService.signIn(email: tEmail, password: tPassword),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'messaggio di errore',
              contains(expectedMessage),
            ),
          ),
        );
      });
    });
  });

  group('signOut', () {
    test('calls the signOut method of FirebaseAuth', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockAuth.signOut()).called(1);
    });
  });
}