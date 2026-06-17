import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/widgets/dim_label.dart';
import 'package:wear_app/features/widgets/screen_shell.dart';

class TimeEtaScreen extends StatefulWidget{
  const TimeEtaScreen({super.key});

  @override
  State<TimeEtaScreen> createState() => _TimeEtaScreenState();
}

class _TimeEtaScreenState extends State<TimeEtaScreen> with AutomaticKeepAliveClientMixin {
  //Timer to interpolate time locally between syncs
  late Timer _timer;
  Duration _localElapsed = Duration.zero;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final initialState = context.read<WatchLocationCubit>().state;
    _localElapsed = _calculateInterpolatedTime(initialState);

    _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) {
          if (!mounted) return;
          final state = context.read<WatchLocationCubit>().state;
          if(state.isRecording) {
            setState(() {
              _localElapsed = _calculateInterpolatedTime(state);
            });
          }
        });
  }

  Duration _calculateInterpolatedTime(WatchLocationState state) {
    if (!state.isRecording) return state.stats.elapsedTime;
    return state.stats.elapsedTime + DateTime.now().difference(state.lastUpdate);
  }

  @override
  void dispose() {
    _localElapsed = Duration.zero;
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;

    return MultiBlocListener(
      listeners: [
        BlocListener<WatchLocationCubit, WatchLocationState>(
          listenWhen: (p, c) => p.stats.elapsedTime != c.stats.elapsedTime || p.status != c.status,
          listener: (context, state) {
            setState(() {
              _localElapsed = state.status == HikeRecordingStatus.stopped 
                  ? Duration.zero 
                  : _calculateInterpolatedTime(state);
            });
          },
        ),
      ],
      child: BlocBuilder<WatchLocationCubit, WatchLocationState>(
          buildWhen: (p, c) => p.stats.eta != c.stats.eta,
          builder: (context, state) {
            final eta = state.stats.eta;
            final etaStr = eta.toCompactLabel();

            return ScreenShell(
                icon: Icons.timer_outlined,
                label: 'Time',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _localElapsed.toCompactLabel(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (screenSize.width * 0.11).clamp(18.0, 28.0),
                          fontWeight: FontWeight.w300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const DimLabel(text: 'elapsed'),
                    SizedBox(height: screenSize.height * 0.02),
                    Container(height: 1, width: screenSize.width * 0.15, color: Colors.white12,),
                    SizedBox(height: screenSize.height * 0.02),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        etaStr,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: (screenSize.width * 0.085).clamp(14.0, 22.0),
                          fontWeight: FontWeight.w400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const DimLabel(text: 'eta'),
                  ],
                )
            );
          }
      ),
    );
  }
}