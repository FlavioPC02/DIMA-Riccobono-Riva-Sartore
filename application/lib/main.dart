import 'dart:async';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:application/services/background_tracking_service.dart';
import 'package:application/services/notification_service.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hike_core/hike_core.dart';
import 'screens/homepage.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );

  await NotificationService.initializeNotificationService();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LocationPointAdapter());
  }
  await DefaultBackgroundTrackingService().initialize();
  await setupLocator();

  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Block the rotation for the app
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit(SettingsRepository())),
        BlocProvider(create: (_) => ProfileCubit(ProfileRepository())),
        BlocProvider(create: (_) => ActivityCubit(ActivityRepository())),
      ],
      child: const MainApp(),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {

    final lightColorScheme = AppTheme.lightColorScheme;
    final darkColorScheme = AppTheme.darkColorScheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        switchTheme: AppTheme.buildSwitchTheme(lightColorScheme),
        elevatedButtonTheme: AppTheme.buildElevatedButtonTheme(),
        textTheme: AppTheme.buildTextTheme(),
        inputDecorationTheme: AppTheme.buildInputDecorationTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        switchTheme: AppTheme.buildSwitchTheme(darkColorScheme),
        textTheme: AppTheme.buildTextTheme(),
        elevatedButtonTheme: AppTheme.buildElevatedButtonTheme(),
        inputDecorationTheme: AppTheme.buildInputDecorationTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSubscription;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint("user = $user");
      final loggedIn = user != null;
      if(loggedIn == _isLoggedIn) return;

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      setState(() {
        _isLoggedIn = loggedIn;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn ? const Navigation() : const LoginScreen();
  }
}
