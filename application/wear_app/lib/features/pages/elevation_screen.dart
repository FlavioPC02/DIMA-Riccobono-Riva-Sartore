import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/widgets/dim_label.dart';
import 'package:wear_app/features/widgets/screen_shell.dart';

class ElevationScreen extends StatelessWidget {
    const ElevationScreen({super.key});

    @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocBuilder<WatchLocationCubit, WatchLocationState>(
        buildWhen: (p, c) => p.stats.elevationGapMeters != c.stats.elevationGapMeters,
        builder: (context, state) {
          final gap = state.stats.elevationGapMeters ?? 0.0;
          final sign = gap >= 0 ? '+' : '-';
          final gapStr = '$sign${gap.toStringAsFixed(0)} m';

          return ScreenShell(
              icon: Icons.terrain_outlined,
              label: 'Elevation',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    gap >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: gap >= 0
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFE57373),
                    size: (screenSize.width * 0.12).clamp(20.0, 30.0),
                  ),
                  SizedBox(height: screenSize.height * 0.02),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      gapStr,
                      style: TextStyle(
                        color: gap >= 0
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFE57373),
                        fontSize: (screenSize.width * 0.12).clamp(20.0, 30.0),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const DimLabel('elevation gap'),
                ],
              ),
          );
        }
    );
  }
}