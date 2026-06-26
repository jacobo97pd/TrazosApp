import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:permission_handler/permission_handler.dart';

/// Pide de forma explícita los permisos que la app necesita en móvil:
/// ubicación (para trazar el recorrido) y notificaciones (avisos de zonas).
/// En web no aplica (los gestiona el navegador).
class PermissionsService {
  PermissionsService._();

  static bool _requested = false;

  /// Pide ubicación y notificaciones. Idempotente: si ya se concedieron/denegaron
  /// no vuelve a molestar. Best-effort: nunca lanza.
  static Future<void> requestCorePermissions() async {
    if (kIsWeb || _requested) return;
    _requested = true;
    try {
      // Se piden en secuencia (cada uno muestra su diálogo del sistema).
      await Permission.locationWhenInUse.request();
      await Permission.notification.request();
    } catch (e) {
      debugPrint('PermissionsService: $e');
    }
  }

  /// Ubicación "siempre" (background) — útil para seguir trazando con la app
  /// cerrada. En Android 11+ abre ajustes, así que se pide aparte y opcional.
  static Future<bool> requestBackgroundLocation() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.locationAlways.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
}
