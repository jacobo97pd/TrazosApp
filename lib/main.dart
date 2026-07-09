import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'dev/location_simulator.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'services/strava_service.dart';

// Manejador de mensajes FCM en background — debe ser top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // TODO: mostrar notificación local si la app está en background/terminada
  debugPrint('FCM background: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura el ?code= del callback OAuth de Strava (web) ANTES de que el router
  // normalice la URL y lo borre. Imprescindible para cerrar el login.
  StravaService.captureWebStravaCallback();

  // Orientación solo portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Barra de estado transparente sobre el mapa
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Estado del modo simulación (Ajustes → Modo simulación), apagado por defecto.
  await LocationSimulator.load();

  // El tracking en segundo plano lo gestiona geolocator con un foreground
  // service de localización (ver RunNotifier._locationSettings): el GPS sigue
  // registrando con la app en background o el móvil bloqueado.

  runApp(
    const ProviderScope(
      child: TrazosApp(),
    ),
  );
}

class TrazosApp extends ConsumerWidget {
  const TrazosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Inicializa notificaciones push al arrancar la app logueada
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null) {
        NotificationService.initialize();
      }
    });

    return MaterialApp.router(
      title: 'Trazos',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) {
        // Escala de texto fija — evita que ajustes de accesibilidad rompan el layout
        return MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
