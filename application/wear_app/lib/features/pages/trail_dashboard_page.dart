import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/pages/distance_screen.dart';
import 'package:wear_app/features/pages/elevation_screen.dart';
import 'package:wear_app/features/pages/time_eta_screen.dart';
import 'package:wear_app/features/widgets/command_overlay.dart';
import 'package:wear_app/features/widgets/scroll_indicator.dart';
import 'package:wear_plus/wear_plus.dart';

class TrailDashboardPage extends StatefulWidget{
  const TrailDashboardPage({super.key});

  @override
  State<TrailDashboardPage> createState() => _TrailDashboardPageState();
}

class _TrailDashboardPageState extends State<TrailDashboardPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showCommands = false;

  //Circular layout changes the UI
  bool _isRound = true;

  static const int _pageCount = 3;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WatchShape(
        builder: (context, shape, child) {
          _isRound = shape == WearShape.round;

          return AmbientMode(
              builder: (context, mode, child) {
                if (mode == WearMode.ambient) {
                  return _buildAmbientView();
                }
                return _buildActiveView();
              }
          );
        }
    );
  }

  Widget _buildAmbientView() {
    return BlocBuilder<WatchLocationCubit, WatchLocationState>(
        buildWhen: (p, c) => p.stats.elapsedTime != c.stats.elapsedTime,
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                state.stats.elapsedTime.toCompactLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w200,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildActiveView() {
    final screenSize = MediaQuery.of(context).size;
    final buttonSize = screenSize.width * 0.13;
    final buttonIconSize = buttonSize * 0.55;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1410),
      body: Stack(
        children: [
          //Main page view
          PageView(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            children: const [
              TimeEtaScreen(),
              DistanceScreen(),
              ElevationScreen(),
            ],
          ),

          //Vertical scroller
          Positioned(
              right: _isRound ? screenSize.width * 0.05 : 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: ScrollIndicator(
                    pageCount: _pageCount,
                    currentPage: _currentPage,
                    isRound: _isRound,
                ),
              ),
          ),

          //Command button (bottom-left)
          Positioned(
            left: _isRound ? screenSize.width * 0.16 : 8,
            bottom: _isRound ? screenSize.height * 0.14 : 10,
            child: GestureDetector(
              onTap: () => setState(() => _showCommands = !_showCommands),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  _showCommands ? Icons.close : Icons.more_horiz,
                  size: buttonIconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          //Command overlay
          if (_showCommands)
            CommandOverlay(
              isRound: _isRound,
              onDismiss: () => setState(() {
                _showCommands = false;
              }),
            ),
        ],
      ),
    );
  }

}