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

  CollectionReference<Map<String, dynamic>> get _activitiesCollection =>
      _remoteUserDoc.collection('activities');

  CollectionReference<Map<String, dynamic>> get _favoriteTrailsCollection =>
      _remoteUserDoc.collection('favoriteTrails');

  Future<void> createUser(String email, String nickname) async {
    try {
      await _remoteUserDoc.set({
        'uid': _uid,
        'nickname': nickname.trim(),
        'email': email.trim(),
        'accountCreated': FieldValue.serverTimestamp(),
        'level': 0,
        'xp': 0,
      });
    } on FirebaseException catch (_) {
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

  Future<String> addActivity(Map<String, dynamic> data) async {
    final doc = await _activitiesCollection.add(data);
    return doc.id;
  }

  Future<void> updateActivity(String id, Map<String, dynamic> data) {
    return _activitiesCollection.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteActivity(String id) {
    return _activitiesCollection.doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> streamActivities() {
    return _activitiesCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<Map<String, dynamic>?> fetchActivity(String id) async {
    final snapshot = await _activitiesCollection
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (snapshot.exists && snapshot.data() != null) {
      return snapshot.data();
    }
    return null;
  }

  Future<void> addNoteToArray(
    String activityId,
    Map<String, dynamic> noteJson,
  ) async {
    try {
      await _activitiesCollection.doc(activityId).set({
        'notes': FieldValue.arrayUnion([noteJson]),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeNoteFromArray(
    String activityId,
    Map<String, dynamic> noteJson,
  ) async {
    await _activitiesCollection.doc(activityId).set({
      'notes': FieldValue.arrayRemove([noteJson]),
    }, SetOptions(merge: true));
  }

  Future<void> saveFavoriteTrail(String id, Map<String, dynamic> data) {
    return _favoriteTrailsCollection.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteFavoriteTrail(String id) {
    return _favoriteTrailsCollection.doc(id).delete();
  }

  Future<bool> isFavoriteTrail(String id) async {
    final snapshot = await _favoriteTrailsCollection.doc(id).get();
    return snapshot.exists;
  }

  Stream<List<Map<String, dynamic>>> streamFavoriteTrails() {
    return _favoriteTrailsCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }
}
