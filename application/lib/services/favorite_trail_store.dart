import 'package:application/core/models/favorite_trail.dart';
import 'package:hive_ce_flutter/adapters.dart';

class FavoriteTrailStore {
  static const _boxName = 'favorite_trails';

  Box<Map>? _box;

  Future<Box<Map>> get _favoriteBox async {
    final existing = _box;
    if (existing != null) return existing;

    _box = await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  Stream<List<FavoriteTrail>> streamFavoriteTrails() async* {
    final box = await _favoriteBox;
    yield _readFavoriteTrails(box);
    yield* box.watch().asyncMap((_) => fetchFavoriteTrails());
  }

  Future<List<FavoriteTrail>> fetchFavoriteTrails() async {
    final box = await _favoriteBox;
    return _readFavoriteTrails(box);
  }

  Future<bool> isFavorite(String trailId) async {
    if (trailId.isEmpty) return false;

    final box = await _favoriteBox;
    return box.containsKey(trailId);
  }

  Future<void> saveTrail(FavoriteTrail trail) async {
    if (trail.id.isEmpty) return;

    final box = await _favoriteBox;
    await box.put(trail.id, _trailToEntry(trail));
  }

  Future<void> deleteTrail(String trailId) async {
    if (trailId.isEmpty) return;

    final box = await _favoriteBox;
    await box.delete(trailId);
  }

  List<FavoriteTrail> _readFavoriteTrails(Box<Map> box) {
    final trails = box.values
        .map((entry) => _trailFromEntry(_normalizeEntry(entry)))
        .toList(growable: false);
    trails.sort((a, b) => a.name.compareTo(b.name));
    return trails;
  }

  Map<String, Object?> _trailToEntry(FavoriteTrail trail) {
    return {
      'id': trail.id,
      'name': trail.name,
      'distance': trail.distance,
      'duration': trail.duration,
      'difficulty': trail.difficulty,
      'ascent': trail.ascent,
      'isFerrata': trail.isFerrata,
    };
  }

  FavoriteTrail _trailFromEntry(Map<String, Object?> entry) {
    return FavoriteTrail(
      id: entry['id']?.toString() ?? '',
      name: entry['name']?.toString() ?? 'Trail',
      distance: entry['distance']?.toString(),
      duration: entry['duration']?.toString(),
      difficulty: entry['difficulty'] as int?,
      ascent: entry['ascent']?.toString(),
      isFerrata: entry['isFerrata'] as bool?,
    );
  }

  Map<String, Object?> _normalizeEntry(Map entry) {
    return entry.map((key, value) => MapEntry(key.toString(), value));
  }

}
