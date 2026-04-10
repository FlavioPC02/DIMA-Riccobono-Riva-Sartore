import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  DatabaseService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _remoteUserDoc =>
      _db.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> get _remotePreferencesDoc =>
      _remoteUserDoc.collection('settings').doc('preferences');

  Future<void> createUser(String email, String nickname) async {
    try {
      await _remoteUserDoc.set({
        'uid': _uid,
        'nickname': nickname.trim(),
        'email': email.trim(),
        'accountCreated': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch(_) {
      throw Exception('Unable to reach the server');
    }
  }

  Future<Map<String, dynamic>?> fetchDocument(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final snapshot = await doc.get();
    return snapshot.data();
  }

  Future<void> saveDocument(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await doc.set(data, SetOptions(merge: merge));
  }

  Stream<Map<String, dynamic>?> streamDocument(
    DocumentReference<Map<String, dynamic>> doc,
  ) {
    return doc.snapshots().map((snapshot) => snapshot.data());
  }

  Future<Map<String, dynamic>?> fetchSettings() {
    return fetchDocument(_remotePreferencesDoc);
  }

  Future<void> saveSettings(Map<String, dynamic> data) {
    return saveDocument(_remotePreferencesDoc, data);
  }

  Stream<Map<String, dynamic>?> streamSettings() {
    return streamDocument(_remotePreferencesDoc);
  }

  Future<Map<String, dynamic>?> fetchProfile() {
    return fetchDocument(_remoteUserDoc);
  }

  Future<void> saveProfile(Map<String, dynamic> data) {
    return saveDocument(_remoteUserDoc, data);
  }

  Stream<Map<String, dynamic>?> streamProfile() {
    return streamDocument(_remoteUserDoc);
  }
}