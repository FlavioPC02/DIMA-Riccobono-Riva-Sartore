import 'package:application/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'map_page.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _currentPageIndex = 0;

  void _togglePage (int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //indexed stack keeps the state of each page alive when switching between them
      body: IndexedStack(
        index: _currentPageIndex,
        children: const <Widget>[
          MapPage(),
          DiaryPage(),
          SettingsPage(),   
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        onDestinationSelected: _togglePage,
        selectedIndex: _currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.map),
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.book),
            icon: Icon(Icons.book_outlined),
            label: 'Diary',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person),
            icon: Icon(Icons.person_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("diary", style: TextStyle(fontSize: 40), textAlign: TextAlign.center,),);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePage();
  }
}
