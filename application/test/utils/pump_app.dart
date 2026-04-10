import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Widget pumpApp({
  required Widget child,
  required SettingsCubit settingsCubit,
  required ProfileCubit profileCubit,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<ProfileCubit>.value(value: profileCubit,),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}