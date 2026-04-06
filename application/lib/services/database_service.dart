import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser!.uid; 

  Future<void> createUser(String email, String nickname) async {
    try {
      await _db.collection('users').doc(_uid).set({
        'uid': _uid,
        'nickname': nickname.trim(),
        'email': email.trim(),
        'accountCreated': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch(_) {
      throw Exception('Unable to reach the server');
    }
  }
}