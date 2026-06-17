import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/router.dart';
import '../services/strava_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5)),
    );
    _ctrl.forward();
    _navigate();
  }

  bool _connectingStrava = false;

  Future<void> _navigate() async {
    final strava = ref.read(stravaServiceProvider);

    // Web: si volvemos del redirect OAuth de Strava, completa el login mostrando
    // feedback (la función puede tardar por cold start; sin feedback el usuario
    // cree que está colgado y refresca, gastando el code de un solo uso).
    if (strava.hasPendingWebStravaLogin) {
      setState(() => _connectingStrava = true);
      await strava.completeWebStravaLoginIfPending();
      if (!mounted) return;
    } else {
      // Splash normal con su animación
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
    // currentUser refleja al instante el login con custom token de Strava
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    if (!mounted) return;
    if (isLoggedIn) {
      context.go(AppRoutes.map);
    } else if (_connectingStrava) {
      // El login de Strava falló (code caducado, error de red…)
      context.go(AppRoutes.auth);
    } else if (!onboardingDone) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.auth);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'TRAZOS',
                    style: GoogleFonts.cinzel(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Conquista la ciudad corriendo',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  if (_connectingStrava) ...[
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFFFC4C02)),
                    ),
                    const SizedBox(height: 12),
                    Text('Conectando con Strava…',
                        style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
