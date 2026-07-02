// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:application/services/database_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockCollectionReference mockUsersCollection;
  late MockCollectionReference mockSettingsCollection;
  late MockCollectionReference mockActivitiesCollection;
  late MockCollectionReference mockFavoriteTrailsCollection;
  late MockDocumentReference mockUserDoc;
  late MockDocumentReference mockPreferencesDoc;
  late DatabaseService databaseService;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockUsersCollection = MockCollectionReference();
    mockSettingsCollection = MockCollectionReference();
    mockActivitiesCollection = MockCollectionReference();
    mockFavoriteTrailsCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockPreferencesDoc = MockDocumentReference();

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user-123');

    when(
      () => mockFirestore.collection('users'),
    ).thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc('user-123')).thenReturn(mockUserDoc);

    when(
      () => mockUserDoc.collection('settings'),
    ).thenReturn(mockSettingsCollection);
    when(
      () => mockSettingsCollection.doc('preferences'),
    ).thenReturn(mockPreferencesDoc);

    when(
      () => mockUserDoc.collection('activities'),
    ).thenReturn(mockActivitiesCollection);
    when(
      () => mockUserDoc.collection('favoriteTrails'),
    ).thenReturn(mockFavoriteTrailsCollection);

    databaseService = DatabaseService(db: mockFirestore, auth: mockAuth);
  });

  test(
    'createUser trims email and nickname and saves the correct document',
    () async {
      when(() => mockUserDoc.set(any(), any())).thenAnswer((_) async {});
      await databaseService.createUser(
        '  test@example.com  ',
        '  First User  ',
      );

      final capturedData =
          verify(() => mockUserDoc.set(captureAny(), any())).captured.single
              as Map<String, dynamic>;
      expect(capturedData['uid'], 'user-123');
      expect(capturedData['email'], 'test@example.com');
      expect(capturedData['nickname'], 'First User');
      expect(capturedData['accountCreated'], isA<FieldValue>());
    },
  );

  test('createUser throws Exception on FirebaseException', () async {
    when(
      () => mockUserDoc.set(any(), any()),
    ).thenThrow(FirebaseException(plugin: 'firestore'));
    await expectLater(
      databaseService.createUser('test@example.com', 'First User'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Unable to reach the server'),
        ),
      ),
    );
  });

  test('fetchDocument returns the underlying snapshot data', () async {
    final mockSnapshot = MockDocumentSnapshot();
    const documentData = {'key': 'value'};
    when(() => mockUserDoc.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.data()).thenReturn(documentData);

    final result = await databaseService.fetchDocument(mockUserDoc);
    expect(result, documentData);
  });

  test(
    'fetchSettings throws a StateError when the user is not authenticated',
    () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(() => databaseService.fetchSettings(), throwsStateError);
    },
  );

  test('saveSettings calls set with merge true', () async {
    when(() => mockPreferencesDoc.set(any(), any())).thenAnswer((_) async {});
    await databaseService.saveSettings({'theme': 'dark'});
    verify(() => mockPreferencesDoc.set({'theme': 'dark'}, any())).called(1);
  });

  test('streamSettings yields data', () {
    final mockSnapshot = MockDocumentSnapshot();
    when(() => mockSnapshot.data()).thenReturn({'theme': 'dark'});
    when(
      () => mockPreferencesDoc.snapshots(),
    ).thenAnswer((_) => Stream.value(mockSnapshot));

    expect(databaseService.streamSettings(), emits({'theme': 'dark'}));
  });

  test('fetchProfile returns profile data', () async {
    final mockSnapshot = MockDocumentSnapshot();
    when(() => mockUserDoc.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.data()).thenReturn({'nickname': 'Test'});

    final result = await databaseService.fetchProfile();
    expect(result, {'nickname': 'Test'});
  });

  test('saveProfile calls set with merge true', () async {
    when(() => mockUserDoc.set(any(), any())).thenAnswer((_) async {});
    await databaseService.saveProfile({'nickname': 'NewTest'});
    verify(() => mockUserDoc.set({'nickname': 'NewTest'}, any())).called(1);
  });

  test('streamProfile yields data', () {
    final mockSnapshot = MockDocumentSnapshot();
    when(() => mockSnapshot.data()).thenReturn({'nickname': 'Test'});
    when(
      () => mockUserDoc.snapshots(),
    ).thenAnswer((_) => Stream.value(mockSnapshot));

    expect(databaseService.streamProfile(), emits({'nickname': 'Test'}));
  });

  test('addActivity adds a document and returns its id', () async {
    final mockDocRef = MockDocumentReference();
    when(() => mockDocRef.id).thenReturn('activity-id');
    when(
      () => mockActivitiesCollection.add(any()),
    ).thenAnswer((_) async => mockDocRef);

    final id = await databaseService.addActivity({'name': 'Hike'});
    expect(id, 'activity-id');
    verify(() => mockActivitiesCollection.add({'name': 'Hike'})).called(1);
  });

  test('updateActivity updates the document', () async {
    final mockActivityDoc = MockDocumentReference();
    when(
      () => mockActivitiesCollection.doc('act-123'),
    ).thenReturn(mockActivityDoc);
    when(() => mockActivityDoc.set(any(), any())).thenAnswer((_) async {});

    await databaseService.updateActivity('act-123', {'name': 'Updated Hike'});
    verify(
      () => mockActivityDoc.set({'name': 'Updated Hike'}, any()),
    ).called(1);
  });

  test('deleteActivity deletes the document', () async {
    final mockActivityDoc = MockDocumentReference();
    when(
      () => mockActivitiesCollection.doc('act-123'),
    ).thenReturn(mockActivityDoc);
    when(() => mockActivityDoc.delete()).thenAnswer((_) async {});

    await databaseService.deleteActivity('act-123');
    verify(() => mockActivityDoc.delete()).called(1);
  });

  test('streamActivities yields mapped list of documents', () {
    final mockQuery = MockQuery();
    final mockQuerySnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(
      () => mockActivitiesCollection.orderBy('date', descending: true),
    ).thenReturn(mockQuery);
    when(
      () => mockQuery.snapshots(),
    ).thenAnswer((_) => Stream.value(mockQuerySnapshot));
    when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
    when(() => mockDoc.id).thenReturn('act-id');
    when(() => mockDoc.data()).thenReturn({'name': 'Hike'});

    expect(
      databaseService.streamActivities(),
      emits([
        {'id': 'act-id', 'name': 'Hike'},
      ]),
    );
  });

  test(
    'saveFavoriteTrail, isFavoriteTrail, and streamFavoriteTrails use the favorite trails collection',
    () async {
      final mockFavoriteDoc = MockDocumentReference();
      final mockFavoriteSnapshot = MockDocumentSnapshot();
      final mockFavoriteQuerySnapshot = MockQuerySnapshot();
      final mockFavoriteQueryDoc = MockQueryDocumentSnapshot();

      when(
        () => mockFavoriteTrailsCollection.doc('trail-1'),
      ).thenReturn(mockFavoriteDoc);
      when(() => mockFavoriteDoc.set(any(), any())).thenAnswer((_) async {});
      when(
        () => mockFavoriteDoc.get(),
      ).thenAnswer((_) async => mockFavoriteSnapshot);
      when(() => mockFavoriteSnapshot.exists).thenReturn(true);

      when(
        () => mockFavoriteTrailsCollection.snapshots(),
      ).thenAnswer((_) => Stream.value(mockFavoriteQuerySnapshot));
      when(
        () => mockFavoriteQuerySnapshot.docs,
      ).thenReturn([mockFavoriteQueryDoc]);
      when(() => mockFavoriteQueryDoc.id).thenReturn('trail-1');
      when(() => mockFavoriteQueryDoc.data()).thenReturn({'name': 'Trail One'});

      await databaseService.saveFavoriteTrail('trail-1', {'name': 'Trail One'});

      expect(await databaseService.isFavoriteTrail('trail-1'), isTrue);
      await expectLater(
        databaseService.streamFavoriteTrails(),
        emits([
          {'id': 'trail-1', 'name': 'Trail One'},
        ]),
      );

      verify(() => mockFavoriteDoc.set({'name': 'Trail One'}, any())).called(1);
      verify(() => mockFavoriteDoc.get()).called(1);
      verify(() => mockFavoriteTrailsCollection.snapshots()).called(1);
    },
  );

  test('fetchActivity returns activity data when document exists', () async {
    final mockActivityDoc = MockDocumentReference();
    final mockSnapshot = MockDocumentSnapshot();

    when(
      () => mockActivitiesCollection.doc('act-1'),
    ).thenReturn(mockActivityDoc);

    when(
      () => mockActivityDoc.get(any()),
    ).thenAnswer((_) async => mockSnapshot);

    when(() => mockSnapshot.exists).thenReturn(true);
    when(
      () => mockSnapshot.data(),
    ).thenReturn({'name': 'Morning hike', 'xp': 100});

    final result = await databaseService.fetchActivity('act-1');

    expect(result, {'name': 'Morning hike', 'xp': 100});

    verify(() => mockActivityDoc.get(any())).called(1);
  });

  test('fetchActivity returns null when document does not exist', () async {
    final mockActivityDoc = MockDocumentReference();
    final mockSnapshot = MockDocumentSnapshot();

    when(
      () => mockActivitiesCollection.doc('act-1'),
    ).thenReturn(mockActivityDoc);

    when(
      () => mockActivityDoc.get(any()),
    ).thenAnswer((_) async => mockSnapshot);

    when(() => mockSnapshot.exists).thenReturn(false);

    final result = await databaseService.fetchActivity('act-1');

    expect(result, isNull);
  });

  test('fetchActivity returns null when snapshot data is null', () async {
    final mockActivityDoc = MockDocumentReference();
    final mockSnapshot = MockDocumentSnapshot();

    when(
      () => mockActivitiesCollection.doc('act-1'),
    ).thenReturn(mockActivityDoc);

    when(
      () => mockActivityDoc.get(any()),
    ).thenAnswer((_) async => mockSnapshot);

    when(() => mockSnapshot.exists).thenReturn(true);
    when(() => mockSnapshot.data()).thenReturn(null);

    final result = await databaseService.fetchActivity('act-1');

    expect(result, isNull);
  });

  test('addNoteToArray writes arrayUnion to Firestore', () async {
    final mockActivityDoc = MockDocumentReference();

    when(
      () => mockActivitiesCollection.doc('act-1'),
    ).thenReturn(mockActivityDoc);

    when(() => mockActivityDoc.set(any(), any())).thenAnswer((_) async {});

    final note = {'id': 'note-1', 'text': 'Hello'};

    await databaseService.addNoteToArray('act-1', note);

    final captured =
        verify(() => mockActivityDoc.set(captureAny(), any())).captured.first
            as Map<String, dynamic>;

    expect(captured.containsKey('notes'), isTrue);
    expect(captured['notes'], isA<FieldValue>());
  });

  test('addNoteToArray rethrows Firestore exceptions', () async {
    final mockActivityDoc = MockDocumentReference();

    when(
      () => mockActivitiesCollection.doc('act-1'),
    ).thenReturn(mockActivityDoc);

    when(
      () => mockActivityDoc.set(any(), any()),
    ).thenThrow(FirebaseException(plugin: 'firestore'));

    expect(
      () => databaseService.addNoteToArray('act-1', {'id': 'note-1'}),
      throwsA(isA<FirebaseException>()),
    );
  });

  test('removeNoteFromArray writes arrayRemove to Firestore', () async {
    final mockActivityDoc = MockDocumentReference();

    when(
      () => mockActivitiesCollection.doc('act-1'),
    ).thenReturn(mockActivityDoc);

    when(() => mockActivityDoc.set(any(), any())).thenAnswer((_) async {});

    final note = {'id': 'note-1', 'text': 'Hello'};

    await databaseService.removeNoteFromArray('act-1', note);

    final captured =
        verify(() => mockActivityDoc.set(captureAny(), any())).captured.first
            as Map<String, dynamic>;

    expect(captured.containsKey('notes'), isTrue);
    expect(captured['notes'], isA<FieldValue>());
  });

  test('deleteFavoriteTrail deletes the favorite trail document', () async {
    final mockFavoriteDoc = MockDocumentReference();

    when(
      () => mockFavoriteTrailsCollection.doc('trail-1'),
    ).thenReturn(mockFavoriteDoc);

    when(() => mockFavoriteDoc.delete()).thenAnswer((_) async {});

    await databaseService.deleteFavoriteTrail('trail-1');

    verify(() => mockFavoriteDoc.delete()).called(1);
  });
}
