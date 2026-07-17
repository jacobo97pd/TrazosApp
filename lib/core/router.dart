import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/map_screen.dart';
import '../screens/run_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/club_screen.dart';
import '../screens/board_screen.dart';
import '../screens/club_chat_screen.dart';
import '../screens/club_events_screen.dart';
import '../screens/create_event_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/runner_profile_screen.dart';
import '../screens/challenges_screen.dart';
import '../screens/shoes_screen.dart';
import '../screens/corredores_screen.dart';
import '../screens/my_conquests_screen.dart';
import '../screens/conquest_detail_screen.dart';

// Clave del navigator raíz — permite navegar desde fuera del árbol de widgets
// (p. ej. al tocar una notificación push en NotificationService).
final rootNavigatorKey = GlobalKey<NavigatorState>();

// Rutas nombradas
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const home = '/home/map';
  static const map = home;
  static const run = '/run';
  static const clubChat = '/club/chat';
  static const clubEvents = '/club/events';
  static const createEvent = '/club/events/new';
  static const settings = '/settings';
  static const runner = '/runner'; // + /:uid
  static const challenges = '/challenges';
  static const shoes = '/shoes';
  static const corredores = '/corredores';
  static const conquests = '/conquests';
  static const myConquests = '/conquests/mine';
  static const board = '/home/board';
  static const ranking = '/home/ranking';
  static const profile = '/home/profile';
  static const club = '/home/club';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      // El deep-link OAuth de Strava (runrace://…/strava-callback?code=…) lo
      // consume StravaService vía app_links; aquí solo evitamos que go_router
      // muestre "Ruta no encontrada" mandándolo al splash (que decide a dónde ir).
      if (state.uri.path.endsWith('strava-callback')) {
        return AppRoutes.splash;
      }

      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuthRoute = state.matchedLocation == AppRoutes.auth ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isOnAuthRoute) return AppRoutes.auth;
      if (isLoggedIn && state.matchedLocation == AppRoutes.auth) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.run,
        builder: (_, __) => const RunScreen(),
      ),
      GoRoute(
        path: AppRoutes.clubChat,
        builder: (_, __) => const ClubChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.clubEvents,
        builder: (_, __) => const ClubEventsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createEvent,
        builder: (_, __) => const CreateEventScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.runner}/:uid',
        builder: (_, state) =>
            RunnerProfileScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: AppRoutes.challenges,
        builder: (_, __) => const ChallengesScreen(),
      ),
      GoRoute(
        path: AppRoutes.shoes,
        builder: (_, __) => const ShoesScreen(),
      ),
      GoRoute(
        path: AppRoutes.corredores,
        builder: (_, __) => const CorredoresScreen(),
      ),
      GoRoute(
        path: AppRoutes.myConquests,
        builder: (_, __) => const MyConquestsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.conquests}/:postId',
        builder: (_, state) => ConquestDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.map,
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: AppRoutes.board,
            builder: (_, __) => const BoardScreen(),
          ),
          GoRoute(
            path: AppRoutes.ranking,
            builder: (_, __) => const RankingScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.club,
            builder: (_, __) => const ClubScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
    ),
  );
});
