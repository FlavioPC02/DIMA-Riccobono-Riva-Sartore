import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:application/services/service_locator.dart';

void main() {
  final sl = GetIt.instance;

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hive_test_dir');
    
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await sl.reset();
  });

  group('setupLocator', () {
    WidgetsFlutterBinding.ensureInitialized();
    test('should register ILocationRepository and LocationCubit correctly', () async {
      await setupLocator();

      expect(sl.isRegistered<ILocationRepository>(), isTrue);
      expect(sl<ILocationRepository>(), isA<HiveLocationRepository>());

      expect(sl.isRegistered<LocationCubit>(), isTrue);

      final cubit1 = sl<LocationCubit>();
      final cubit2 = sl<LocationCubit>();

      expect(cubit1, isA<LocationCubit>());
      expect(identical(cubit1, cubit2), isFalse);
    });
  });
}