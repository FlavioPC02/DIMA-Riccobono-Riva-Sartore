import 'dart:math';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:hike_core/hike_core.dart';
import 'package:application/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

int totalXpTillNextLevel(int level, {int baseXp = 100, double growth = 1.2}) {
  int totalXp = 0;
  for (var i = 0; i < level + 1; i++) {
    totalXp += (baseXp * pow(growth, i + 1)).round();
  }
  return totalXp;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() {
    return _ProfilePageState();
  }
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nicknameController;
  bool _isNicknameFormExpanded = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _submitNickname() {
    final nextNickname = _nicknameController.text.trim();
    if (nextNickname.isEmpty) {
      return;
    }

    context.read<ProfileCubit>().updateNickname(nextNickname);
    FocusScope.of(context).unfocus();

    setState(() {
      _isNicknameFormExpanded = false;
    });
  }

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
    } catch (e) {
      if (!mounted) {
        return;
      }

      debugPrint(e.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Try again.')),
      );
    }
  }

  double truncateToDecimalPlaces(num value) =>
      (value * pow(10, 2)).truncate() / pow(10, 2);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final profile = context.watch<ProfileCubit>().state;
    final activities = context.watch<ActivityCubit>().state;

    if (!_isNicknameFormExpanded &&
        _nicknameController.text != profile.nickname) {
      _nicknameController.text = profile.nickname;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 30),
            SizedBox(width: 12),
            Text('Profile'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile info box
                  _Header(
                    nickname: profile.nickname,
                    email: profile.mail,
                    xpLength: profile.xp / totalXpTillNextLevel(profile.level),
                    level: profile.level,
                  ),

                  // Stats & difficulty card
                  _StatsdifficultySection(
                    hikeNumber: activities
                        .where((a) => a.status == ActivityStatus.completed)
                        .toList()
                        .length,
                    distance: truncateToDecimalPlaces(
                      activities.fold<double>(
                            0.0,
                            (distance, activity) =>
                                activity.status == ActivityStatus.completed
                                ? distance + activity.trackedDistance
                                : distance,
                          ) /
                          1000, //kilometers
                    ),
                    difficultyLevel: settings.difficulty,
                    ondifficultyChanged: (value) {
                      setState(() {
                        context.read<SettingsCubit>().updateDifficulty(value);
                      });
                    },
                    ferrataSwitchValue: settings.ferrata,
                    onFerrataSwitchChanged: (value) {
                      setState(() {
                        context.read<SettingsCubit>().updateFerrata(value);
                      });
                    },
                  ),

                  // Account settings card
                  _AccountSection(
                    nicknameController: _nicknameController,
                    isNicknameFormExpanded: _isNicknameFormExpanded,
                    onToggleNicknameForm: () {
                      setState(() {
                        _isNicknameFormExpanded = !_isNicknameFormExpanded;
                        if (_isNicknameFormExpanded) {
                          _nicknameController.text = profile.nickname;
                        }
                      });
                    },
                    onNicknameSubmitted: _submitNickname,
                    onLogout: _logout,
                    notificationValue: settings.notifications,
                    onNotificationValueChanged: (value) {
                      setState(() {
                        context.read<SettingsCubit>().updateNotifications(
                          value,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String nickname;
  final String email;
  final double xpLength;
  final int level;

  const _Header({
    required this.nickname,
    required this.email,
    required this.xpLength,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorLength = xpLength.clamp(0, 1.0).toDouble();
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.zero,
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 15),
          //Avatar + text info
          Padding(
            padding: EdgeInsetsGeometry.fromLTRB(15, 0, 15, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF4E9D8),
                    border: Border.all(
                      color: const Color(0xFF4A2F1F),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.person, size: 60),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nickname
                      Text(
                        nickname,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      // Mail
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          //XP bar
          xpBar(context, indicatorLength),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget xpBar(BuildContext context, double indicatorLength) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          //Text pointer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('XP Level', textAlign: TextAlign.left),
              Text('Level $level', textAlign: TextAlign.end),
            ],
          ),

          // progress bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 14,
                value: indicatorLength,
                backgroundColor: AppColors.inactiveTrackColor,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsdifficultySection extends StatelessWidget {
  final int hikeNumber;
  final double distance;
  final double difficultyLevel;
  final ValueChanged<double> ondifficultyChanged;
  final bool ferrataSwitchValue;
  final ValueChanged<bool> onFerrataSwitchChanged;

  const _StatsdifficultySection({
    required this.hikeNumber,
    required this.distance,
    required this.difficultyLevel,
    required this.ondifficultyChanged,
    required this.ferrataSwitchValue,
    required this.onFerrataSwitchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stats & difficulty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          //Card
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Stats row
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      //Hike number
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.terrain),
                            SizedBox(height: 6),
                            Text(hikeNumber.toString()),
                            Text(
                              hikeNumber == 1 ? 'Hike' : 'Hikes',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // Vertical divider
                      SizedBox(height: 60, child: VerticalDivider()),

                      // Distance
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.directions_walk),
                            SizedBox(height: 6),
                            // Distance text
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(distance.toString()),
                                Text(' Km'),
                              ],
                            ),
                            Text(
                              'Distance',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // difficulty Slider
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select your difficulty level:'),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 10,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 22,
                          ),
                        ),
                        child: Slider(
                          value: difficultyLevel,
                          min: 0,
                          max: 2,
                          divisions: 2,
                          onChanged: ondifficultyChanged,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Beginner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Intermediate',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Expert',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Ferrata switch
                SwitchListTile(
                  title: const Text('Ferrata equipment'),
                  secondary: const Icon(Icons.hiking),
                  value: ferrataSwitchValue,
                  onChanged: onFerrataSwitchChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final TextEditingController nicknameController;
  final bool isNicknameFormExpanded;
  final VoidCallback onToggleNicknameForm;
  final VoidCallback onNicknameSubmitted;
  final VoidCallback onLogout;
  final bool notificationValue;
  final ValueChanged<bool> onNotificationValueChanged;

  const _AccountSection({
    required this.nicknameController,
    required this.isNicknameFormExpanded,
    required this.onToggleNicknameForm,
    required this.onNicknameSubmitted,
    required this.onLogout,
    required this.notificationValue,
    required this.onNotificationValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Change nickname button
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Change nickname'),
                  trailing: Icon(
                    isNicknameFormExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  onTap: onToggleNicknameForm,
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: isNicknameFormExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: nicknameController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => onNicknameSubmitted(),
                          decoration: const InputDecoration(
                            labelText: 'New nickname',
                            hintText: 'Insert new nickname...',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: onNicknameSubmitted,
                          child: const Text('Save nickname'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Notification switch
                SwitchListTile(
                  secondary: Icon(Icons.notifications),
                  title: const Text('Notification'),
                  value: notificationValue,
                  onChanged: onNotificationValueChanged,
                ),
                const Divider(height: 1),

                // Exit button
                ListTile(
                  key: const ValueKey('logout_button'),
                  leading: const Icon(
                    Icons.power_settings_new,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Exit',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
