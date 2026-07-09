import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/run_model.dart';
import '../core/constants.dart';
import '../dev/location_simulator.dart';
import '../services/zone_capture_service.dart';
import 'zones_provider.dart';

// Auto-cierre del cerco: vuelves cerca del punto de inicio tras alejarte.
const double _loopCloseRadiusMeters =
    35.0; // a esta distancia del inicio cierra
const double _minAwayMeters = 60.0; // debes alejarte al menos esto antes

// Estado inmutable de la sesión de carrera
class RunState {
  const RunState({
    this.isRunning = false,
    this.isPaused = false,
    this.route = const [],
    this.polygon,
    this.isPolygonClosed = false,
    this.distanceMeters = 0.0,
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
  bool get reachedMinDistance =>
      distanceMeters >= AppConstants.minRunDistanceMeters;

  RunState copyWith({
    bool? isRunning,
    bool? isPaused,
    List<LatLng>? route,
    List<LatLng>? polygon,
    bool? isPolygonClosed,
    double? distanceMeters,
    int? durationSeconds,
    LatLng? currentPosition,
    double? distanceToStartMeters,
    bool? isCapturing,
    ZoneCaptureResult? captureResult,
    String? capturedZoneName,
    RunModel? lastSaved,
  }) =>
      RunState(
        isRunning: isRunning ?? this.isRunning,
        isPaused: isPaused ?? this.isPaused,
        route: route ?? this.route,
        polygon: polygon ?? this.polygon,
        isPolygonClosed: isPolygonClosed ?? this.isPolygonClosed,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        currentPosition: currentPosition ?? this.currentPosition,
        distanceToStartMeters:
            distanceToStartMeters ?? this.distanceToStartMeters,
        isCapturing: isCapturing ?? this.isCapturing,
        captureResult: captureResult ?? this.captureResult,
        capturedZoneName: capturedZoneName ?? this.capturedZoneName,
        lastSaved: lastSaved ?? this.lastSaved,
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

  // Tiempo de la última lectura GPS, para calcular velocidad por segmento.
  DateTime? _lastPosTime;

  @override
  RunState build() => const RunState();

  Future<void> startRun() async {
    if (!kSimulateLocation) {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    } else {
      // Modo simulación: siembra el punto de partida en la última ubicación
      // conocida si la hay (si no, se queda en el centro de Madrid por defecto).
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          LocationSimulator.instance.lat = last.latitude;
          LocationSimulator.instance.lng = last.longitude;
        }
      } catch (_) {/* sin GPS: usa el punto por defecto del simulador */}
    }

    _maxDistFromStart = 0;
    _startedAt = DateTime.now();
    _pausedTotal = Duration.zero;
    _pauseStart = null;
    _lastPosTime = null;
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
    if (kSimulateLocation) LocationSimulator.instance.stop();
    await _locationSub?.cancel();
    if (state.lastSaved == null) await _saveRun();
    _maxDistFromStart = 0;
    _startedAt = null;
    _pausedTotal = Duration.zero;
    _pauseStart = null;
    _lastPosTime = null;
    state = const RunState();
  }

  int get _elapsedSeconds {
    if (_startedAt == null) return state.durationSeconds;
    return DateTime.now().difference(_startedAt!).inSeconds -
        _pausedTotal.inSeconds;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: _elapsedSeconds);
    });
  }

  void _startLocationTracking() {
    // En modo simulación el joystick alimenta las posiciones; si no, GPS real.
    final stream = kSimulateLocation
        ? LocationSimulator.instance.positions
        : Geolocator.getPositionStream(locationSettings: _locationSettings());
    _locationSub = stream.listen((position) {
      if (state.isPolygonClosed) return; // ya cerrado, ignorar
      final newPoint = LatLng(position.latitude, position.longitude);
      final route = state.route;
      final now = position.timestamp;

      double addedDistance = 0;
      if (route.isNotEmpty) {
        final segMeters = Geolocator.distanceBetween(
          route.last.latitude,
          route.last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        // Velocidad del segmento; si es un salto imposible (deriva GPS o
        // vehículo) no sumamos su distancia para no inflar los km.
        final segSecs = _lastPosTime != null
            ? now.difference(_lastPosTime!).inMilliseconds / 1000.0
            : 0.0;
        final segKmh =
            segSecs > 0 ? (segMeters / 1000) / (segSecs / 3600) : 0.0;
        if (segKmh <= AppConstants.glitchSpeedKmh) {
          addedDistance = segMeters;
        }
      }
      _lastPosTime = now;

      final start = route.isEmpty ? newPoint : route.first;
      final distFromStart = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
      if (distFromStart > _maxDistFromStart) _maxDistFromStart = distFromStart;

      state = state.copyWith(
        route: [...route, newPoint],
        currentPosition: newPoint,
        distanceMeters: state.distanceMeters + addedDistance,
        distanceToStartMeters: distFromStart,
      );

      _checkAutoClose();
    });

    // Emite la posición de partida para que la ruta tenga un primer punto.
    if (kSimulateLocation) LocationSimulator.instance.begin();
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
    if (polygon == null || polygon.length < AppConstants.minPolygonPoints) {
      return;
    }

    state = state.copyWith(isCapturing: true);

    // Anti-trampas: la velocidad media de toda la carrera debe ser de correr,
    // no de bici/coche (ni de estar parado).
    final hours = state.durationSeconds / 3600.0;
    final avgKmh = hours > 0 ? (state.distanceMeters / 1000) / hours : 0.0;
    if (avgKmh > AppConstants.maxAvgSpeedKmh ||
        avgKmh < AppConstants.minAvgSpeedKmh) {
      await _saveRun();
      state = state.copyWith(
        isCapturing: false,
        captureResult: ZoneCaptureResult.invalidSpeed,
      );
      return;
    }

    final zones = ref.read(zonesProvider).valueOrNull ?? const [];
    final inside =
        zones.where((z) => _pointInPolygon(z.centroid, polygon)).toList();

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
    inside.sort((a, b) =>
        _distance(center, a.centroid).compareTo(_distance(center, b.centroid)));
    final zone = inside.first;

    final result = await ref.read(zoneCaptureServiceProvider).attemptCapture(
          runnerPolygon: polygon,
          zone: zone,
          distanceMeters: state.distanceMeters,
          durationSeconds: state.durationSeconds,
        );

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
      id: _uuid.v4(),
      userId: uid,
      userName: FirebaseAuth.instance.currentUser?.displayName ?? uid,
      route: state.route,
      polygon: state.polygon,
      distance: state.distanceMeters,
      duration: state.durationSeconds,
      avgPace: state.avgPaceMinPerKm,
      startedAt: _startedAt ??
          DateTime.now().subtract(Duration(seconds: state.durationSeconds)),
      finishedAt: DateTime.now(),
      capturedZoneId: capturedZoneId,
    );

    await FirebaseFirestore.instance
        .collection('runs')
        .doc(run.id)
        .set(run.toFirestore());

    state = state.copyWith(lastSaved: run);

    // Suma los km de esta carrera al total del usuario. Dispara onUserStatsWritten
    // en el servidor, que recalcula los totales del club. (Las reglas permiten
    // que el usuario edite su propio totalKm.)
    if (state.distanceMeters > 0) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'totalKm': FieldValue.increment(state.distanceMeters / 1000),
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (_) {/* la carrera ya quedó guardada; no bloquear por esto */}
    }
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
            notificationIcon:
                AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
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
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
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
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);
