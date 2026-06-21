import 'dart:convert';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/widgets/note_dialog.dart';
import 'package:application/widgets/note_image_gallery.dart';
import 'package:hike_core/hike_core.dart';
import 'package:application/core/models/weather_data.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../core/models/activity.dart';

class ActivityDetailPage extends StatefulWidget {
  final Activity initialActivity;

  const ActivityDetailPage({super.key, required Activity activity})
    : initialActivity = activity;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  final String _appName = 'FlutterHikingApp/1.0';

  @override
  void initState() {
    super.initState();
    context.read<ActivityCubit>().loadActivityDetails(
      widget.initialActivity.id,
    );
  }

  Future<List<List<TrailPoint>>> _fetchTrailPath(
    Activity currentActivity,
  ) async {
    final query =
        """
      [out:json][timeout:15];
      relation(${currentActivity.trailId});
      way(r);
      out tags geom;
    """;

    final overpassServers = [
      Uri.parse('https://overpass-api.de/api/interpreter'),
      Uri.parse('https://overpass.private.coffee/api/interpreter'),
      Uri.parse('https://overpass.kumi.systems/api/interpreter'),
    ];

    for (final overpassUrl in overpassServers) {
      try {
        final response = await http
            .post(overpassUrl, body: query, headers: {'User-Agent': _appName})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          continue;
        }

        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        final segments = <List<TrailPoint>>[];

        for (final el in elements) {
          if (el['type'] != 'way' || el['geometry'] == null) {
            continue;
          }

          final geometry = el['geometry'] as List<dynamic>;

          final points = geometry
              .map<TrailPoint>(
                (geo) => TrailPoint(
                  lat: (geo['lat'] as num).toDouble(),
                  lng: (geo['lon'] as num).toDouble(),
                ),
              )
              .toList();

          if (points.isNotEmpty) {
            segments.add(points);
          }
        }
        return segments;
      } catch (e) {
        return [[]];
      }
    }
    return [[]];
  }

  Future<Activity> _loadActivity(Activity activity) async {
    if(!activity.hasTrailPath) {
      final newActivity = activity.copyWith(
        trailPath: await _fetchTrailPath(activity),
      );

      if(!mounted) return newActivity;

      context.read<ActivityCubit>().updateActivity(newActivity);
      return newActivity;
    }

    return activity;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: BlocBuilder<ActivityCubit, List<Activity>>(
        builder: (context, state) {
          final activity = state.firstWhere(
            (a) => a.id == widget.initialActivity.id,
            orElse: () {
              return widget.initialActivity;
            },
          );

          return FutureBuilder<Activity>(
            future: _loadActivity(activity),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final currentActivity = snapshot.data!;

              return Scaffold(
                floatingActionButton: Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tabController,
                      builder: (context, _) {
                        if (tabController.index == 1) {
                          return FloatingActionButton(
                            onPressed: () async {
                              final result =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (context) => const NoteDialog(),
                                  );

                              if (result != null && context.mounted) {
                                final newNote = ActivityNote(
                                  id: '',
                                  text: result['text'] ?? '',
                                  imageUrls: List<String>.from(
                                    result['imageUrls'] ?? [],
                                  ),
                                  createdAt: DateTime.now(),
                                );

                                context.read<ActivityCubit>().addOrUpdateNote(
                                  currentActivity,
                                  newNote,
                                );
                              }
                            },
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondary,
                            child: const Icon(Icons.add),
                          );
                        }
                        if (currentActivity.status == ActivityStatus.planned) {
                          return FloatingActionButton.extended(
                            key: const ValueKey('start_button'),
                            onPressed: currentActivity.hasTrailPath
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NavigatorScreen(
                                          trail: currentActivity.navigatorTrail,
                                          activity: currentActivity,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondary,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Start'),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverAppBar(
                      pinned: true,
                      elevation: 0,
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondary,
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
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondary,
                                      ),
                                    ),
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
                              await context
                                  .read<ActivityCubit>()
                                  .deleteActivity(currentActivity.id);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: Theme.of(context).colorScheme.secondary,
                        child: _ActivityHeader(activity: currentActivity),
                      ),
                    ),
                    SliverAppBar(
                      pinned: true,
                      primary: false,
                      toolbarHeight: 0,
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      bottom: const TabBar(
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: 'Overview'),
                          Tab(text: 'Notes'),
                        ],
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      _OverviewTab(activity: currentActivity),
                      _NotesTab(activity: currentActivity),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final Activity activity;

  const _ActivityHeader({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DifficultyChip(difficulty: activity.difficulty),
          const SizedBox(height: 12),
          Text(
            activity.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderStat(
                icon: Icons.route,
                label: 'Distance',
                value: '${activity.distanceKm.toStringAsFixed(1)} km',
              ),
              const SizedBox(width: 32),
              _HeaderStat(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: activity.durationMinutes.toMinuteDurationLabel(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final ActivityDifficulty difficulty;
  const _DifficultyChip({required this.difficulty});

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
        difficulty.label,
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

    double? lat;
    double? lon;
    if (widget.activity.trailPath.isNotEmpty &&
        widget.activity.trailPath.first.isNotEmpty) {
      final startPoint = widget.activity.trailPath.first.first;
      lat = startPoint.lat;
      lon = startPoint.lng;
    }

    _weatherFuture = isPlanned && daysUntil <= 13 && daysUntil >= 0
        ? WeatherService().fetchWeather(widget.activity.date, lat, lon)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        if (_weatherFuture != null)
          FutureBuilder<WeatherData>(
            future: _weatherFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _WeatherCardLoading();
              }
              if (snap.hasError) {
                return _WeatherCardError(
                  message:
                      'Error while fetching weather data. Check your connnection.',
                );
              }
              return _WeatherCard(
                weather: snap.data!,
                date: widget.activity.date,
              );
            },
          )
        else if (widget.activity.status == ActivityStatus.planned &&
            !widget.activity.date.difference(DateTime.now()).isNegative)
          const _WeatherCardError(
            message: 'Forecast available only within 14 days of the hike.',
          ),
        Padding(padding: EdgeInsets.only(top: 10)),
        _StatRow(label: 'Trail Name', value: widget.activity.trailName),
        _DifficultyRow(difficulty: widget.activity.difficulty),
        if (widget.activity.status == ActivityStatus.planned)
          _StatRow(
            label: 'Planned on',
            value: DateFormat('d MMMM yyyy').format(widget.activity.date),
          ),
        if (widget.activity.status == ActivityStatus.completed) ...[
          _StatRow(
            label: 'Completed on',
            value: DateFormat('d MMMM yyyy').format(widget.activity.date),
          ),
          _StatRow(label: 'XP Earned', value: '${widget.activity.xpEarned}'),
          _StatRow(
            label: 'Elevation Gain',
            value: '${widget.activity.trackedElevationGap} m',
          ),
          _StatRow(
            label: 'Tracked Distance',
            value: '${widget.activity.trackedDistance} km',
          ),
          _StatRow(
            label: 'Tracked Time',
            value: widget.activity.trackedTime.toCompactLabel(),
          ),
        ],
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
              height: MediaQuery.textScalerOf(context).scale(150),
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
                'Based on trail location',
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$hour:00',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            child: Lottie.asset(
              _lottieAsset(entry.weatherCode),
              fit: BoxFit.contain,
            ),
          ),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${entry.temp.round()}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (entry.precipitationProbability > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '💧${entry.precipitationProbability}%',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
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
        color: Theme.of(context).colorScheme.tertiary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.errorText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.errorText),
            ),
          ),
        ],
      ),
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
            'No notes yet. Tap + to add one!',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final sortedNotes = List<ActivityNote>.from(activity.notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: sortedNotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final note = sortedNotes[index];
        final dateStr = DateFormat('d MMM yyyy - HH:mm').format(note.createdAt);
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => NoteDialog(existingNote: note),
              );

              if (result != null && context.mounted) {
                final updatedNote = ActivityNote(
                  id: note.id,
                  text: result['text'] ?? '',
                  imageUrls: List<String>.from(result['imageUrls'] ?? []),
                  createdAt: note.createdAt,
                );

                context.read<ActivityCubit>().addOrUpdateNote(
                  activity,
                  updatedNote,
                );
              }
            },
            onLongPress: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete note'),
                  content: const Text(
                    'Are you sure you want to delete this note?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
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
                context.read<ActivityCubit>().deleteNote(activity, note.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (note.text.isNotEmpty) ...[
                    Text(note.text, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 12),
                  ],
                  if (note.imageUrls.isNotEmpty)
                    NoteImageGallery(imageUrls: note.imageUrls),
                ],
              ),
            ),
          ),
        );
      },
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
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(right: 1.0, top: 2.0),
                child: Icon(
                  index < filled ? Icons.landscape : Icons.landscape_outlined,
                  size: 23,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            }),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
