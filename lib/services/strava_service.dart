import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../models/run_model.dart';

// ── Claves SecureStorage ──────────────────────────────────────────────────────
const _kAccessToken  = 'strava_access_token';
const _kRefreshToken = 'strava_refresh_token';
const _kExpiresAt    = 'strava_expires_at'; // Unix timestamp en segundos

// ── DTO interno ───────────────────────────────────────────────────────────────
class StravaTokenData {
  const StravaTokenData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.athleteId,
    required this.athleteName,
  });

  final String accessToken;
  final String refreshToken;
  final int    expiresAt;     // Unix timestamp (segundos)
  final String athleteId;
  final String athleteName;
}

// ── Servicio principal ────────────────────────────────────────────────────────
class StravaService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final _appLinks   = AppLinks();
  final _functions  = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final _httpClient = http.Client();

  // ── 1. connectStrava ─────────────────────────────────────────────────────────
  //
  // Flujo:
  //   1. Suscribirse al stream de deep-links ANTES de abrir el navegador
  //   2. Abrir la URL OAuth de Strava en el navegador externo
  //   3. Esperar el callback runrace://strava-callback?code=XXX (5 min timeout)
  //   4. Llamar a la Cloud Function exchangeStravaToken con el code
  //   5. Guardar tokens en SecureStorage + stravaId en Firestore
  //   6. Devolver StravaTokenData o null si el usuario canceló

  Future<StravaTokenData?> connectStrava() async {
    final code = await _awaitCodeMobile();
    if (code == null) return null;
    return _exchangeCode(code);
  }

  bool _isStravaCallback(Uri uri) =>
      uri.scheme == AppConstants.appScheme && uri.host == 'strava-callback';

  // ── "Iniciar sesión con Strava" ──────────────────────────────────────────────
  //
  // Móvil: abre Strava, espera el code via deep-link y completa el login
  //        (devuelve true si la sesión se inició).
  // Web:   redirige la pestaña a Strava. El login se completa al volver, en
  //        completeWebStravaLoginIfPending() (devuelve false: la página se va).

  static const String _kStravaLoginState = 'strava_login';

  // El code del callback web, capturado en main() ANTES de que go_router
  // normalice la URL y borre el "?code=" (estrategia hash de Flutter web).
  static String? _pendingWebCode;

  static void captureWebStravaCallback() {
    if (!kIsWeb) return;
    final p = Uri.base.queryParameters;
    if (p['state'] == _kStravaLoginState && (p['code']?.isNotEmpty ?? false)) {
      _pendingWebCode = p['code'];
    }
  }

  Future<bool> signInWithStrava() async {
    if (kIsWeb) {
      final uri = _authorizeUri(
        redirectUri: Uri.base.origin,
        state: _kStravaLoginState,
      );
      // Navega en la MISMA pestaña; Strava redirige de vuelta a origin?code=…
      await launchUrl(uri, webOnlyWindowName: '_self');
      return false;
    }

    final code = await _awaitCodeMobile();
    if (code == null) return false;
    await _completeStravaLogin(code);
    return true;
  }

  // True si venimos del redirect OAuth de Strava en web y aún no hay sesión.
  bool get hasPendingWebStravaLogin =>
      kIsWeb &&
      _pendingWebCode != null &&
      FirebaseAuth.instance.currentUser == null;

  // Al arrancar en web: si capturamos un code de Strava y no hay sesión,
  // completa el login. Devuelve true si inició sesión.
  Future<bool> completeWebStravaLoginIfPending() async {
    if (!kIsWeb) return false;
    if (FirebaseAuth.instance.currentUser != null) return false;

    final code = _pendingWebCode;
    if (code == null) return false;
    _pendingWebCode = null; // un solo uso

    try {
      await _completeStravaLogin(code);
      return true;
    } catch (_) {
      return false; // code caducado/reutilizado u otro error
    }
  }

  // Intercambia el code por un custom token de Firebase y abre sesión.
  Future<void> _completeStravaLogin(String code) async {
    final result = await _functions
        .httpsCallable('loginWithStrava')
        .call<Map<String, dynamic>>({'code': code});

    final data = result.data;
    await FirebaseAuth.instance
        .signInWithCustomToken(data['firebaseToken'] as String);

    // Guarda los tokens de Strava para subir carreras / refrescar más tarde.
    await _persistTokens(StravaTokenData(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
      expiresAt:    (data['expiresAt']   as num).toInt(),
      athleteId:    data['athleteId']    as String,
      athleteName:  data['athleteName']  as String? ?? '',
    ));
  }

  // Construye la URL de autorización de Strava.
  Uri _authorizeUri({required String redirectUri, String? state}) => Uri.parse(
        'https://www.strava.com/oauth/authorize'
        '?client_id=${AppConstants.stravaClientId}'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&response_type=code'
        '&approval_prompt=auto'
        '&scope=${AppConstants.stravaScope}'
        '${state != null ? '&state=$state' : ''}',
      );

  // Móvil: abre Strava y espera el code que llega por deep-link runrace://…
  Future<String?> _awaitCodeMobile() async {
    final oauthUri = _authorizeUri(redirectUri: AppConstants.stravaRedirectUri);

    // Suscribirse al stream antes de abrir el navegador para no perder el callback
    final completer = Completer<String?>();
    StreamSubscription<Uri>? sub;

    sub = _appLinks.uriLinkStream.listen((uri) {
      if (_isStravaCallback(uri) && !completer.isCompleted) {
        completer.complete(uri.queryParameters['code']);
        sub?.cancel();
      }
    });

    // Si la app fue matada por el OS y relanzada via deep-link
    unawaited(
      _appLinks.getInitialLink().then((initialUri) {
        if (initialUri != null &&
            _isStravaCallback(initialUri) &&
            !completer.isCompleted) {
          completer.complete(initialUri.queryParameters['code']);
          sub?.cancel();
        }
      }),
    );

    if (!await launchUrl(oauthUri, mode: LaunchMode.externalApplication)) {
      await sub.cancel();
      throw Exception('No se pudo abrir el navegador para Strava.');
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        sub?.cancel();
        return null;
      },
    );
  }

  // ── Intercambio de code por tokens (via Cloud Function) ──────────────────────
  Future<StravaTokenData> _exchangeCode(String code) async {
    final result = await _functions
        .httpsCallable('exchangeStravaToken')
        .call<Map<String, dynamic>>({'code': code});

    final data = result.data;
    final tokenData = StravaTokenData(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
      expiresAt:    (data['expiresAt']   as num).toInt(),
      athleteId:    data['athleteId']    as String,
      athleteName:  data['athleteName']  as String? ?? '',
    );

    await _persistTokens(tokenData);
    return tokenData;
  }

  Future<void> _persistTokens(StravaTokenData tokens) async {
    await Future.wait([
      _storage.write(key: _kAccessToken,  value: tokens.accessToken),
      _storage.write(key: _kRefreshToken, value: tokens.refreshToken),
      _storage.write(key: _kExpiresAt,    value: tokens.expiresAt.toString()),
    ]);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'stravaId':        tokens.athleteId,
      'stravaConnected': true,
    });
  }

  // ── Desconectar Strava ───────────────────────────────────────────────────────
  Future<void> disconnectStrava() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kExpiresAt),
    ]);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'stravaId':        null,
      'stravaToken':     null,
      'stravaConnected': false,
      'stravaImported':  false,
    });
  }

  // ── Estado de conexión ───────────────────────────────────────────────────────
  Future<bool> get isConnected async =>
      (await _storage.read(key: _kAccessToken)) != null;

  // ── Gestión de tokens ────────────────────────────────────────────────────────
  //
  // Devuelve un access_token válido, refrescando via Cloud Function si expira
  // en menos de 5 minutos. Devuelve null si no hay sesión activa.

  Future<String?> _validAccessToken() async {
    final accessToken  = await _storage.read(key: _kAccessToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);
    final expiresAtStr = await _storage.read(key: _kExpiresAt);

    if (accessToken == null || refreshToken == null || expiresAtStr == null) {
      return null;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      int.parse(expiresAtStr) * 1000,
    );

    // Refrescar si expira en menos de 5 min (buffer de seguridad)
    if (expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      return _refreshToken(refreshToken);
    }

    return accessToken;
  }

  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final result = await _functions
          .httpsCallable('refreshStravaToken')
          .call<Map<String, dynamic>>({'refreshToken': refreshToken});

      final data       = result.data;
      final newToken   = data['accessToken'] as String;
      final expiresAt  = (data['expiresAt']  as num).toInt();

      await Future.wait([
        _storage.write(key: _kAccessToken, value: newToken),
        _storage.write(key: _kExpiresAt,   value: expiresAt.toString()),
      ]);

      return newToken;
    } on FirebaseFunctionsException {
      // Token de refresco inválido — limpiar sesión
      await Future.wait([
        _storage.delete(key: _kAccessToken),
        _storage.delete(key: _kRefreshToken),
        _storage.delete(key: _kExpiresAt),
      ]);
      return null;
    }
  }

  // ── 2. uploadRunToStrava ─────────────────────────────────────────────────────
  //
  // Construye el payload de actividad y lo sube directamente a la API de Strava.
  // El access_token se obtiene de SecureStorage (+ refresco automático si expira).
  // Guarda el stravaActivityId resultante en runs/{runId}.
  //
  // Errores manejados:
  //   401 → sesión caducada (se limpia SecureStorage)
  //   429 → rate limit de Strava
  //   timeout → red caída

  Future<String?> uploadRunToStrava(RunModel run) async {
    final token = await _validAccessToken();
    if (token == null) return null;

    final zoneName = run.capturedZoneId != null
        ? '¡Zona capturada! ${run.distanceKm.toStringAsFixed(2)} km'
        : 'Carrera RunRace ${run.distanceKm.toStringAsFixed(2)} km';

    final body = jsonEncode({
      'name':             zoneName,
      'type':             'Run',
      'sport_type':       'Run',
      'start_date_local': run.startedAt.toUtc().toIso8601String(),
      'elapsed_time':     run.duration,
      'description':      'RunRace · ${run.distanceKm.toStringAsFixed(2)} km '
                          '· Ritmo ${run.formattedDuration} '
                          '${run.capturedZoneId != null ? '· Zona capturada 🏁' : ''}',
      'distance':         run.distance,
      'trainer':          0,
      'commute':          0,
    });

    http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse('https://www.strava.com/api/v3/activities'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type':  'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado. Comprueba tu conexión.');
    }

    switch (response.statusCode) {
      case 201:
        final data             = jsonDecode(response.body) as Map<String, dynamic>;
        final stravaActivityId = data['id']?.toString();
        if (stravaActivityId != null && run.id.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('runs')
              .doc(run.id)
              .update({'stravaActivityId': stravaActivityId});
        }
        return stravaActivityId;

      case 401:
        // Token inválido — limpiar SecureStorage para forzar reconexión
        await Future.wait([
          _storage.delete(key: _kAccessToken),
          _storage.delete(key: _kRefreshToken),
          _storage.delete(key: _kExpiresAt),
        ]);
        throw Exception('Sesión de Strava caducada. Vuelve a conectar en tu perfil.');

      case 429:
        throw Exception('Límite de peticiones de Strava alcanzado. Inténtalo en unos minutos.');

      default:
        return null;
    }
  }

  // ── 3. importStravaHistory ───────────────────────────────────────────────────
  //
  // Pagina GET /api/v3/athlete/activities (máx 200 por página) y suma la
  // distancia de todas las actividades de tipo Run.
  // Solo se ejecuta una vez gracias al flag stravaImported en Firestore.
  // Devuelve el total de km importados (0 si ya se importó antes).

  Future<double> importStravaHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (userDoc.data()?['stravaImported'] == true) return 0;

    final token = await _validAccessToken();
    if (token == null) return 0;

    double totalMeters = 0;
    int    page        = 1;
    const  perPage     = 200;

    while (true) {
      http.Response response;
      try {
        response = await _httpClient
            .get(
              Uri.parse(
                'https://www.strava.com/api/v3/athlete/activities'
                '?per_page=$perPage&page=$page',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        break;
      }

      if (response.statusCode != 200) break;

      final activities = jsonDecode(response.body) as List<dynamic>;
      if (activities.isEmpty) break;

      for (final activity in activities) {
        final type = activity['type'] as String? ?? '';
        if (type == 'Run' || type == 'TrailRun' || type == 'VirtualRun') {
          totalMeters += (activity['distance'] as num?)?.toDouble() ?? 0;
        }
      }

      if (activities.length < perPage) break; // última página
      page++;
    }

    final totalKm = totalMeters / 1000;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'totalKm':        totalKm,
      'stravaImported': true,
    });

    return totalKm;
  }

  void dispose() => _httpClient.close();
}

final stravaServiceProvider = Provider<StravaService>((ref) {
  final service = StravaService();
  ref.onDispose(service.dispose);
  return service;
});

// Pequeño helper para no importar `dart:async` en callers
void unawaited(Future<void> future) => future.ignore();
