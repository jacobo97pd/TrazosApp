import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';

class NotificationService {
  NotificationService._();

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Pedir permiso (iOS / Android 13+)
    await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Guardar token FCM en Firestore
    final token = await messaging.getToken();
    await _saveToken(token);

    // Actualizar token cuando rote
    messaging.onTokenRefresh.listen(_saveToken);

    // Manejar mensajes en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Abrir la pantalla correcta al tocar una notificación en background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Notificación inicial si la app estaba terminada
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
  }

  static Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // SnackBar in-app usando el contexto del navigator raíz
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notification.title ?? notification.body ?? 'Nueva notificación'),
        action: message.data.isNotEmpty
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => _navigateForData(message.data),
              )
            : null,
      ),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) =>
      _navigateForData(message.data);

  // Navega a la pantalla correcta según data['type'] de la notificación.
  static void _navigateForData(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (data['type']) {
      case 'zone_captured':
      case 'zone_expired':
      case 'zone_expiring':
        context.go(AppRoutes.map);
      case 'club_joined':
      case 'club_invite':
        context.go(AppRoutes.club);
      default:
        context.go(AppRoutes.home);
    }
  }
}
