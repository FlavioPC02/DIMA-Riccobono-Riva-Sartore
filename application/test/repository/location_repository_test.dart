import 'dart:io';

import 'package:application/core/models/location_point.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

import '../utils/test_config.dart';

void main() {
	late Directory tmpDir;

	setUpAll(() async {
    setupTest();
		tmpDir = Directory.systemTemp.createTempSync('hive_test_');
		Hive.init(tmpDir.path);
		Hive.registerAdapter(LocationPointAdapter());
	});

	tearDownAll(() async {
		await Hive.close();
		try {
			if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
		} catch (_) {}
	});

	test('save() and getAll() persist and return points', () async {
		final repo = HiveLocationRepository();
		await repo.init();
		await repo.clear();

		final now = DateTime.now();
		final p = LocationPoint(
			lat: 12.34,
			lng: 56.78,
			altitude: 100.0,
			positionAccuracy: 1.0,
			altitudeAccuracy: 2.0,
			timestamp: now,
		);

		await repo.save(p);

		final all = repo.getAll();
		expect(all, hasLength(1));
		final stored = all.first;
		expect(stored.lat, equals(p.lat));
		expect(stored.lng, equals(p.lng));
		expect(stored.altitude, equals(p.altitude));
		expect(stored.positionAccuracy, equals(p.positionAccuracy));
		expect(stored.altitudeAccuracy, equals(p.altitudeAccuracy));
		expect(stored.timestamp.millisecondsSinceEpoch,
				equals(p.timestamp.millisecondsSinceEpoch));
	});

	test('clear() removes all points', () async {
		final repo = HiveLocationRepository();
		await repo.init();
		await repo.clear();

		final p1 = LocationPoint(
			lat: 1,
			lng: 2,
			altitude: 0,
			positionAccuracy: 0,
			altitudeAccuracy: 0,
			timestamp: DateTime.now(),
		);
		final p2 = LocationPoint(
			lat: 3,
			lng: 4,
			altitude: 0,
			positionAccuracy: 0,
			altitudeAccuracy: 0,
			timestamp: DateTime.now(),
		);

		await repo.save(p1);
		await repo.save(p2);
		expect(repo.getAll(), hasLength(2));

		await repo.clear();
		expect(repo.getAll(), isEmpty);
	});

	test('watch() notifies listeners on changes', () async {
		final repo = HiveLocationRepository();
		await repo.init();
		await repo.clear();

		final listenable = repo.watch();
		var notified = 0;
		void listener() => notified++;

		listenable.addListener(listener);

		final p = LocationPoint(
			lat: 7,
			lng: 8,
			altitude: 0,
			positionAccuracy: 0,
			altitudeAccuracy: 0,
			timestamp: DateTime.now(),
		);

		await repo.save(p);

		// allow notification to propagate
		await Future.delayed(const Duration(milliseconds: 100));

		expect(notified, greaterThan(0));

		listenable.removeListener(listener);
	});
}

