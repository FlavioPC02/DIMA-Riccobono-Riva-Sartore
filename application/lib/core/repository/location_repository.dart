import '../models/location_point.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/adapters.dart';

abstract class ILocationRepository {
  Future<void> save(LocationPoint point);

  List<LocationPoint> getAll();

  Future<void> clear();

  //watch for new points added by background isolate
  ValueListenable<Box<LocationPoint>> watch();
}

class HiveLocationRepository implements ILocationRepository {
  static const _boxName = 'location_box';

  late Box<LocationPoint> _box;

  Future<void> init() async {
    _box = await Hive.openBox<LocationPoint>(_boxName);
  }

  @override
  Future<void> save(LocationPoint point) async {
    await _box.add(point);
  }

  @override
  List<LocationPoint> getAll() => _box.values.toList();

  @override
  Future<void> clear() async => _box.clear();

  @override
  ValueListenable<Box<LocationPoint>> watch() => _box.listenable();
}