import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants.dart';

enum ZoneCaptureResult {
  success,
  insufficientDistance,
  invalidSpeed,
  areaTooSmall,
  invalidPolygon,
  serverError,
}

// Razones devueltas por claimTerritory → enum local.
const _reasonMap = {
  'min_points':            ZoneCaptureResult.insufficientDistance,
  'insufficient_distance': ZoneCaptureResult.insufficientDistance,
  'invalid_polygon':       ZoneCaptureResult.invalidPolygon,
  'invalid_speed':         ZoneCaptureResult.invalidSpeed,
  'area_too_small':        ZoneCaptureResult.areaTooSmall,
};

class ZoneCaptureService {
  ZoneCaptureService();

  // Reclama como territorio propio el polígono cerrado de la carrera. Toda la
  // validación (y el recorte a otros) ocurre en la Cloud Function claimTerritory.
  Future<({ZoneCaptureResult result, int areaM2})> claim({
    required List<LatLng> polygon,
    required double distanceMeters,
    required int durationSeconds,
  }) async {
    if (polygon.length < AppConstants.minPolygonPoints) {
      return (result: ZoneCaptureResult.insufficientDistance, areaM2: 0);
    }

    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('validateCapture');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'polygonCoords': polygon
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'distanceMeters':  distanceMeters,
        'durationSeconds': durationSeconds,
      });

      final data = result.data;
      if (data['success'] == true) {
        return (
          result: ZoneCaptureResult.success,
          areaM2: (data['areaM2'] as num?)?.toInt() ?? 0,
        );
      }
      final reason = data['reason'] as String? ?? '';
      return (
        result: _reasonMap[reason] ?? ZoneCaptureResult.serverError,
        areaM2: 0,
      );
    } on FirebaseFunctionsException {
      return (result: ZoneCaptureResult.serverError, areaM2: 0);
    } catch (_) {
      return (result: ZoneCaptureResult.serverError, areaM2: 0);
    }
  }

  // Mensaje legible para el usuario según resultado.
  static String messageFor(ZoneCaptureResult result) => switch (result) {
        ZoneCaptureResult.success =>
          '¡Territorio conquistado!',
        ZoneCaptureResult.insufficientDistance =>
          'Debes correr al menos 500 m.',
        ZoneCaptureResult.invalidSpeed =>
          'Velocidad no válida. El recorrido debe hacerse corriendo (sin bici/coche).',
        ZoneCaptureResult.areaTooSmall =>
          'El área es muy pequeña. Haz un cerco más grande.',
        ZoneCaptureResult.invalidPolygon =>
          'Cerco inválido. Vuelve a trazar la ruta.',
        ZoneCaptureResult.serverError =>
          'Error del servidor. Inténtalo de nuevo.',
      };
}

final zoneCaptureServiceProvider = Provider<ZoneCaptureService>(
  (ref) => ZoneCaptureService(),
);
