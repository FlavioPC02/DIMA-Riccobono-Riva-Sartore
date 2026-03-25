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
}