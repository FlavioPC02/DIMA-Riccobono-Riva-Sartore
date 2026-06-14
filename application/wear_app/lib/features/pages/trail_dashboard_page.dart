import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';

import 'package:wear_app/features/models/page_descriptor.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/widgets/compass_widget.dart';
import 'package:wear_app/features/widgets/page_chrome.dart';

//class TrailDashboardPage extends StatefulWidget {
//  const TrailDashboardPage({super.key});
//
//  @override
//  State<TrailDashboardPage> createState() => _TrailDashboardPageState();
//}
//
//class _TrailDashboardPageState extends State<TrailDashboardPage> {
//  static const double _initialTravelledMeters = 0.0;
//  static const double _initialTrailDistanceMeters = 0.0;
//  static const double _initialWaypointMeters = 0.0;
//
//  final PageController _pageController = PageController();
//  final List<PageDescriptor> _pages = const [
//    PageDescriptor(
//      title: 'Hike Progress',
//      subtitle: 'Default active screen',
//      icon: Icons.directions_walk_rounded,
//    ),
//    PageDescriptor(
//      title: 'Stats Screen',
//      subtitle: 'Swipe left for elevation and speed',
//      icon: Icons.insights_rounded,
//    ),
//    PageDescriptor(
//      title: 'Map Bearing Screen',
//      subtitle: 'Swipe right for compass guidance',
//      icon: Icons.explore_rounded,
//    ),
//  ];
//
//
//  int _pageIndex = 0;
//  bool _controlsVisible = false;
//  bool _offTrailAlertVisible = false;
//
//  @override
//  void initState() {
//    super.initState();
//  }
//
//  @override
//  void dispose() {
//    _pageController.dispose();
//    super.dispose();
//  }
//
//  //HikeTrailProgress get _trailProgress => HikeTrailProgress(
//  //      travelledMeters: _travelledMeters,
//  //      trailDistanceMeters: _trailDistanceMeters,
//  //      bearingDegrees: _bearingDegrees,
//  //    );
//
//  DateTime get _eta => DateTime.now().add(_etaDuration);
//
//  Duration get _etaDuration {
//    final speedMps = math.max(_currentSpeedKmh / 3.6, 0.3);
//    final remainingMeters = math.max(0.0, _trailDistanceMeters - _travelledMeters);
//    return Duration(seconds: (remainingMeters / speedMps).round());
//  }
//
//  void _setPage(int index) {
//    if (index < 0 || index >= _pages.length) {
//      return;
//    }
//
//    _pageController.animateToPage(
//      index,
//      duration: const Duration(milliseconds: 220),
//      curve: Curves.easeOut,
//    );
//  }
//
//  void _toggleControls() {
//    setState(() {
//      _controlsVisible = !_controlsVisible;
//    });
//  }
//
//  void _openControls() {
//    if (_controlsVisible) {
//      return;
//    }
//
//    setState(() {
//      _controlsVisible = true;
//    });
//  }
//
//  void _hideControls() {
//    if (!_controlsVisible) {
//      return;
//    }
//
//    setState(() {
//      _controlsVisible = false;
//    });
//  }
//
//  void _startOrResume() {
//    setState(() {
//      _recordingState = HikeRecordingState.recording;
//      _controlsVisible = false;
//    });
//  }
//
//  void _pauseRecording() {
//    setState(() {
//      _recordingState = HikeRecordingState.paused;
//    });
//  }
//
//  void _stopHike() {
//    setState(() {
//      _recordingState = HikeRecordingState.idle;
//      _controlsVisible = false;
//      _offTrailAlertVisible = false;
//      _pageIndex = 0;
//      _travelledMeters = _initialTravelledMeters;
//      _trailDistanceMeters = _initialTrailDistanceMeters;
//      _elevationGainMeters = 168.0;
//      _currentSpeedKmh = 0;
//      _waypointDistanceMeters = _initialWaypointMeters;
//      _bearingDegrees = 38.0;
//      _elapsed = const Duration(hours: 1, minutes: 42, seconds: 18);
//    });
//
//    _setPage(0);
//  }
//
//  void _showOffTrailAlert() {
//    _alertTimer?.cancel();
//    HapticFeedback.mediumImpact();
//
//    setState(() {
//      _offTrailAlertVisible = true;
//    });
//
//    _alertTimer = Timer(const Duration(seconds: 4), () {
//      if (!mounted) {
//        return;
//      }
//
//      setState(() {
//        _offTrailAlertVisible = false;
//      });
//    });
//  }
//
//  void _dismissAlert() {
//    _alertTimer?.cancel();
//    setState(() {
//      _offTrailAlertVisible = false;
//    });
//  }
//
//  Widget _pageFooter(String primary, String secondary) {
//    return Column(
//      children: [
//        Text(
//          primary,
//          textAlign: TextAlign.center,
//          style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                color: Colors.white,
//                fontWeight: FontWeight.w800,
//              ),
//        ),
//        const SizedBox(height: 4),
//        Text(
//          secondary,
//          textAlign: TextAlign.center,
//          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                color: Colors.white60,
//              ),
//        ),
//      ],
//    );
//  }
//
//  Widget _progressPage() {
//    return GestureDetector(
//      behavior: HitTestBehavior.opaque,
//      onLongPress: _openControls,
//      child: Padding(
//        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
//        child: HikeMetricScreen.distance(
//          distanceMeters: _travelledMeters,
//          trailProgress: _trailProgress,
//          footer: Column(
//            children: [
//              Row(
//                children: [
//                  Expanded(
//                    child: Text(
//                      _elapsed.toCompactLabel(),
//                      textAlign: TextAlign.center,
//                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                            color: Colors.white70,
//                            fontWeight: FontWeight.w700,
//                          ),
//                    ),
//                  ),
//                  Expanded(
//                    child: Text(
//                      _eta.toCompactLabel(),
//                      textAlign: TextAlign.center,
//                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                            color: Colors.white70,
//                            fontWeight: FontWeight.w700,
//                          ),
//                    ),
//                  ),
//                ],
//              ),
//            ],
//          ),
//        ),
//      ),
//    );
//  }
//
//  Widget _progressActions() {
//    return Padding(
//      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
//      child: FilledButton.tonalIcon(
//        key: const Key('off-trail-button'),
//        onPressed: _showOffTrailAlert,
//        icon: const Icon(Icons.warning_amber_rounded),
//        label: const Text('Off-trail'),
//      ),
//    );
//  }
//
//  Widget _statsPage() {
//    return GestureDetector(
//      behavior: HitTestBehavior.opaque,
//      onLongPress: _openControls,
//      child: Padding(
//        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
//        child: HikeMetricScreen(
//          title: 'Elevation gain',
//          value: formatDistanceMeters(_elevationGainMeters),
//          subtitle: 'Current speed ${_currentSpeedKmh.toStringAsFixed(1)} km/h',
//          trailProgress: _trailProgress,
//          footer: _pageFooter(
//            'Climbing steady',
//            'Swipe right to return to hike progress',
//          ),
//        ),
//      ),
//    );
//  }
//
//  Widget _mapPage() {
//    return GestureDetector(
//      behavior: HitTestBehavior.opaque,
//      onLongPress: _openControls,
//      child: Padding(
//        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
//        child: HikeMetricScreen(
//          title: 'Map Bearing',
//          value: '${_bearingDegrees.toStringAsFixed(0)}°',
//          subtitle: '${_waypointDistanceMeters.round()} m to next waypoint',
//          trailProgress: _trailProgress,
//          footer: Column(
//            children: [
//              CompassWidget(bearingDegrees: _bearingDegrees),
//              const SizedBox(height: 10),
//              _pageFooter(
//                'Bearing locked',
//                'Swipe left to return to hike progress',
//              ),
//            ],
//          ),
//        ),
//      ),
//    );
//  }
//
//  Widget _controlsOverlay() {
//    return Positioned.fill(
//      child: IgnorePointer(
//        ignoring: !_controlsVisible,
//        child: AnimatedOpacity(
//          opacity: _controlsVisible ? 1 : 0,
//          duration: const Duration(milliseconds: 180),
//          child: GestureDetector(
//            behavior: HitTestBehavior.opaque,
//            onTap: _hideControls,
//            child: Container(
//              color: Colors.black.withValues(alpha: 0.72),
//              alignment: Alignment.center,
//              child: GestureDetector(
//                onTap: () {},
//                child: Container(
//                  margin: const EdgeInsets.symmetric(horizontal: 18),
//                  padding: const EdgeInsets.all(18),
//                  decoration: BoxDecoration(
//                    color: const Color(0xFF121C18),
//                    borderRadius: BorderRadius.circular(28),
//                    border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
//                  ),
//                  child: HikeRecordingControls(
//                    state: _recordingState,
//                    onStart: _startOrResume,
//                    onPause: _pauseRecording,
//                    onStop: _stopHike,
//                  ),
//                ),
//              ),
//            ),
//          ),
//        ),
//      ),
//    );
//  }
//
//  Widget _alertOverlay() {
//    final remainingMeters = math.max(0.0, _trailDistanceMeters - _travelledMeters).round();
//
//    return Positioned.fill(
//      child: IgnorePointer(
//        ignoring: !_offTrailAlertVisible,
//        child: AnimatedOpacity(
//          opacity: _offTrailAlertVisible ? 1 : 0,
//          duration: const Duration(milliseconds: 160),
//          child: GestureDetector(
//            behavior: HitTestBehavior.opaque,
//            onTap: _dismissAlert,
//            child: Container(
//              color: Colors.black.withValues(alpha: 0.72),
//              alignment: Alignment.center,
//              child: Container(
//                margin: const EdgeInsets.symmetric(horizontal: 18),
//                padding: const EdgeInsets.all(18),
//                decoration: BoxDecoration(
//                  color: const Color(0xFF2B1B10),
//                  borderRadius: BorderRadius.circular(28),
//                  border: Border.all(
//                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.72),
//                  ),
//                ),
//                child: Column(
//                  mainAxisSize: MainAxisSize.min,
//                  children: [
//                    Text(
//                      'Return to trail',
//                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                            color: Colors.white,
//                            fontWeight: FontWeight.w800,
//                          ),
//                    ),
//                    const SizedBox(height: 8),
//                    HikeOffTrailBanner(
//                      distanceMeters: remainingMeters,
//                      direction: 'Haptic alert sent. Turn back toward the path.',
//                      onDismiss: _dismissAlert,
//                    ),
//                  ],
//                ),
//              ),
//            ),
//          ),
//        ),
//      ),
//    );
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      body: SafeArea(
//        child: Stack(
//          children: [
//            GestureDetector(
//              behavior: HitTestBehavior.opaque,
//              onLongPress: _toggleControls,
//              child: Column(
//                children: [
//                  PageChrome(
//                    descriptor: _pages[_pageIndex],
//                    pageIndex: _pageIndex,
//                  ),
//                  Expanded(
//                    child: PageView(
//                      key: const Key('watch-page-view'),
//                      controller: _pageController,
//                      onPageChanged: (value) {
//                        setState(() {
//                          if (value >= 0 &&value < 3) {
//                            _pageIndex = value; 
//                          }
//                        });
//                      },
//                      children: [
//                        _progressPage(),
//                        _progressActions(),
//                        _statsPage(),
//                        _mapPage(),
//                      ],
//                    ),
//                  ),
//                  Padding(
//                    padding: const EdgeInsets.only(bottom: 10),
//                    child: Row(
//                      mainAxisAlignment: MainAxisAlignment.center,
//                      children: List.generate(_pages.length, (index) {
//                        final selected = index == _pageIndex;
//                        return AnimatedContainer(
//                          duration: const Duration(milliseconds: 180),
//                          margin: const EdgeInsets.symmetric(horizontal: 4),
//                          height: 6,
//                          width: selected ? 18 : 6,
//                          decoration: BoxDecoration(
//                            color: selected
//                                ? Theme.of(context).colorScheme.primary
//                                : Colors.white24,
//                            borderRadius: BorderRadius.circular(99),
//                          ),
//                        );
//                      }),
//                    ),
//                  ),
//                ],
//              ),
//            ),
//            Positioned(
//              top: 8,
//              right: 8,
//              child: AnimatedOpacity(
//                opacity: _controlsVisible ? 0.0 : 1.0,
//                duration: const Duration(milliseconds: 180),
//                child: Material(
//                  color: const Color(0xFF16211D),
//                  shape: const CircleBorder(),
//                  child: IconButton(
//                    key: const Key('crown-button'),
//                    onPressed: _openControls,
//                    icon: const Icon(Icons.circle_outlined),
//                    tooltip: 'Crown controls',
//                  ),
//                ),
//              ),
//            ),
//            _controlsOverlay(),
//            _alertOverlay(),
//          ],
//        ),
//      ),
//    );
//  }
//}

class TrailDashboardPage extends StatelessWidget{
  const TrailDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<WatchLocationCubit, WatchLocationState, double>(
      selector: (state) => state.stats.distanceMeters, 
      builder: (context, distance) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${distance.toStringAsFixed(2)} m',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const Text('distance'),
            ],
          ),
        );
      }
    );
  }
}