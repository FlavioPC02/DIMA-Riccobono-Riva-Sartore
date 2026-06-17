import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/pages/trail_dashboard_page.dart';
import 'package:wear_app/features/services/watch_notification_service.dart';
import 'package:wear_app/features/services/watch_wear_sync.dart';
import 'features/pages/watch_app_homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WatchNotificationService.initialize();
  //await NotificationService.initializeNotificationService();

  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WatchLocationCubit>(
        create: (_) => WatchLocationCubit(WatchWearSyncService()),
        child: HikeWearApp(),
    );
  }
}

class HikeWearApp extends StatefulWidget {
  const HikeWearApp({super.key});

  @override
  State<HikeWearApp> createState() => _HikeWearAppState();
}

class _HikeWearAppState extends State<HikeWearApp> {

  StreamSubscription<void>? _navSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<WatchLocationCubit>();
      _navSubscription = cubit.onNavigateToHike.listen((_) {
        _openTimeEtaScreen();
      });
    });
  }

  void _openTimeEtaScreen() {
    if(!mounted) return;
    _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TrailDashboardPage()),
            (route) => route.isFirst
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkColorScheme = AppTheme.darkColorScheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.scaffoldBackgroundColor,
        switchTheme: AppTheme.buildSwitchTheme(darkColorScheme),
        textTheme: AppTheme.buildTextTheme(),
        elevatedButtonTheme: AppTheme.buildElevatedButtonTheme(),
        inputDecorationTheme: AppTheme.buildInputDecorationTheme(),
      ),
      home: const WatchAppHomepage(),
    );
  }

  @override
  void dispose() {
    _navSubscription?.cancel();
    super.dispose();
  }
}