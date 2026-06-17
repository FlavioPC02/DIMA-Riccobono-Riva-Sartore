import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
<<<<<<< HEAD
import 'package:application/core/repository/activity_repository.dart';
=======
import 'package:application/core/models/activity.dart';
>>>>>>> 0a4663f (implemented Hive and fixed favorites)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';

Widget pumpApp({
  required Widget child,
  SettingsCubit? settingsCubit,
  ProfileCubit? profileCubit,
  ActivityCubit? activityCubit,
}) {
  final providedActivityCubit = activityCubit;
  final resolvedActivityCubit = providedActivityCubit ?? MockActivityCubit();
  if (providedActivityCubit == null) {
    when(
      () => resolvedActivityCubit.stream,
    ).thenAnswer((_) => const Stream<List<Activity>>.empty());
    when(() => resolvedActivityCubit.state).thenReturn(const <Activity>[]);
  }

  return MultiBlocProvider(
    providers: [
<<<<<<< HEAD
      BlocProvider<SettingsCubit>.value(value: settingsCubit ?? MockSettingsCubit(),),
      BlocProvider<ProfileCubit>.value(value: profileCubit ?? MockProfileCubit(),),
      BlocProvider<ActivityCubit>.value(
        value: activityCubit ?? ActivityCubit(
          ActivityRepository(hasCurrentUser: () => false),
        ),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: false,
=======
      BlocProvider<SettingsCubit>.value(
        value: settingsCubit ?? MockSettingsCubit(),
>>>>>>> 0a4663f (implemented Hive and fixed favorites)
      ),
      BlocProvider<ProfileCubit>.value(
        value: profileCubit ?? MockProfileCubit(),
      ),
      BlocProvider<ActivityCubit>.value(value: resolvedActivityCubit),
    ],
    child: MaterialApp(theme: ThemeData(useMaterial3: false), home: child),
  );
}
