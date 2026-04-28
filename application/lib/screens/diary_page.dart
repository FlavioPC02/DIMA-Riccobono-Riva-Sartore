import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.book, size: 30),
              SizedBox(width: 12),
              Text(
                'Diary',
                style: TextStyle(fontSize: 28, color: AppColors.textPrimary),
              ),
            ],
          ),
          bottom: TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textPrimary,
            indicatorColor: AppColors.secondary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Completed'),
              Tab(text: 'Planned'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CompletedTab(),
            _PlannedTab(),
          ],
        ),
      ),
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context) {
    // TODO: replace with real data from DB
    final List<Map<String, String>> activities = [];

    if (activities.isEmpty) {
      return const _EmptyState(
        icon: Icons.terrain,
        message: 'No completed hikes yet.\nStart exploring!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _ActivityCard(activity: activities[index]);
      },
    );
  }
}

class _PlannedTab extends StatelessWidget {
  const _PlannedTab();

  @override
  Widget build(BuildContext context) {
    // TODO: replace with real data from DB
    final List<Map<String, String>> activities = [];

    if (activities.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_note,
        message: 'No planned hikes yet.\nSchedule your next adventure!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _ActivityCard(activity: activities[index]);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, String> activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: const Icon(Icons.hiking),
        title: Text(activity['name'] ?? ''),
        subtitle: Text(activity['date'] ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: navigate to activity detail
        },
      ),
    );
  }
}
