import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/run_model.dart';
import '../core/constants.dart';
import '../services/zone_capture_service.dart';
import 'zones_provider.dart';

// Auto-cierre del cerco: vuelves cerca del punto de inicio tras alejarte.
const double _loopCloseRadiusMeters = 35.0; // a esta distancia del inicio cierra
const double _minAwayMeters         = 60.0; // debes alejarte al menos esto antes

// Estado inmutable de la sesión de carrera
class RunState {
  const RunState({
    this.isRunning  = false,
    this.isPaused   = false,
    this.route      = const [],
    this.polygon,
    this.isPolygonClosed = false,
    this.distanceMeters  = 0.0,
    this.durationSeconds = 0,
    this.currentPosition,
    this.distanceToStartMeters = 0.0,
    this.isCapturing = false,
    this.captureResult,
    this.capturedZoneName,
    this.lastSaved,
  });

  final bool isRunning;
  final bool isPaused;
  final List<LatLng> route;
  final List<LatLng>? polygon;
  final bool isPolygonClosed;
  final double distanceMeters;
  final int durationSeconds;
  final LatLng? currentPosition;
  final double distanceToStartMeters;
  final bool isCapturing;
  final ZoneCaptureResult? captureResult;
  final String? capturedZoneName;
  final RunModel? lastSaved;

  double get distanceKm => distanceMeters / 1000;

  // min/km — evita división por cero
  double get avgPaceMinPerKm {
    if (distanceKm < 0.01) return 0;
    return (durationSeconds / 60) / distanceKm;
  }

  String get formattedPace {
    if (avgPaceMinPerKm == 0) return '--:--';
    final min = avgPaceMinPerKm.floor();
    final sec = ((avgPaceMinPerKm - min) * 60).round();
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ¿Falta distancia mínima para poder cerrar?
  bool get reachedMinDistance => distanceMeters >= AppConstants.minRunDistanceMeters;

  RunState copyWith({
    bool? isRunning, bool? isPaused, List<LatLng>? route,
    List<LatLng>? polygon, bool? isPolygonClosed,
    double? distanceMeters, int? durationSeconds,
    LatLng? currentPosition, double? distanceToStartMeters,
    bool? isCapturing, ZoneCaptureResult? captureResult, String? capturedZoneName,
    RunModel? lastSaved,
  }) => RunState(
    isRunning:       isRunning       ?? this.isRunning,
    isPaused:        isPaused        ?? this.isPaused,
    route:           route           ?? this.route,
    polygon:         polygon         ?? this.polygon,
    isPolygonClosed: isPolygonClosed ?? this.isPolygonClosed,
    distanceMeters:  distanceMeters  ?? this.distanceMeters,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    currentPosition: currentPosition ?? this.currentPosition,
    distanceToStartMeters: distanceToStartMeters ?? this.distanceToStartMeters,
    isCapturing:     isCapturing     ?? this.isCapturing,
    captureResult:   captureResult   ?? this.captureResult,
    capturedZoneName: capturedZoneName ?? this.capturedZoneName,
    lastSaved:       lastSaved       ?? this.lastSaved,
  );
}

class RunNotifier extends Notifier<RunState> {
  Timer? _timer;
  StreamSubscription<Position>? _locationSub;
  final _uuid = const Uuid();
  double _maxDistFromStart = 0;

  // Duración por reloj de pared (fiable aunque el isolate se ralentice en background)
  DateTime? _startedAt;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pauseStart;

  @override
  RunState build() => const RunState();

  Future<void> startRun() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _maxDistFromStart = 0;
    _startedAt   = DateTime.now();
    _pausedTotal = Duration.zero;
    _pauseStart  = null;
    state = const RunState(isRunning: true);
    _startTimer();
    _startLocationTracking();
  }

  void pauseRun() {
    _timer?.cancel();
    _locationSub?.pause();
    _pauseStart = DateTime.now();
    state = state.copyWith(isPaused: true);
  }

  void resumeRun() {
    if (_pauseStart != null) {
      _pausedTotal += DateTime.now().difference(_pauseStart!);
      _pauseStart = null;
    }
    _startTimer();
    _locationSub?.resume();
    state = state.copyWith(isPaused: false);
  }

  // Finaliza la sesión (botón Parar/Finalizar): guarda si no se guardó y resetea.
  Future<void> stopRun() async {
    _timer?.cancel();
    await _locationSub?.cancel();
    if (state.lastSaved == null) await _saveRun();
    _maxDistFromStart = 0;
    _startedAt = null;
    _pausedTotal = Duration.zero;
    _pauseStart = null;
    state = const RunState();
  }

  int get _elapsedSeconds {
    if (_startedAt == null) return state.durationSeconds;
    return DateTime.now().difference(_startedAt!).inSeconds - _pausedTotal.inSeconds;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: _elapsedSeconds);
    });
  }

  void _startLocationTracking() {
    _locationSub = Geolocator.getPositionStream(locationSettings: _locationSettings())
        .listen((position) {
      if (state.isPolygonClosed) return; // ya cerrado, ignorar
      final newPoint = LatLng(position.latitude, position.longitude);
      final route    = state.route;

      double addedDistance = 0;
      if (route.isNotEmpty) {
        addedDistance = Geolocator.distanceBetween(
          route.last.latitude, route.last.longitude,
          newPoint.latitude, newPoint.longitude,
        );
      }

      final start = route.isEmpty ? newPoint : route.first;
      final distFromStart = Geolocator.distanceBetween(
        start.latitude, start.longitude,
        newPoint.latitude, newPoint.longitude,
      );
      if (distFromStart > _maxDistFromStart) _maxDistFromStart = distFromStart;

      state = state.copyWith(
        route:                 [...route, newPoint],
        currentPosition:       newPoint,
        distanceMeters:        state.distanceMeters + addedDistance,
        distanceToStartMeters: distFromStart,
      );

      _checkAutoClose();
    });
  }

  // Cierra el cerco automáticamente al volver al inicio (tras alejarte y correr
  // la distancia mínima). Luego intenta capturar la zona rodeada.
  void _checkAutoClose() {
    if (state.isPolygonClosed) return;
    if (state.route.length < AppConstants.minPolygonPoints) return;
    if (!state.reachedMinDistance) return;
    if (_maxDistFromStart < _minAwayMeters) return;
    if (state.distanceToStartMeters > _loopCloseRadiusMeters) return;

    _timer?.cancel();
    _locationSub?.cancel();

    final closed = [...state.route, state.route.first];
    state = state.copyWith(polygon: closed, isPolygonClosed: true);
    _autoCapture();
  }

  // Busca la zona cuyo centroide queda dentro del cerco y la intenta capturar.
  Future<void> _autoCapture() async {
    final polygon = state.polygon;
    if (polygon == null || polygon.length < AppConstants.minPolygonPoints) return;

    state = state.copyWith(isCapturing: true);

    final zones = ref.read(zonesProvider).valueOrNull ?? const [];
    final inside = zones
        .where((z) => _pointInPolygon(z.centroid, polygon))
        .toList();

    if (inside.isEmpty) {
      await _saveRun();
      state = state.copyWith(
        isCapturing: false,
        captureResult: ZoneCaptureResult.noZoneInArea,
      );
      return;
    }

    // Si hay varias, elige la más cercana al centro del recorrido.
    final center = _routeCentroid(polygon);
    inside.sort((a, b) => _distance(center, a.centroid)
        .compareTo(_distance(center, b.centroid)));
    final zone = inside.first;

    final result = await ref
        .read(zoneCaptureServiceProvider)
        .attemptCapture(runnerPolygon: polygon, zone: zone);

    await _saveRun(
      capturedZoneId: result == ZoneCaptureResult.success ? zone.id : null,
    );
    state = state.copyWith(
      isCapturing: false,
      captureResult: result,
      capturedZoneName: zone.name,
    );
  }

  Future<void> _saveRun({String? capturedZoneId}) async {
    if (state.lastSaved != null) return; // ya guardada
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || state.route.isEmpty) return;

    final run = RunModel(
      id:             _uuid.v4(),
      userId:         uid,
      userName:       FirebaseAuth.instance.currentUser?.displayName ?? uid,
      route:          state.route,
      polygon:        state.polygon,
      distance:       state.distanceMeters,
      duration:       state.durationSeconds,
      avgPace:        state.avgPaceMinPerKm,
      startedAt:      _startedAt ??
          DateTime.now().subtract(Duration(seconds: state.durationSeconds)),
      finishedAt:     DateTime.now(),
      capturedZoneId: capturedZoneId,
    );

    await FirebaseFirestore.instance
        .collection('runs')
        .doc(run.id)
        .set(run.toFirestore());

    state = state.copyWith(lastSaved: run);
  }

  // Ajustes de localización con servicio en primer plano: el GPS sigue
  // registrando con la app en segundo plano o el móvil bloqueado.
  LocationSettings _locationSettings() {
    if (kIsWeb) {
      return const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 3),
          // Notificación persistente → el SO mantiene viva la captura de GPS.
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'TRAZOS · carrera en curso',
            notificationText: 'Registrando tu ruta aunque bloquees el móvil.',
            enableWakeLock: true,
            notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 5);
    }
  }

  // ── Geometría ────────────────────────────────────────────────────────────────

  double _distance(LatLng a, LatLng b) => Geolocator.distanceBetween(
        a.latitude, a.longitude, b.latitude, b.longitude,
      );

  LatLng _routeCentroid(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  // Point-in-polygon por ray casting (lat/lng como y/x; ok para áreas urbanas).
  bool _pointInPolygon(LatLng point, List<LatLng> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);
