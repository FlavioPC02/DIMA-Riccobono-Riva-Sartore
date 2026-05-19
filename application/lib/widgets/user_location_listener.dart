import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/models/user_location_state.dart';
import 'package:application/core/models/location_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserLocationListener extends StatelessWidget {
  
  final Function(LocationPoint? position) onLocationChanged;
  final Widget child;

  const UserLocationListener({
    super.key,
    required this.child,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, UserLocationState>(
      listener: (context, state) {
        state.when(
          unknown: () => onLocationChanged(null), 
          known: (location) {
            onLocationChanged(location);
          }, 
          error: (lastKnown, _) {
            onLocationChanged(lastKnown);
          }
        );
      },
      child: child,
    );
  }
}