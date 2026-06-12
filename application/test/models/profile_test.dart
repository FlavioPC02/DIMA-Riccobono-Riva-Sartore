import 'package:flutter_test/flutter_test.dart';
import 'package:application/core/models/profile.dart';

void main() {
  group('Profile', () {
    test('copyWith updates provided fields only', () {
      final profile = Profile(
        nickname: 'user',
        mail: 'user@example.com',
        xp: 123.4,
        level: 5,
      );

      final updated = profile.copyWith(xp: 200.0, level: 6);
      expect(updated.nickname, 'user');
      expect(updated.mail, 'user@example.com');
      expect(updated.xp, 200.0);
      expect(updated.level, 6);
    });

    test('toJson contains the expected fields', () {
      final profile = Profile(
        nickname: 'tester',
        mail: 'tester@mail.com',
        xp: 55.5,
        level: 2,
      );

      final json = profile.toJson();
      expect(json, {
        'nickname': 'tester',
        'email': 'tester@mail.com',
        'xp': 55.5,
        'level': 2,
      });
    });

    test('fromJson uses defaults when fields are missing', () {
      final profile = Profile.fromJson({});
      expect(profile.nickname, 'name');
      expect(profile.mail, 'placeholder@mail.com');
      expect(profile.xp, 0.0);
      expect(profile.level, 0);
    });
  });
}
