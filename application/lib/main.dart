import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:application/services/background_tracking_service.dart';
import 'package:application/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/homepage.dart';
import 'package:application/core/models/location_point.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'dart:ui' as ui;

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
  Hive.registerAdapter(LocationPointAdapter());
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

  static SwitchThemeData _buildSwitchTheme(ColorScheme colorScheme) {
    return SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return null;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.secondary;
        }
        return null;
      }),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const ui.Size(double.infinity, 50),
        shape: const StadiumBorder(),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 16),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Color(0xFFFFFFFF),
      primary: Color(0xFFE95F2A),
      secondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFFE1E1E1),
      shadow: Color(0xFF000000),
      onSecondary: Color(0xFF21211F),
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Color(0xFF21211F),
      primary: Color(0xFFE95F2A),
      secondary: Color(0xFF21211F),
      tertiary: Color(0xFF141414),
      shadow: Color(0xFFAAAAAA),
      onSecondary: Color(0xFFFFFFFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        switchTheme: _buildSwitchTheme(lightColorScheme),
        elevatedButtonTheme: _buildElevatedButtonTheme(),
        textTheme: _buildTextTheme(),
        inputDecorationTheme: _buildInputDecorationTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        switchTheme: _buildSwitchTheme(darkColorScheme),
        textTheme: _buildTextTheme(),
        elevatedButtonTheme: _buildElevatedButtonTheme(),
        inputDecorationTheme: _buildInputDecorationTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const Navigation();
        }

        return const LoginScreen();
      },
    );
  }
}
