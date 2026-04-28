import 'package:flutter/material.dart';
import '../core/models/activity.dart';
import '../core/theme/app_colors.dart';

class ActivityDetailPage extends StatelessWidget {
  final Activity activity;

  const ActivityDetailPage({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 260,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: _ActivityHeader(activity: activity),
              ),
              bottom: const TabBar(
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: Colors.white70,
                indicatorColor: AppColors.secondary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Notes'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(activity: activity),
              _StatsTab(activity: activity),
              _NotesTab(activity: activity),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final Activity activity;

  const _ActivityHeader({required this.activity});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _DifficultyChip(difficulty: activity.difficulty),
            const SizedBox(height: 12),
            Text(
              activity.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _HeaderStat(
                  icon: Icons.schedule,
                  label: 'Duration',
                  value: _formatDuration(activity.durationMinutes),
                ),
                const SizedBox(width: 32),
                _HeaderStat(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${activity.distanceKm.toStringAsFixed(1)} km',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _DifficultyChip extends StatelessWidget {
  final ActivityDifficulty difficulty;
  const _DifficultyChip({required this.difficulty});

  static const _labels = {
    ActivityDifficulty.easy: 'Easy',
    ActivityDifficulty.moderate: 'Moderate',
    ActivityDifficulty.hard: 'Hard',
  };

  static const _colors = {
    ActivityDifficulty.easy: Color(0xFF4CAF50),
    ActivityDifficulty.moderate: Color(0xFFFFA726),
    ActivityDifficulty.hard: Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _colors[difficulty],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _labels[difficulty]!,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Activity activity;
  const _OverviewTab({required this.activity});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          activity.trailName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Status: ${activity.status.name}',
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        const Text(
          'Add a description, points of interest or other details for this hike here.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Activity activity;
  const _StatsTab({required this.activity});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DifficultyRow(difficulty: activity.difficulty),
        _StatRow(label: 'Distance', value: '${activity.distanceKm} km'),
        _StatRow(label: 'Duration', value: '${activity.durationMinutes} min'),
        _StatRow(label: 'XP Earned', value: '${activity.xpEarned}'),
      ],
    );
  }
}

class _NotesTab extends StatelessWidget {
  final Activity activity;
  const _NotesTab({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No notes yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [Text(activity.notes)],
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final ActivityDifficulty difficulty;
  const _DifficultyRow({required this.difficulty});

  static const _filledCount = {
    ActivityDifficulty.easy: 1,
    ActivityDifficulty.moderate: 2,
    ActivityDifficulty.hard: 3,
  };

  static const _color = Color(0xFFFFA726);

  @override
  Widget build(BuildContext context) {
    final filled = _filledCount[difficulty]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Difficulty', style: TextStyle(fontSize: 16)),
          Row(
            children: List.generate(
              3,
              (i) => Icon(
                Icons.terrain,
                size: 26,
                color: i < filled ? _color : Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
