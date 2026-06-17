import 'dart:io';

import 'package:application/core/models/favorite_trail.dart';
import 'package:application/services/favorite_trail_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:latlong2/latlong.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('favorite_trails_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('persists only trail data and restores it as a trail map', () async {
    final store = FavoriteTrailStore();
    final trail = FavoriteTrail.fromTrail({
      'id': 12345,
      'name': 'Sentiero Test',
      'subTrails': const [
        [LatLng(45.1, 9.1), LatLng(45.2, 9.2)],
      ],
    });

    await store.saveTrail(trail);

    final restoredStore = FavoriteTrailStore();
    final favorites = await restoredStore.fetchFavoriteTrails();
    final restoredTrail = favorites.single.toTrailMap();

    expect(favorites.single.id, '12345');
    expect(favorites.single.name, 'Sentiero Test');
    expect(restoredTrail['id'], '12345');
    expect(restoredTrail['name'], 'Sentiero Test');
    expect(restoredTrail['subTrails'].single.first, isA<LatLng>());
  });

  test('reports favorite state and deletes a trail by id', () async {
    final store = FavoriteTrailStore();
    final trail = FavoriteTrail.fromTrail({
      'id': 'trail-1',
      'name': 'Trail',
      'subTrails': const [
        [LatLng(45.1, 9.1)],
      ],
    });

    await store.saveTrail(trail);
    expect(await store.isFavorite('trail-1'), isTrue);

    await store.deleteTrail('trail-1');

    expect(await store.isFavorite('trail-1'), isFalse);
    expect(await store.fetchFavoriteTrails(), isEmpty);
  });
}
