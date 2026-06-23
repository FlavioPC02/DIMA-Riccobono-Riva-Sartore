import 'trail_point.dart';

class PlannedTrail {
  final String activityId;
  final String trailId;
  // The segments of the trail, where each segment is a list of TrailPoints.
  final List<List<TrailPoint>> segments;

  const PlannedTrail({
    required this.activityId,
    required this.trailId,
    required this.segments,
  });

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'trailId': trailId,
      'segments': segments.map((segment) {
        return segment.map((point) {
          return point.toMap();
        }).toList();
      }).toList(),
    };
  }


  static PlannedTrail fromMap(Map<dynamic, dynamic> map) {
    final rawSegments = map['segments'] as List;

    return PlannedTrail(
      activityId: map['activityId'].toString(),
      trailId: map['trailId'].toString(),
      segments: rawSegments.map((rawSegment) {
        return (rawSegment as List).map((rawPoint) {
          return TrailPoint.fromMap(rawPoint as Map);
        }).toList();
      }).toList(),
    );
  }
}