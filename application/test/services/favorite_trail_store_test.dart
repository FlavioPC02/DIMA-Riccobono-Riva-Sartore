import 'dart:async';

import 'package:application/core/models/favorite_trail.dart';
import 'package:application/services/favorite_trail_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';

void main() {
  test('maps remote favorite trails in the order they are returned', () async {
    final mockDb = MockDatabaseService();
    final controller = StreamController<List<Map<String, dynamic>>>();
    addTearDown(controller.close);

    when(
      () => mockDb.streamFavoriteTrails(),
    ).thenAnswer((_) => controller.stream);

    final store = FavoriteTrailStore(
      hasCurrentUser: () => true,
      databaseServiceFactory: () => mockDb,
    );

    controller.add([
      {'id': 'beta', 'name': 'Trail Beta'},
      {'id': 'alpha', 'name': 'Trail Alpha'},
    ]);

    final favorites = await store.fetchFavoriteTrails();

    expect(favorites.map((trail) => trail.name), ['Trail Beta', 'Trail Alpha']);
  });

  test('reports favorite state and deletes a trail by id', () async {
    final mockDb = MockDatabaseService();
    final favoriteTrails = <Map<String, dynamic>>[];

    when(
      () => mockDb.streamFavoriteTrails(),
    ).thenAnswer((_) => Stream<List<Map<String, dynamic>>>.value(
      List<Map<String, dynamic>>.from(favoriteTrails),
    ));
    when(() => mockDb.saveFavoriteTrail(any(), any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      final data = Map<String, dynamic>.from(
        invocation.positionalArguments[1] as Map,
      );

      favoriteTrails.removeWhere((trail) => trail['id'] == id);
      favoriteTrails.add({'id': id, ...data});
    });
    when(() => mockDb.isFavoriteTrail(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      return favoriteTrails.any((trail) => trail['id'] == id);
    });
    when(() => mockDb.deleteFavoriteTrail(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      favoriteTrails.removeWhere((trail) => trail['id'] == id);
    });

    final store = FavoriteTrailStore(
      hasCurrentUser: () => true,
      databaseServiceFactory: () => mockDb,
    );

    final trail = FavoriteTrail.fromTrail({'id': 'trail-1', 'name': 'Trail'});

    await store.saveTrail(trail);
    expect(await store.isFavorite('trail-1'), isTrue);

    await store.deleteTrail('trail-1');

    expect(await store.isFavorite('trail-1'), isFalse);
    expect(await store.fetchFavoriteTrails(), isEmpty);
  });

  test('emits updates when favorite trails change', () async {
    final mockDb = MockDatabaseService();
    final controller = StreamController<List<Map<String, dynamic>>>();
    final favoriteTrails = <Map<String, dynamic>>[];
    addTearDown(controller.close);

    when(
      () => mockDb.streamFavoriteTrails(),
    ).thenAnswer((_) => controller.stream);
    when(() => mockDb.saveFavoriteTrail(any(), any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      final data = Map<String, dynamic>.from(
        invocation.positionalArguments[1] as Map,
      );

      favoriteTrails.removeWhere((trail) => trail['id'] == id);
      favoriteTrails.add({'id': id, ...data});
      controller.add(List<Map<String, dynamic>>.from(favoriteTrails));
    });

    final store = FavoriteTrailStore(
      hasCurrentUser: () => true,
      databaseServiceFactory: () => mockDb,
    );

    final emissions = <List<FavoriteTrail>>[];
    final subscription = store.streamFavoriteTrails().listen(emissions.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    controller.add(const []);
    await Future<void>.delayed(Duration.zero);
    await store.saveTrail(
      FavoriteTrail.fromTrail({'id': 'trail-1', 'name': 'Trail'}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(emissions.first, isEmpty);
    expect(emissions.last.single.id, 'trail-1');
  });
}
