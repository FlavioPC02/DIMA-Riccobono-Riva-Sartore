import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/screens/activity_detail_page.dart';
import 'package:application/screens/add_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlannedTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 30),
            SizedBox(width: 12),
            Text(
              'Diary',
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Completed'),
            Tab(text: 'Planned'),
          ],
        ),
      ),
      floatingActionButton: isPlannedTab
          ? FloatingActionButton(
              heroTag: 'add_planned_activity',
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.textPrimary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ActivityCubit>(),
                    //child: const AddActivityPage(),
                  ),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: BlocBuilder<ActivityCubit, List<Activity>>(
        builder: (context, activities) {
          final completed = activities
              .where((a) => a.status == ActivityStatus.completed)
              .toList();
          final planned = activities
              .where((a) => a.status == ActivityStatus.planned)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _ActivityList(
                activities: completed,
                emptyIcon: Icons.terrain,
                emptyMessage: 'No completed hikes yet.\nStart exploring!',
              ),
              _ActivityList(
                activities: planned,
                emptyIcon: Icons.event_note,
                emptyMessage:
                    'No planned hikes yet.\nSchedule your next adventure!',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<Activity> activities;
  final IconData emptyIcon;
  final String emptyMessage;

  const _ActivityList({
    required this.activities,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return _EmptyState(icon: emptyIcon, message: emptyMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _ActivityCard(activity: activities[index]),
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
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hiking),
        title: Text(activity.name),
        subtitle: Text(
          DateFormat('dd/MM/yyyy').format(activity.date)
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityDetailPage(activity: activity),
            ),
          );
        },
      ),
    );
  }
}
