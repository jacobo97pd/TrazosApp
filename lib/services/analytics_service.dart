import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Analytics de producto para las superficies sociales de conquistas.
///
/// La API es deliberadamente especifica: no acepta IDs, captions, nombres,
/// URLs, coordenadas ni mapas de parametros arbitrarios.
abstract interface class AnalyticsService {
  Future<void> logFeedView();

  Future<void> logDetailView({required bool ownPost});

  Future<void> logReaction({required String kind, required bool active});

  Future<void> logCommentCreated();

  Future<void> logReportSubmitted({required String reason});

  Future<void> logRunnerBlocked();

  Future<void> logMyConquestsView();
}

/// Ejecuta telemetria fuera del resultado funcional de la accion. Tambien
/// protege frente a implementaciones inyectadas que fallen sincronicamente.
void logAnalyticsBestEffort(Future<void> Function() event) {
  try {
    event().ignore();
  } catch (_) {
    // Analytics nunca puede convertir una mutacion correcta en un error de UI.
  }
}

/// Implementacion de produccion respaldada por Firebase Analytics.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  static const _reactionKinds = {'like', 'applause'};
  static const _reportReasons = {
    'spam',
    'harassment',
    'hate_speech',
    'violence',
    'sexual_content',
    'dangerous_activity',
    'privacy',
    'misinformation',
    'other',
  };

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // La telemetria nunca debe cambiar el resultado de una accion de usuario.
    }
  }

  @override
  Future<void> logFeedView() => _bestEffort(
        () => _analytics.logEvent(name: 'conquest_feed_view'),
      );

  @override
  Future<void> logDetailView({required bool ownPost}) => _bestEffort(
        () => _analytics.logEvent(
          name: 'conquest_detail_view',
          parameters: {'own_post': ownPost ? 1 : 0},
        ),
      );

  @override
  Future<void> logReaction({required String kind, required bool active}) =>
      _bestEffort(
        () => _analytics.logEvent(
          name: 'conquest_reaction_toggle',
          parameters: {
            'reaction_type': _reactionKinds.contains(kind) ? kind : 'unknown',
            'active': active ? 1 : 0,
          },
        ),
      );

  @override
  Future<void> logCommentCreated() => _bestEffort(
        () => _analytics.logEvent(name: 'conquest_comment_create'),
      );

  @override
  Future<void> logReportSubmitted({required String reason}) => _bestEffort(
        () => _analytics.logEvent(
          name: 'conquest_report_submit',
          parameters: {
            'reason': _reportReasons.contains(reason) ? reason : 'other',
          },
        ),
      );

  @override
  Future<void> logRunnerBlocked() => _bestEffort(
        () => _analytics.logEvent(name: 'runner_block'),
      );

  @override
  Future<void> logMyConquestsView() => _bestEffort(
        () => _analytics.logEvent(name: 'my_conquests_view'),
      );
}

/// Implementacion para tests, previews o builds donde no se quiera emitir.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logFeedView() => Future<void>.value();

  @override
  Future<void> logDetailView({required bool ownPost}) => Future<void>.value();

  @override
  Future<void> logReaction({required String kind, required bool active}) =>
      Future<void>.value();

  @override
  Future<void> logCommentCreated() => Future<void>.value();

  @override
  Future<void> logReportSubmitted({required String reason}) =>
      Future<void>.value();

  @override
  Future<void> logRunnerBlocked() => Future<void>.value();

  @override
  Future<void> logMyConquestsView() => Future<void>.value();
}

/// Punto unico de inyeccion. En tests se sustituye con
/// `analyticsServiceProvider.overrideWithValue(const NoopAnalyticsService())`.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (_) => FirebaseAnalyticsService(),
);
