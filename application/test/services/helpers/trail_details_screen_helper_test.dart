import 'package:application/core/models/activity.dart'; 
import 'package:application/services/helpers/trail_details_screen_helper.dart'; 
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('TrailDetailsScreenHelper Tests', () {

    group('getFormattedDistance', () {
      test('returns calculated distance if tag is null', () {
        expect(TrailDetailsScreenHelper.getFormattedDistance(null, 1500), '1.5 km');
      });

      test('returns N/D if tag is null and calculated is 0', () {
        expect(TrailDetailsScreenHelper.getFormattedDistance(null, 0), 'N/D');
      });

      test('extracts number from textual tag and appends km', () {
        expect(TrailDetailsScreenHelper.getFormattedDistance('10.5 mi', 0), '10.5 km');
        expect(TrailDetailsScreenHelper.getFormattedDistance('12', 0), '12.0 km');
      });

      test('handles non-numeric textual tags without "km"', () {
        expect(TrailDetailsScreenHelper.getFormattedDistance('unknown', 0), 'unknown km');
      });
      
      test('handles non-numeric textual tags already containing "km"', () {
        expect(TrailDetailsScreenHelper.getFormattedDistance('a few km', 0), 'a few km');
      });
    });

    group('getDistanceKm', () {
      test('extracts value from valid tag string', () {
        expect(TrailDetailsScreenHelper.getDistanceKm('5.5km', 10000), 5.5);
      });

      test('uses calculated distance if tag is null or invalid', () {
        expect(TrailDetailsScreenHelper.getDistanceKm(null, 4500), 4.5);
        expect(TrailDetailsScreenHelper.getDistanceKm('invalid', 4500), 4.5);
      });
    });

    group('getDurationMinutes', () {
      test('uses tagDuration if available', () {
        expect(TrailDetailsScreenHelper.getDurationMinutes('1h 30m', null, 10), 90);
      });

      test('uses tagTime if tagDuration is missing', () {
        expect(TrailDetailsScreenHelper.getDurationMinutes(null, '2:00', 10), 120);
      });

      test('estimates based on distance (4 km/h) if tags are missing', () {
        expect(TrailDetailsScreenHelper.getDurationMinutes(null, null, 10.0), 150);
      });
    });

    group('formatDuration', () {
      test('formats minutes correctly into hours and minutes', () {
        expect(TrailDetailsScreenHelper.formatDuration(150), '2h 30m');
        expect(TrailDetailsScreenHelper.formatDuration(45), '0h 45m');
      });

      test('handles values <= 0', () {
        expect(TrailDetailsScreenHelper.formatDuration(0), 'N/D');
        expect(TrailDetailsScreenHelper.formatDuration(-10), 'N/D');
      });
    });

    group('getFormattedAscent', () {
      test('uses tagAscent if present and numeric', () {
        expect(TrailDetailsScreenHelper.getFormattedAscent('500', null), '+500 m');
      });

      test('uses estimatedAscent if tagAscent is missing', () {
        expect(TrailDetailsScreenHelper.getFormattedAscent(null, '300m'), '+300 m');
      });

      test('returns N/D for non-numeric or empty strings', () {
        expect(TrailDetailsScreenHelper.getFormattedAscent('invalid', null), 'N/D');
        expect(TrailDetailsScreenHelper.getFormattedAscent(null, null), 'N/D');
      });
    });

    group('fromStringToMinutesInt', () {
      test('parses "Xh Ym" format', () {
        expect(TrailDetailsScreenHelper.fromStringToMinutesInt('2h 30m'), 150);
      });

      test('parses "X:YY" format', () {
        expect(TrailDetailsScreenHelper.fromStringToMinutesInt('1:45'), 105);
      });

      test('parses numeric-only format', () {
        expect(TrailDetailsScreenHelper.fromStringToMinutesInt('120'), 120);
      });

      test('handles null, empty, or invalid inputs', () {
        expect(TrailDetailsScreenHelper.fromStringToMinutesInt(null), 0);
        expect(TrailDetailsScreenHelper.fromStringToMinutesInt(''), 0);
        expect(TrailDetailsScreenHelper.fromStringToMinutesInt('invalid'), 0);
      });
    });

    group('calculateDifficultyLevel', () {
      test('evaluates CAI scales correctly', () {
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel({'cai_scale': 'EEA'}, 0, 0), 3);
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel({'cai_scale': 'E'}, 0, 0), 2);
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel({'cai_scale': 'T'}, 0, 0), 1);
      });

      test('evaluates SAC scales correctly', () {
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel({'sac_scale': 'alpine'}, 0, 0), 3);
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel({'sac_scale': 'T2'}, 0, 0), 2);
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel({'sac_scale': 'hiking'}, 0, 0), 1);
      });

      test('calculates level based on effort (fallback) with km and ascent parameters', () {
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel(null, 2.0, 100), 1);
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel(null, 10.0, 200), 2);
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel(null, 15.0, 500), 3);
      });

      test('calculates level by extracting data from text tags if parameters are 0', () {
        final tags = {'distance': '10km', 'ascent': '200m'};
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel(tags, 0, 0), 2);
      });

      test('returns 0 if there is insufficient data', () {
        expect(TrailDetailsScreenHelper.calculateDifficultyLevel(null, 0, 0), 0);
      });
    });

    group('calculateXp', () {
      test('assigns correct XP based on difficulty', () {
        expect(TrailDetailsScreenHelper.calculateXp(ActivityDifficulty.easy), 50.0);
        expect(TrailDetailsScreenHelper.calculateXp(ActivityDifficulty.moderate), 100.0);
        expect(TrailDetailsScreenHelper.calculateXp(ActivityDifficulty.hard), 200.0);
      });
    });

    group('getLottieAsset', () {
      test('maps weather codes to correct Lottie files', () {
        expect(TrailDetailsScreenHelper.getLottieAsset(800), 'assets/lottie/clear.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(801), 'assets/lottie/few_clouds.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(802), 'assets/lottie/cloudy.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(750), 'assets/lottie/fog.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(601), 'assets/lottie/snow.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(500), 'assets/lottie/rain.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(300), 'assets/lottie/drizzle.json');
        expect(TrailDetailsScreenHelper.getLottieAsset(200), 'assets/lottie/thunderstorm.json');
      });
    });

    group('stitchSegments', () {
      test('returns empty if there are no segments', () {
        expect(TrailDetailsScreenHelper.stitchSegments([]), isEmpty);
      });

      test('stitches closest segments together (Attach mode 0: End to First)', () {
        final seg1 = [LatLng(0, 0), LatLng(0, 0.01)];
        final seg2 = [LatLng(0, 0.011), LatLng(0, 0.02)]; 

        final result = TrailDetailsScreenHelper.stitchSegments([seg1, seg2]);
        expect(result.length, 3); 
      });

      test('breaks if minimum distance is > 1000m', () {
        final seg1 = [LatLng(0, 0), LatLng(0, 0.01)];
        final seg2 = [LatLng(1, 1), LatLng(1, 1.01)]; 

        final result = TrailDetailsScreenHelper.stitchSegments([seg1, seg2]);
        expect(result.length, 2);
      });
    });
    
    group('samplePoints', () {
      test('returns all points if they are less than maxPoints', () {
        final points = [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2)];
        final result = TrailDetailsScreenHelper.samplePoints(points, 5);
        
        expect((result['points'] as List).length, 3);
        expect((result['distances'] as List).length, 3);
      });

      test('samples points correctly if they exceed maxPoints', () {
        final points = List.generate(10, (index) => LatLng(0, index.toDouble()));
        final result = TrailDetailsScreenHelper.samplePoints(points, 3);
        
        final sampledPoints = result['points'] as List;
        expect(sampledPoints.length, 4); 
      });
    });

  });
}