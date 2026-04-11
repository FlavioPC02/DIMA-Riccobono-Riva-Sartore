import 'package:application/screens/profile_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Sei nella Home 🚀'),
            SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () { 
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              //TODO: sostituire con la vera homepage
                              builder: (_) => const ProfilePage(),
                            ),
                          );
                        },
                        child: const Text('Sign Up'),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}