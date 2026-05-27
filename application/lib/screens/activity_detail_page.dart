import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/extensions/duration_formatting.dart';
import 'package:application/core/models/weather_data.dart';
import 'package:application/services/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
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
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete activity',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete activity'),
                        content: const Text(
                          'Are you sure you want to delete this activity?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await context.read<ActivityCubit>().deleteActivity(
                        activity.id,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _ActivityHeader(activity: activity),
              ),
              bottom: const TabBar(
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _HeaderStat(
                  icon: Icons.schedule,
                  label: 'Duration',
                  value: activity.durationMinutes.toMinuteDurationLabel(),
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
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatefulWidget {
  final Activity activity;
  const _OverviewTab({required this.activity});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late final Future<WeatherData>? _weatherFuture;

  @override
  void initState() {
    super.initState();
    final isPlanned = widget.activity.status == ActivityStatus.planned;
    final daysUntil = widget.activity.date.difference(DateTime.now()).inDays;
    _weatherFuture = isPlanned && daysUntil <= 13 && daysUntil >= 0
        ? WeatherService().fetchWeather(widget.activity.date)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.activity.trailName.isNotEmpty) ...[
          Text(
            widget.activity.trailName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
        ],
        if (_weatherFuture != null)
          FutureBuilder<WeatherData>(
            future: _weatherFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _WeatherCardLoading();
              }
              if (snap.hasError) {
                return _WeatherCardError(message: snap.error.toString());
              }
              return _WeatherCard(
                weather: snap.data!,
                date: widget.activity.date,
              );
            },
          )
        else if (widget.activity.status == ActivityStatus.planned)
          const _WeatherCardError(
            message: 'Forecast available only within 14 days of the hike.',
          ),
      ],
    );
  }
}

// ─── WEATHER CARD ──────────────────────────────────────────────────────

// Maps OWM weather codes to local Lottie asset paths in assets/lottie/
String _lottieAsset(int code) {
  if (code == 800) return 'assets/lottie/clear.json';
  if (code == 801) return 'assets/lottie/few_clouds.json';
  if (code >= 802) return 'assets/lottie/cloudy.json';
  if (code >= 700) return 'assets/lottie/fog.json';
  if (code >= 600) return 'assets/lottie/snow.json';
  if (code >= 500) return 'assets/lottie/rain.json';
  if (code >= 300) return 'assets/lottie/drizzle.json';
  return 'assets/lottie/thunderstorm.json';
}

// App weather icon buckets:
// 2xx Thunderstorm, 3xx Drizzle, 5xx Rain, 6xx Snow,
// 7xx Atmosphere, 800 Clear, 80x Clouds
List<Color> _gradientFor(int code) {
  if (code == 800) return const [Color(0xFF29B6F6), Color(0xFF0277BD)];
  if (code == 801) return const [Color(0xFF64B5F6), Color(0xFF1565C0)];
  if (code == 802) return const [Color(0xFF64B5F6), Color(0xFF546E7A)];
  if (code >= 803) return const [Color(0xFF90A4AE), Color(0xFF546E7A)];
  if (code >= 700) return const [Color(0xFF90A4AE), Color(0xFF607D8B)];
  if (code >= 600) return const [Color(0xFF80DEEA), Color(0xFF0277BD)];
  if (code >= 500) return const [Color(0xFF1E88E5), Color(0xFF0D47A1)];
  if (code >= 300) return const [Color(0xFF42A5F5), Color(0xFF1565C0)];
  return const [Color(0xFF546E7A), Color(0xFF263238)]; // 2xx thunderstorm
}

class _WeatherCard extends StatelessWidget {
  final WeatherData weather;
  final DateTime date;

  const _WeatherCard({required this.weather, required this.date});

  @override
  Widget build(BuildContext context) {
    final gradientColors = _gradientFor(weather.weatherCode);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _WeatherStat(
                icon: const Text('💧', style: TextStyle(fontSize: 28)),
                value: '${weather.precipitationProbability}%',
                label: 'Precipitation',
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _WeatherStat(
                icon: Lottie.asset(
                  'assets/lottie/wind.json',
                  width: 36,
                  height: 36,
                ),
                value: '${weather.windSpeed.round()} km/h',
                label: 'Wind',
              ),
            ],
          ),
          if (weather.hourly.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: weather.hourly.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (_, i) => _HourlySlot(entry: weather.hourly[i]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 12, color: Colors.white54),
              SizedBox(width: 4),
              Text(
                'Based on your current location',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final Widget icon;
  final String value;
  final String label;

  const _WeatherStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _HourlySlot extends StatelessWidget {
  final WeatherHourEntry entry;
  const _HourlySlot({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hour = entry.time.hour.toString().padLeft(2, '0');
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            '$hour:00',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Lottie.asset(_lottieAsset(entry.weatherCode), width: 32, height: 32),
          Text(
            '${entry.temp.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            entry.precipitationProbability > 0
                ? '💧${entry.precipitationProbability}%'
                : '',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _WeatherCardLoading extends StatelessWidget {
  const _WeatherCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _WeatherCardError extends StatelessWidget {
  final String message;
  const _WeatherCardError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
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
        _StatRow(label: 'Duration', value: activity.durationMinutes.toMinuteDurationLabel()),
        _StatRow(label: 'XP Earned', value: '${activity.xpEarned}'),
        _StatRow(label: 'Elevation Gain', value: '${activity.trackedElevationGap} m'),
        _StatRow(label: 'Tracked Distance', value: '${activity.trackedDistance} km'),
        _StatRow(label: 'Tracked Time', value: activity.trackedTime.toCompactLabel()),
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
          child: Text('No notes yet.', style: TextStyle(color: Colors.grey)),
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
