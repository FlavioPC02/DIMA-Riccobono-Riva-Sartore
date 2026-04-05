import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/homepage.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //mapbox public token used to display the map
  //removed for now to avoid github token scanning bot
  //TODO: when a definitive package name is chosen, restrict token usage inside mapbox dashboard to prevent unauthorized use 
  MapboxOptions.setAccessToken("");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Navigation(),
        ),
      ),
    );
  }
}
