import 'package:application/core/cubit/user_location_cubit.dart';
import 'package:application/core/models/user_location_state.dart';
import 'package:application/core/models/user_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserLocationListener extends StatelessWidget {
  
  final Function(UserPosition? position) onLocationChanged;
  final Widget child;

  const UserLocationListener({
    super.key,
    required this.child,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserLocationCubit(),
      child: Builder(
        builder: (context) {
          return BlocListener<UserLocationCubit, UserLocationState>(
            listener: (context, state) => state.when(
              unknown: () => onLocationChanged(null), 
              known: (location) => onLocationChanged(location),
              error: (lastKnownLocation, _) => 
                onLocationChanged(lastKnownLocation),
            ),
            child: child,
          );
        }
      ),
    );
  }
}