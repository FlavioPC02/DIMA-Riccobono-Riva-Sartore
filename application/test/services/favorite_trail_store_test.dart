import 'package:application/core/models/favorite_trail.dart';
import 'package:application/services/favorite_trail_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps favorite trails in memory and returns them sorted by name', () async {
    final store = FavoriteTrailStore();

    await store.saveTrail(
      FavoriteTrail.fromTrail({
        'id': 'beta',
        'name': 'Trail Beta',
      }),
    );
    await store.saveTrail(
      FavoriteTrail.fromTrail({
        'id': 'alpha',
        'name': 'Trail Alpha',
      }),
    );

    final favorites = await store.fetchFavoriteTrails();

    expect(favorites.map((trail) => trail.name), ['Trail Alpha', 'Trail Beta']);
  });

  test('reports favorite state and deletes a trail by id', () async {
    final store = FavoriteTrailStore();
    final trail = FavoriteTrail.fromTrail({
      'id': 'trail-1',
      'name': 'Trail',
    });

    await store.saveTrail(trail);
    expect(await store.isFavorite('trail-1'), isTrue);

    await store.deleteTrail('trail-1');

    expect(await store.isFavorite('trail-1'), isFalse);
    expect(await store.fetchFavoriteTrails(), isEmpty);
  });

  test('emits updates when favorite trails change', () async {
    final store = FavoriteTrailStore();
    final emissions = <List<FavoriteTrail>>[];
    final subscription = store.streamFavoriteTrails().listen(emissions.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await store.saveTrail(
      FavoriteTrail.fromTrail({
        'id': 'trail-1',
        'name': 'Trail',
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(emissions.first, isEmpty);
    expect(emissions.last.single.id, 'trail-1');
  });
}
