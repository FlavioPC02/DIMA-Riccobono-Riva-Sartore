import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> registerUser(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'email-already-in-use'){
        message = 'An account already exists with that email';
      } else if (e.code == 'weak-password'){
        message = 'The password provided is too weak';
      } else if (e.code == 'network-request-failed'){
        message = 'Connection error';
      } else {
        message = 'Unable to reach the server';
      }

      throw Exception(message);
    }
  }

  Future<User?> signIn({required String email, required String password}) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user';
      } else if (e.code == 'network-request-failed') {
        message = 'Connection error';
      } else {
        message = 'Unable to reach the server';
      }

      throw Exception(message);
    }
  }

}