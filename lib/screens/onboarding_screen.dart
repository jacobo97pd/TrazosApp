import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/router.dart';

class _OnboardPage {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
}

const _pages = [
  _OnboardPage(
    icon:        Icons.map_outlined,
    title:       'Conquista zonas',
    subtitle:    'Traza rutas y captura barrios enteros.\nCada zona que corres es tuya.',
    accentColor: AppColors.accent,
  ),
  _OnboardPage(
    icon:        Icons.groups_rounded,
    title:       'Crea tu RunClub',
    subtitle:    'Forma equipo, suma zonas y domina\nel ranking de tu ciudad.',
    accentColor: AppColors.cyan,
  ),
  _OnboardPage(
    icon:        Icons.emoji_events_rounded,
    title:       'Defiende tu territorio',
    subtitle:    'Si no corres en 7 días, cualquiera\npuede robarte la zona.',
    accentColor: AppColors.gold,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _current = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
    if (!mounted) return;
    context.go(AppRoutes.auth);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Saltar'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount:  _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _OnboardPageView(page: _pages[i]),
              ),
            ),
            // Indicador de puntos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
                width:  _current == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color:         _current == i
                      ? _pages[i].accentColor
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _current == _pages.length - 1
                  ? ElevatedButton(
                      onPressed: _finish,
                      child: const Text('Empezar a correr'),
                    )
                  : ElevatedButton(
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve:    Curves.easeInOut,
                      ),
                      child: const Text('Siguiente'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageView extends StatelessWidget {
  const _OnboardPageView({required this.page});
  final _OnboardPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color:        page.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: page.accentColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(page.icon, size: 60, color: page.accentColor),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
