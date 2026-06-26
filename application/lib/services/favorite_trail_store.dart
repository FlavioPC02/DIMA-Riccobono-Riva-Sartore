import 'dart:async';

import 'package:application/core/models/favorite_trail.dart';

class FavoriteTrailStore {
  static final Map<String, FavoriteTrail> _favorites = {};
  static final StreamController<List<FavoriteTrail>> _updates =
      StreamController<List<FavoriteTrail>>.broadcast();

  Stream<List<FavoriteTrail>> streamFavoriteTrails() async* {
    yield _readFavoriteTrails();
    yield* _updates.stream;
  }

  Future<List<FavoriteTrail>> fetchFavoriteTrails() async {
    return _readFavoriteTrails();
  }

  Future<bool> isFavorite(String trailId) async {
    if (trailId.isEmpty) return false;

    return _favorites.containsKey(trailId);
  }

  Future<void> saveTrail(FavoriteTrail trail) async {
    if (trail.id.isEmpty) return;

    _favorites[trail.id] = trail;
    _emit();
  }

  Future<void> deleteTrail(String trailId) async {
    if (trailId.isEmpty) return;

    _favorites.remove(trailId);
    _emit();
  }

  static Future<void> clear() async {
    _favorites.clear();
    _emit();
  }

  static Future<void> clearForTesting() => clear();

  static void _emit() {
    if (!_updates.isClosed) {
      _updates.add(_readFavoriteTrails());
    }
  }

  static List<FavoriteTrail> _readFavoriteTrails() {
    final trails = _favorites.values.toList(growable: false);
    trails.sort((a, b) => a.name.compareTo(b.name));
    return trails;
  }
}
