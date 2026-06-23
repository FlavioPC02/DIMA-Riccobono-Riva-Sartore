import 'package:flutter_bloc/flutter_bloc.dart';

enum MapState { initial, clearSearchAndTrails }

class MapCubit extends Cubit<MapState> {
  MapCubit() : super(MapState.initial);

  void clearMap() {
    emit(MapState.clearSearchAndTrails);
    emit(MapState.initial);
  }
}