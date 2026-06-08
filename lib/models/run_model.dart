import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunModel extends Equatable {
  const RunModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.route,
    required this.distance,
    required this.duration,
    required this.startedAt,
    this.clubId,
    this.polygon,
    this.avgPace,
    this.finishedAt,
    this.capturedZoneId,
    this.stravaActivityId,
  });

  final String id;
  final String userId;
  final String userName;
  final String? clubId;
  final List<LatLng> route;
  final List<LatLng>? polygon;
  final double distance;  // metros
  final int    duration;  // segundos
  final double? avgPace;  // min/km
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? capturedZoneId;
  final String? stravaActivityId;

  String get formattedDuration {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get distanceKm => distance / 1000;

  factory RunModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;

    List<LatLng> parsePoints(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((p) {
        final m = p as Map;
        return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
      }).toList();
    }

    return RunModel(
      id:               doc.id,
      userId:           d['userId']   as String,
      userName:         d['userName'] as String,
      clubId:           d['clubId']   as String?,
      route:            parsePoints(d['route']),
      polygon:          parsePoints(d['polygon']),
      distance:         (d['distance'] as num).toDouble(),
      duration:         (d['duration'] as num).toInt(),
      avgPace:          (d['avgPace']  as num?)?.toDouble(),
      startedAt:        (d['startedAt']  as Timestamp).toDate(),
      finishedAt:       (d['finishedAt'] as Timestamp?)?.toDate(),
      capturedZoneId:   d['capturedZoneId']   as String?,
      stravaActivityId: d['stravaActivityId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    List<Map<String, double>> serializePoints(List<LatLng>? pts) =>
        (pts ?? []).map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

    return {
      'userId':    userId,
      'userName':  userName,
      if (clubId != null) 'clubId': clubId,
      'route':     serializePoints(route),
      if (polygon != null && polygon!.isNotEmpty) 'polygon': serializePoints(polygon),
      'distance':  distance,
      'duration':  duration,
      if (avgPace != null) 'avgPace': avgPace,
      'startedAt': Timestamp.fromDate(startedAt),
      if (finishedAt != null) 'finishedAt': Timestamp.fromDate(finishedAt!),
      if (capturedZoneId   != null) 'capturedZoneId':   capturedZoneId,
      if (stravaActivityId != null) 'stravaActivityId': stravaActivityId,
    };
  }

  @override
  List<Object?> get props => [id, userId, distance, duration, startedAt];
}
