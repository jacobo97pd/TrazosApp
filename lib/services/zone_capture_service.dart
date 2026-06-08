import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/zone_model.dart';
import '../core/constants.dart';

enum ZoneCaptureResult {
  success,
  insufficientDistance,
  noPolygon,
  noZoneInArea,
  centroidNotInPolygon,
  insufficientOverlap,
  serverError,
  zoneNotFound,
  invalidPolygon,
}

// Razones devueltas por la Cloud Function → enum local
const _reasonMap = {
  'min_points':           ZoneCaptureResult.insufficientDistance,
  'insufficient_distance': ZoneCaptureResult.insufficientDistance,
  'invalid_polygon':      ZoneCaptureResult.invalidPolygon,
  'centroid_not_inside':  ZoneCaptureResult.centroidNotInPolygon,
  'no_overlap':           ZoneCaptureResult.insufficientOverlap,
  'insufficient_overlap': ZoneCaptureResult.insufficientOverlap,
  'zone_not_found':       ZoneCaptureResult.zoneNotFound,
};

class ZoneCaptureService {
  ZoneCaptureService();

  // Toda la validación ocurre en la Cloud Function; el cliente solo envía datos.
  Future<ZoneCaptureResult> attemptCapture({
    required List<LatLng> runnerPolygon,
    required ZoneModel zone,
  }) async {
    if (runnerPolygon.length < AppConstants.minPolygonPoints) {
      return ZoneCaptureResult.insufficientDistance;
    }

    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('validateCapture');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'zoneId': zone.id,
        'polygonCoords': runnerPolygon
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      });

      final data = result.data;
      if (data['success'] == true) return ZoneCaptureResult.success;

      final reason = data['reason'] as String? ?? '';
      return _reasonMap[reason] ?? ZoneCaptureResult.serverError;
    } on FirebaseFunctionsException {
      // UNAUTHENTICATED, INVALID_ARGUMENT, etc.
      return ZoneCaptureResult.serverError;
    } catch (_) {
      return ZoneCaptureResult.serverError;
    }
  }

  // Mensaje legible para el usuario según resultado
  static String messageFor(ZoneCaptureResult result) => switch (result) {
    ZoneCaptureResult.success               => '¡Zona capturada!',
    ZoneCaptureResult.insufficientDistance  => 'Debes correr al menos 500 m.',
    ZoneCaptureResult.noPolygon             => 'Cierra el cerco primero.',
    ZoneCaptureResult.noZoneInArea          => 'Tu cerco no rodea ninguna zona.',
    ZoneCaptureResult.centroidNotInPolygon  => 'Tu ruta no cubre el centro de la zona.',
    ZoneCaptureResult.insufficientOverlap   => 'Debes cubrir al menos el 60 % de la zona.',
    ZoneCaptureResult.zoneNotFound          => 'Zona no encontrada.',
    ZoneCaptureResult.invalidPolygon        => 'Polígono inválido. Vuelve a trazar la ruta.',
    ZoneCaptureResult.serverError           => 'Error del servidor. Inténtalo de nuevo.',
  };
}

final zoneCaptureServiceProvider = Provider<ZoneCaptureService>(
  (ref) => ZoneCaptureService(),
);
