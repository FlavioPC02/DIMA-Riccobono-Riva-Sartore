import 'package:application/core/models/activity.dart';
import 'package:latlong2/latlong.dart';

class TrailDetailsScreenHelper {
  static const Distance _distanceCalc = Distance();

  static String getFormattedDistance(String? tagDistance, double calculatedMeters) {
    String distance = tagDistance ?? (calculatedMeters > 0 ? "${(calculatedMeters / 1000).toStringAsFixed(1)} km" : 'N/D');

    if (distance != 'N/D' && tagDistance != null) {
      String numericPart = distance.replaceAll(RegExp(r'[^0-9.]'), '');
      double? distValue = double.tryParse(numericPart);
      
      if (distValue != null) {
        return '${distValue.toStringAsFixed(1)} km';
      } else if (!distance.toLowerCase().contains('km')) {
        return '$distance km';
      }
    }
    return distance;
  }

  static double getDistanceKm(String? tagDistance, double calculatedMeters) {
    if (tagDistance != null) {
      String numericPart = tagDistance.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(numericPart) ?? (calculatedMeters / 1000);
    }
    return calculatedMeters / 1000;
  }

  static int getDurationMinutes(String? tagDuration, String? tagTime, double distanceKm) {
    if (tagDuration != null && tagDuration.isNotEmpty) return fromStringToMinutesInt(tagDuration);
    if (tagTime != null && tagTime.isNotEmpty) return fromStringToMinutesInt(tagTime);
    
    // Stima basata su 4 km/h se non ci sono tag
    double hours = distanceKm / 4.0;
    return (hours * 60).toInt();
  }

  static String formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return 'N/D';
    return "${totalMinutes ~/ 60}h ${totalMinutes % 60}m";
  }

  static String getFormattedAscent(String? tagAscent, String? estimatedAscent) {
    final String ascent = tagAscent ?? estimatedAscent ?? 'N/D';
    if (ascent != 'N/D') {
      String numericPart = ascent.replaceAll(RegExp(r'[^0-9.]'), '');
      return numericPart.isNotEmpty ? '+$numericPart m' : 'N/D';
    }
    return 'N/D';
  }

  static int fromStringToMinutesInt(String? duration) {
    if (duration == null || duration.isEmpty) return 0;
    duration = duration.trim();

    final matchText = RegExp(r'^(\d+)\s*h\s*(\d+)\s*m').firstMatch(duration);
    if (matchText != null) {
      return (int.parse(matchText.group(1)!) * 60) + int.parse(matchText.group(2)!);
    }

    final matchTime = RegExp(r'^(\d+):(\d{2})').firstMatch(duration);
    if (matchTime != null) {
      return (int.parse(matchTime.group(1)!) * 60) + int.parse(matchTime.group(2)!);
    }

    if (int.tryParse(duration) != null) return int.parse(duration);

    return 0;
  }

  static int calculateDifficultyLevel(Map<String, dynamic>? tags, double distanceKm, double ascentM) {    
    final cai = tags?['cai_scale']?.toString().toUpperCase();
    final sac = tags?['sac_scale']?.toString().toUpperCase();

    if (cai != null) {
      if (cai.contains('EE') || cai.contains('EAI')) return 3;
      if (cai == 'E') return 2;
      if (cai == 'T') return 1;
    }

    if (sac != null) {
      if (sac.contains('ALPINE') || sac.contains('T4') || sac.contains('T5') || sac.contains('T6')) return 3;
      if (sac.contains('MOUNTAIN_HIKING') || sac.contains('T2') || sac.contains('T3')) return 2;
      if (sac.contains('HIKING') || sac.contains('T1')) return 1;
    }

    double dist = distanceKm;
    double asc = ascentM;

    if (dist == 0 && tags?['distance'] != null) {
      dist = double.tryParse(tags!['distance'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    if (asc == 0 && tags?['ascent'] != null) {
      asc = double.tryParse(tags!['ascent'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }

    if (dist == 0 && asc == 0) return 0;

    double effortScore = dist + (asc / 100);
    
    if (effortScore < 7.0) {
      return 1;
    }
    if (effortScore < 14.0) {
      return 2;
    }
    return 3;
  }

  static double calculateXp(ActivityDifficulty difficulty) {
    switch (difficulty) {
      case ActivityDifficulty.easy: return 50;
      case ActivityDifficulty.moderate: return 100;
      case ActivityDifficulty.hard: return 200;
    }
  }

  static String getLottieAsset(int code) {
    if (code == 800) return 'assets/lottie/clear.json';
    if (code == 801) return 'assets/lottie/few_clouds.json';
    if (code >= 802) return 'assets/lottie/cloudy.json';
    if (code >= 700) return 'assets/lottie/fog.json';
    if (code >= 600) return 'assets/lottie/snow.json';
    if (code >= 500) return 'assets/lottie/rain.json';
    if (code >= 300) return 'assets/lottie/drizzle.json';
    return 'assets/lottie/thunderstorm.json';
  }

  static List<LatLng> stitchSegments(List<List<LatLng>> segments) {
    if (segments.isEmpty) return [];
    
    List<LatLng> allPoints = List.from(segments.first);
    segments.removeAt(0);

    while (segments.isNotEmpty) {
      double minDistance = double.infinity;
      int bestIndex = -1;
      int attachMode = -1;

      LatLng currentEnd = allPoints.last;
      LatLng currentStart = allPoints.first;

      for (int i = 0; i < segments.length; i++) {
        var seg = segments[i];

        double dEndFirst = _distanceCalc.as(LengthUnit.Meter, currentEnd, seg.first);
        if (dEndFirst < minDistance) { minDistance = dEndFirst; bestIndex = i; attachMode = 0; }

        double dEndLast = _distanceCalc.as(LengthUnit.Meter, currentEnd, seg.last);
        if (dEndLast < minDistance) { minDistance = dEndLast; bestIndex = i; attachMode = 1; }

        double dStartLast = _distanceCalc.as(LengthUnit.Meter, currentStart, seg.last);
        if (dStartLast < minDistance) { minDistance = dStartLast; bestIndex = i; attachMode = 2; }

        double dStartFirst = _distanceCalc.as(LengthUnit.Meter, currentStart, seg.first);
        if (dStartFirst < minDistance) { minDistance = dStartFirst; bestIndex = i; attachMode = 3; }
      }

      if (minDistance > 1000) break; // Interrompe se i segmenti sono troppo distanti

      var bestSeg = segments[bestIndex];
      if (attachMode == 0) allPoints.addAll(bestSeg.skip(1));
      else if (attachMode == 1) allPoints.addAll(bestSeg.reversed.skip(1));
      else if (attachMode == 2) allPoints.insertAll(0, bestSeg.sublist(0, bestSeg.length - 1));
      else if (attachMode == 3) allPoints.insertAll(0, bestSeg.reversed.skip(1));
      
      segments.removeAt(bestIndex);
    }
    return allPoints;
  }

  static Map<String, dynamic> samplePoints(List<LatLng> points, int maxPoints) {
    List<double> allDistances = [0.0];
    double currentDist = 0.0;
    
    for (int i = 1; i < points.length; i++) {
      currentDist += _distanceCalc.as(LengthUnit.Meter, points[i - 1], points[i]);
      allDistances.add(currentDist);
    }

    if (points.length <= maxPoints) {
      return {'points': points, 'distances': allDistances};
    }

    List<LatLng> sampledPoints = [];
    List<double> sampledDistances = [];
    double step = points.length / maxPoints;

    for (int i = 0; i < maxPoints; i++) {
      int index = (i * step).toInt();
      sampledPoints.add(points[index]);
      sampledDistances.add(allDistances[index]);
    }
    sampledPoints.add(points.last);
    sampledDistances.add(allDistances.last);

    return {'points': sampledPoints, 'distances': sampledDistances};
  }
}