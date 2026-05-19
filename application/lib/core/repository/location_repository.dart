import 'package:application/core/models/location_point.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

class LocationRepository {
  static Box get _box => Hive.box('location_box');

  //save latest position
  static Future<void> saveCurrent(LocationPoint point) async {
    debugPrint('arrivato nuovo punto');
    await _box.put('latest', point.toMap());
  }

  //append to route
  static Future<void> addToRoute(LocationPoint point) async {
    final List list = _box.get('route', defaultValue: []);
    list.add(point.toMap());
    await _box.put('route', list);
  }

  //get latest location
  static LocationPoint? getLatest() {
    final data = _box.get('latest');
    return data == null ? null : LocationPoint.fromMap(data);
  }

  //get full route
  static List<LocationPoint> getRoute() {
    final List list = _box.get('route', defaultValue: []);
    return list.map<LocationPoint>((e) => LocationPoint.fromMap(e)).toList();
  }

  static void clearRoute() {
    _box.clear();
  }
}