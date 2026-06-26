import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NavigationIndexCubit extends Cubit<int>{
  StreamSubscription<User?>? _authSubscription;
  
  NavigationIndexCubit() : super(0) {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
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