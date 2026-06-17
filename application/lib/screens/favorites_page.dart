import 'package:application/core/models/favorite_trail.dart';
import 'package:application/screens/trail_details_screen.dart';
import 'package:application/services/favorite_trail_store.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoriteTrailStore _favoriteTrailStore = FavoriteTrailStore();
  late final Stream<List<FavoriteTrail>> _favoriteTrailsStream;

  @override
  void initState() {
    super.initState();
    _favoriteTrailsStream = _favoriteTrailStore.streamFavoriteTrails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 30),
            SizedBox(width: 12),
            Text('Favorites'),
          ],
        ),
      ),
      body: StreamBuilder<List<FavoriteTrail>>(
        stream: _favoriteTrailsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final favorites = snapshot.data ?? const <FavoriteTrail>[];
          if (favorites.isEmpty) return const _EmptyFavorites();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _FavoriteTrailCard(favoriteTrail: favorites[index]),
          );
        },
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No favorite trails yet.\nStart exploring and add some to your favorites!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTrailCard extends StatelessWidget {
  final FavoriteTrail favoriteTrail;

  const _FavoriteTrailCard({required this.favoriteTrail});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: Text(favoriteTrail.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TrailDetailsScreen(trail: favoriteTrail.toTrailMap()),
            ),
          );
        },
      ),
    );
  }
}
