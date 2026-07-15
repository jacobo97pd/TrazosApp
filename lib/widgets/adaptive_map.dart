import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as amap;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;

/// En iOS usamos Apple Maps (MapKit nativo): no necesita API key, ni billing,
/// ni configuración en Google Cloud. En Android y web seguimos con Google Maps.
/// Así el mapa siempre se ve en iPhone aunque la key de Google no esté
/// habilitada para "Maps SDK for iOS".
bool get useAppleMaps =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

// ── Tipos neutrales (no atan el resto de la app a un paquete de mapas) ────────

@immutable
class MapPoint {
  const MapPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class MapPolygonData {
  const MapPolygonData({
    required this.id,
    required this.points,
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 2,
    this.holes = const [],
  });
  final String id;
  final List<MapPoint> points;
  final Color fillColor;
  final Color strokeColor;
  final int strokeWidth;

  /// Anillos interiores (agujeros). Solo se pintan en Google Maps; Apple Maps
  /// no los soporta y se ignoran (se ve el contorno exterior relleno).
  final List<List<MapPoint>> holes;
}

class MapLineData {
  const MapLineData({
    required this.id,
    required this.points,
    required this.color,
    this.width = 5,
  });
  final String id;
  final List<MapPoint> points;
  final Color color;
  final int width;
}

enum MapMarkerKind { start, custom }

class MapMarkerData {
  const MapMarkerData({
    required this.id,
    required this.point,
    this.kind = MapMarkerKind.custom,
    this.iconBytes,
  });
  final String id;
  final MapPoint point;
  final MapMarkerKind kind;

  /// PNG del icono (p. ej. el puntero del corredor). Si es null se usa el pin
  /// por defecto (o verde para [MapMarkerKind.start]).
  final Uint8List? iconBytes;
}

/// Controla la cámara con independencia del backend de mapa.
class AdaptiveMapController {
  gmap.GoogleMapController? _google;
  amap.AppleMapController? _apple;

  void animateTo(MapPoint p) {
    _google?.animateCamera(
      gmap.CameraUpdate.newLatLng(gmap.LatLng(p.latitude, p.longitude)),
    );
    _apple?.animateCamera(
      amap.CameraUpdate.newLatLng(amap.LatLng(p.latitude, p.longitude)),
    );
  }

  void dispose() {
    _google?.dispose();
    _google = null;
    _apple = null;
  }
}

// ── Widget adaptativo ─────────────────────────────────────────────────────────

class AdaptiveMap extends StatelessWidget {
  const AdaptiveMap({
    super.key,
    required this.initialTarget,
    required this.initialZoom,
    this.polygons = const [],
    this.lines = const [],
    this.markers = const [],
    this.myLocationEnabled = false,
    this.gesturesEnabled = true,
    this.googleDarkStyle,
    this.controller,
  });

  final MapPoint initialTarget;
  final double initialZoom;
  final List<MapPolygonData> polygons;
  final List<MapLineData> lines;
  final List<MapMarkerData> markers;
  final bool myLocationEnabled;
  final bool gesturesEnabled;

  /// Estilo oscuro JSON (solo Google Maps). Apple Maps sigue el modo del sistema.
  final String? googleDarkStyle;

  /// Si se pasa, se rellena con el controlador real al crear el mapa.
  final AdaptiveMapController? controller;

  @override
  Widget build(BuildContext context) =>
      useAppleMaps ? _buildApple() : _buildGoogle();

  // ── Google Maps (Android / web) ─────────────────────────────────────────────
  Widget _buildGoogle() {
    return gmap.GoogleMap(
      initialCameraPosition: gmap.CameraPosition(
        target: gmap.LatLng(initialTarget.latitude, initialTarget.longitude),
        zoom: initialZoom,
      ),
      onMapCreated: (c) => controller?._google = c,
      style: googleDarkStyle,
      polygons: {
        for (final p in polygons)
          gmap.Polygon(
            polygonId: gmap.PolygonId(p.id),
            points: [
              for (final pt in p.points) gmap.LatLng(pt.latitude, pt.longitude),
            ],
            holes: [
              for (final hole in p.holes)
                [for (final pt in hole) gmap.LatLng(pt.latitude, pt.longitude)],
            ],
            fillColor: p.fillColor,
            strokeColor: p.strokeColor,
            strokeWidth: p.strokeWidth,
            zIndex: 2,
            consumeTapEvents: false,
          ),
      },
      polylines: {
        for (final l in lines)
          gmap.Polyline(
            polylineId: gmap.PolylineId(l.id),
            points: [
              for (final pt in l.points) gmap.LatLng(pt.latitude, pt.longitude),
            ],
            color: l.color,
            width: l.width,
            jointType: gmap.JointType.round,
            startCap: gmap.Cap.roundCap,
            endCap: gmap.Cap.roundCap,
          ),
      },
      markers: {
        for (final m in markers)
          gmap.Marker(
            markerId: gmap.MarkerId(m.id),
            position: gmap.LatLng(m.point.latitude, m.point.longitude),
            icon: m.iconBytes != null
                ? gmap.BitmapDescriptor.bytes(m.iconBytes!)
                : (m.kind == MapMarkerKind.start
                    ? gmap.BitmapDescriptor.defaultMarkerWithHue(
                        gmap.BitmapDescriptor.hueGreen)
                    : gmap.BitmapDescriptor.defaultMarker),
            anchor: const Offset(0.5, 0.5),
            flat: m.iconBytes != null,
          ),
      },
      myLocationEnabled: myLocationEnabled,
      gestureRecognizers: gesturesEnabled
          ? const {
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            }
          : const {},
      scrollGesturesEnabled: gesturesEnabled,
      zoomGesturesEnabled: gesturesEnabled,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      buildingsEnabled: false,
    );
  }

  // ── Apple Maps (iOS) ────────────────────────────────────────────────────────
  Widget _buildApple() {
    return amap.AppleMap(
      initialCameraPosition: amap.CameraPosition(
        target: amap.LatLng(initialTarget.latitude, initialTarget.longitude),
        zoom: initialZoom,
      ),
      onMapCreated: (c) => controller?._apple = c,
      polygons: {
        for (final p in polygons)
          amap.Polygon(
            polygonId: amap.PolygonId(p.id),
            points: [
              for (final pt in p.points) amap.LatLng(pt.latitude, pt.longitude),
            ],
            fillColor: p.fillColor,
            strokeColor: p.strokeColor,
            strokeWidth: p.strokeWidth,
            zIndex: 2,
          ),
      },
      polylines: {
        for (final l in lines)
          amap.Polyline(
            polylineId: amap.PolylineId(l.id),
            points: [
              for (final pt in l.points) amap.LatLng(pt.latitude, pt.longitude),
            ],
            color: l.color,
            width: l.width,
            jointType: amap.JointType.round,
            polylineCap: amap.Cap.roundCap,
          ),
      },
      annotations: {
        for (final m in markers)
          amap.Annotation(
            annotationId: amap.AnnotationId(m.id),
            position: amap.LatLng(m.point.latitude, m.point.longitude),
            icon: m.iconBytes != null
                ? amap.BitmapDescriptor.fromBytes(m.iconBytes!)
                : (m.kind == MapMarkerKind.start
                    ? amap.BitmapDescriptor.markerAnnotationWithHue(
                        amap.BitmapDescriptor.hueGreen)
                    : amap.BitmapDescriptor.defaultAnnotation),
            anchor: const Offset(0.5, 0.5),
          ),
      },
      myLocationEnabled: myLocationEnabled,
      scrollGesturesEnabled: gesturesEnabled,
      zoomGesturesEnabled: gesturesEnabled,
      pitchGesturesEnabled: false,
      rotateGesturesEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
    );
  }
}
