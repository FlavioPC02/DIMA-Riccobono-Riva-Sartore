import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  String _registerErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with that email';
      case 'weak-password':
        return 'The password provided is too weak';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'network-request-failed':
        return 'Connection error';
      case 'operation-not-allowed':
        return 'Email/password sign up is not enabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return 'Sign up failed: ${e.code}';
    }
  }

  String _signInErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email or password is incorrect';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'network-request-failed':
        return 'Connection error';
      case 'operation-not-allowed':
        return 'Email/password login is not enabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'Login failed: ${e.code}';
    }
  }

  Future<User?> registerUser(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_registerErrorMessage(e));
    }
  }

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_signInErrorMessage(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
