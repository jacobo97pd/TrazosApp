import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── SIMULADOR DE GPS (temporal, solo para pruebas) ──────────────────────────
///
/// Permite "moverse" por el mapa con un joystick sin salir a correr de verdad.
///
/// Es un interruptor en tiempo de ejecución (Ajustes → "Modo simulación"),
/// APAGADO por defecto. Así en la build de release (Play / TestFlight) los
/// testers usan GPS real y NO ven el joystick a menos que lo activen ellos.
/// Tú puedes encenderlo en tu móvil para probar todo el flujo de carrera.
///
/// Para quitarlo del todo antes del lanzamiento público: borra la carpeta
/// `lib/dev/`, la sección "Desarrollo" de Ajustes y los usos de
/// `kSimulateLocation` en run_provider.dart y run_screen.dart.
bool get kSimulateLocation => LocationSimulator.enabled;

class LocationSimulator {
  LocationSimulator._();
  static final LocationSimulator instance = LocationSimulator._();

  // ── Interruptor persistente (Ajustes → Modo simulación) ───────────────────
  static const String _prefKey = 'sim_mode_enabled';
  static bool enabled = false;

  /// Carga el estado guardado. Llamar en main() antes de runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  final _controller = StreamController<Position>.broadcast();
  Stream<Position> get positions => _controller.stream;

  // Posición actual simulada (por defecto, centro de Madrid).
  double lat = 40.4168;
  double lng = -3.7038;

  // Vector del joystick (-1..1); (0,0) = parado. vy negativo = norte.
  double _vx = 0;
  double _vy = 0;
  Timer? _timer;

  static const Duration _tick = Duration(milliseconds: 400);
  // Velocidad a deflexión máxima del joystick: ~15 km/h (ritmo de correr, dentro
  // del rango válido del anti-trampas [2, 20] km/h).
  static const double _maxSpeedMps = 4.2;

  double get _magnitude => sqrt(_vx * _vx + _vy * _vy).clamp(0.0, 1.0);

  Position get _position => Position(
        longitude: lng,
        latitude: lat,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: _maxSpeedMps * _magnitude,
        speedAccuracy: 0,
      );

  /// Reinicia la posición al punto dado (o mantiene la actual si es null) y
  /// emite una primera lectura para que la ruta arranque.
  void begin({double? startLat, double? startLng}) {
    if (startLat != null && startLng != null) {
      lat = startLat;
      lng = startLng;
    }
    _vx = 0;
    _vy = 0;
    _controller.add(_position);
  }

  /// Actualiza la dirección desde el joystick.
  void setVector(double vx, double vy) {
    _vx = vx;
    _vy = vy;
    if (_magnitude > 0.02) {
      _timer ??= Timer.periodic(_tick, (_) => _step());
    }
  }

  void _step() {
    final mag = _magnitude;
    if (mag < 0.02) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final meters = _maxSpeedMps * mag * (_tick.inMilliseconds / 1000.0);
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * cos(lat * pi / 180);
    lat += (-_vy) * meters / metersPerDegLat; // arriba = norte
    lng += (_vx) * meters / metersPerDegLng; // derecha = este
    _controller.add(_position);
  }

  void stop() {
    _vx = 0;
    _vy = 0;
    _timer?.cancel();
    _timer = null;
  }
}
