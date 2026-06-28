import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NavigationIndexCubit extends Cubit<int> {
  StreamSubscription<User?>? _authSubscription;
  final Stream<User?> Function()? authChanges; //injectable for test

  NavigationIndexCubit({this.authChanges}) : super(0) {
    final stream = authChanges != null
        ? authChanges!()
        : FirebaseAuth.instance.authStateChanges();

    _authSubscription = stream.listen((user) {
      if (user == null) emit(0);
    });
  }

  void setIndex(int index) => emit(index);

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }
}
