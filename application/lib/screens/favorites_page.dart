import 'package:application/core/cubit/activity_cubit.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:application/core/models/activity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

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
      body: BlocBuilder<ActivityCubit, List<Activity>>(
        builder: (context, activities) {
          final favorites = activities.where((a) => a.isFavorite).toList();

          if (favorites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'No favorite hikes yet.\nStart exploring and add some to your favorites!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _FavoritesCard(favorites: favorites[index]),
          );
        },
      ),
    );
  }
}

class _FavoritesCard extends StatelessWidget {
  final Activity favorites;

  const _FavoritesCard({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: Text(favorites.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to trail details page
        },
      ),
    );
  }
}
