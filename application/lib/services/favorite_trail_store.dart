import 'package:application/core/models/favorite_trail.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteTrailStore {
  final bool Function()? hasCurrentUser;
  final DatabaseService Function()? databaseServiceFactory;

  FavoriteTrailStore({
    this.hasCurrentUser,
    this.databaseServiceFactory,
  });

  DatabaseService? _remoteOrNull() {
    final hasUser = hasCurrentUser != null
        ? hasCurrentUser!()
        : FirebaseAuth.instance.currentUser != null;

    if (!hasUser) return null;

    return databaseServiceFactory != null
        ? databaseServiceFactory!()
        : DatabaseService();
  }

  Stream<List<FavoriteTrail>> streamFavoriteTrails() {
    final remote = _remoteOrNull();
    if (remote == null) return Stream.value([]);

    return remote.streamFavoriteTrails().map(
      (list) => list
          .map((data) => FavoriteTrail.fromJson(data['id'] as String, data))
          .toList(),
    );
  }

  Future<List<FavoriteTrail>> fetchFavoriteTrails() async {
    return streamFavoriteTrails().first;
  }

  Future<bool> isFavorite(String trailId) async {
    if (trailId.isEmpty) return false;

    final remote = _remoteOrNull();
    if (remote == null) return false;

    return remote.isFavoriteTrail(trailId);
  }

  Future<void> saveTrail(FavoriteTrail trail) async {
    if (trail.id.isEmpty) return;

    final remote = _remoteOrNull();
    if (remote == null) return;

    await remote.saveFavoriteTrail(trail.id, trail.toJson());
  }

  Future<void> deleteTrail(String trailId) async {
    if (trailId.isEmpty) return;

    final remote = _remoteOrNull();
    if (remote == null) return;

    await remote.deleteFavoriteTrail(trailId);
  }
}