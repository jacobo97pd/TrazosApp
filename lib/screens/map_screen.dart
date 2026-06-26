import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../data/mock_runners.dart';
import '../providers/zones_provider.dart';
import '../services/permissions_service.dart';

// Camara por defecto (Madrid) hasta tener la ubicacion del usuario.
const _defaultCameraPosition = CameraPosition(
  target: LatLng(40.4168, -3.7038),
  zoom: 14.5,
);

// Mientras existan rutas mock de demo, mantenemos la camara sobre Madrid centro
// para que los trazos se vean y no haya salto automatico a la ubicacion real.
const _showMockRoutes = true;

// Estilo del puntero de ubicación. `runner` = icono propio (se genera en código);
// `dot` = punto azul por defecto de Google. Cambia esta constante para alternar.
enum _Pointer { runner, dot }
const _Pointer _pointerStyle = _Pointer.runner;

/// Mapa limpio y no interactivo: muestra zonas, trazos y ubicacion.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  String? _darkMapStyle;
  CameraPosition? _initialCameraPosition;

  LatLng? _userLatLng;            // ubicación actual para el puntero
  BitmapDescriptor? _runnerIcon;  // icono propio del puntero
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _prepareMap();
    if (_pointerStyle == _Pointer.runner) _loadRunnerIcon();
    _startUserTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Sigue la ubicación del usuario para mover el puntero (ligero, filtro 8 m).
  Future<void> _startUserTracking() async {
    try {
      // Pide explícitamente ubicación + notificaciones (diálogos del sistema).
      await PermissionsService.requestCorePermissions();

      final permission = await Geolocator.checkPermission();
      final resolved = permission == LocationPermission.denied
          ? await Geolocator.requestPermission()
          : permission;
      if (resolved == LocationPermission.denied ||
          resolved == LocationPermission.deniedForever) {
        return;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() => _userLatLng = LatLng(last.latitude, last.longitude));
      }

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen((p) {
        if (mounted) {
          setState(() => _userLatLng = LatLng(p.latitude, p.longitude));
        }
      });
    } catch (_) {/* sin permiso/ubicación: sin puntero */}
  }

  Future<void> _loadRunnerIcon() async {
    final icon = await _bitmapFromIcon(Icons.directions_run_rounded);
    if (mounted) setState(() => _runnerIcon = icon);
  }

  // Genera un puntero circular con el icono (sin necesidad de assets externos).
  // Para usar una imagen propia (zapatilla, etc.), sustituye por
  // BitmapDescriptor.bytes con el PNG del asset.
  Future<BitmapDescriptor> _bitmapFromIcon(IconData icon) async {
    const double size = 120;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(center, size / 2,
        Paint()..color = AppColors.accent.withValues(alpha: 0.22));
    canvas.drawCircle(center, size / 2 * 0.6, Paint()..color = AppColors.accent);
    canvas.drawCircle(
        center,
        size / 2 * 0.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white);

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.42,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _prepareMap() async {
    final styleFuture = rootBundle.loadString('assets/map_style_dark.json');
    final cameraFuture =
        _showMockRoutes ? Future.value(_defaultCameraPosition) : _userCamera();

    final style = await styleFuture;
    final camera = await cameraFuture;
    if (!mounted) return;

    setState(() {
      _darkMapStyle = style;
      _initialCameraPosition = camera;
    });
  }

  Future<CameraPosition> _userCamera() async {
    try {
      final permission = await Geolocator.checkPermission();
      final resolvedPermission = permission == LocationPermission.denied
          ? await Geolocator.requestPermission()
          : permission;

      if (resolvedPermission == LocationPermission.denied ||
          resolvedPermission == LocationPermission.deniedForever) {
        return _defaultCameraPosition;
      }

      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 4),
      );
      return CameraPosition(
        target: LatLng(pos.latitude, pos.longitude),
        zoom: 15,
      );
    } catch (_) {
      return _defaultCameraPosition;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(mapPolygonsProvider);
    final mockPolylines = {
      if (_showMockRoutes)
        for (final runner in mockRunners)
          Polyline(
            polylineId: PolylineId('mock-route-${runner.id}'),
            points: runner.route,
            color: runner.color.withValues(alpha: 0.42),
            width: 3,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            zIndex: 0,
          ),
    };
    final mapReady = _darkMapStyle != null && _initialCameraPosition != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          mapReady
              ? GoogleMap(
                  initialCameraPosition: _initialCameraPosition!,
                  onMapCreated: _onMapCreated,
                  style: _darkMapStyle,
                  polygons: polygons,
                  polylines: mockPolylines,
                  markers: {
                    if (_pointerStyle == _Pointer.runner &&
                        _userLatLng != null &&
                        _runnerIcon != null)
                      Marker(
                        markerId: const MarkerId('me'),
                        position: _userLatLng!,
                        icon: _runnerIcon!,
                        anchor: const Offset(0.5, 0.5),
                        flat: true,
                        zIndexInt: 5,
                      ),
                  },
                  // Punto azul por defecto solo si el estilo es `dot`.
                  myLocationEnabled: _pointerStyle == _Pointer.dot,
                  // Mover + zoom habilitados; EagerGestureRecognizer garantiza
                  // que el mapa gane los gestos (también dentro de scrolls).
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  buildingsEnabled: false,
                )
              : const _DarkMapPlaceholder(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 20,
                  right: 20,
                  bottom: 22,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TRAZOS',
                      style: AppTextStyles.displayMedium.copyWith(
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Conquista las zonas, compite por ser el mejor',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.run),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Correr'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkMapPlaceholder extends StatelessWidget {
  const _DarkMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.background),
      child: SizedBox.expand(
        child: CustomPaint(painter: _MapGridPainter()),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = AppColors.surfaceAlt.withValues(alpha: 0.42)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.38)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (var x = -40.0; x < size.width + 80; x += 58) {
      canvas.drawLine(Offset(x, 0), Offset(x + 90, size.height), minorPaint);
    }
    for (var y = 32.0; y < size.height; y += 74) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), minorPaint);
    }
    canvas.drawLine(
      Offset(size.width * 0.18, 0),
      Offset(size.width * 0.74, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.48),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
