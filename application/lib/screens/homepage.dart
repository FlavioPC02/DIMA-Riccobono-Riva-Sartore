import 'package:application/core/theme/app_colors.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/services/helpers/notification_permission_helper.dart';
import 'package:flutter/material.dart';
import 'diary_page.dart';
import 'map_page.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final granted = await NotificationPermissionHelper.requestNotificationPermissions();

    if (!granted) {
      _showNotificationPermissionDialog();
    }
  }

  void _togglePage (int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  // dialog shown when location permissions are denied
  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Notification permission required', textAlign: TextAlign.center),
          content: const Text(
            'Without enabling the permission, it is not possible to send you notifications.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    //request location permissions
                    await NotificationPermissionHelper.requestNotificationPermissions();
                  },
                  child: const Text('Enable notification permission'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorBackground,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Ignore', style: TextStyle(color: AppColors.errorText)),
                ),
              ],
            ),
          ],
        );
      },
    );
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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePage();
  }
}
