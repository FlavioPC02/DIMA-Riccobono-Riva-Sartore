import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/navigation_index_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../mocks/mocks_manual.dart';

Widget pumpApp({
  required Widget child,
  SettingsCubit? settingsCubit,
  ProfileCubit? profileCubit,
  ActivityCubit? activityCubit,
  NavigationIndexCubit? navigationIndexCubit,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settingsCubit ?? MockSettingsCubit(),),
      BlocProvider<ProfileCubit>.value(value: profileCubit ?? MockProfileCubit(),),
      BlocProvider<ActivityCubit>.value(value: activityCubit ?? MockActivityCubit(),),
      BlocProvider<NavigationIndexCubit>.value(value: navigationIndexCubit ?? MockNavigationIndexCubit(),),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: false,
      ),
      home: child,
    ),
  );
}