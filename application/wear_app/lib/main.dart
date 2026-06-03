import 'package:flutter/material.dart';
import 'package:wear_app/features/hike_dashboard/hike_dashboard_page.dart';

void main() {
  runApp(const HikeWearApp());
}

class HikeWearApp extends StatelessWidget {
  const HikeWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF08110E);
    const panel = Color(0xFF111C18);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hike Wear',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: surface,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF84F0B5),
          secondary: Color(0xFF7DD3FC),
          surface: panel,
          error: Color(0xFFFFB86B),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontSize: 13, height: 1.2),
          bodySmall: TextStyle(fontSize: 11, height: 1.2),
        ),
      ),
      home: const HikeDashboardPage(),
    );
  }
}