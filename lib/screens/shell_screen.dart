import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/router.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (icon: Icons.map_outlined,         activeIcon: Icons.map_rounded,         label: 'Mapa',    path: AppRoutes.map),
    (icon: Icons.campaign_outlined,    activeIcon: Icons.campaign_rounded,    label: 'Tablón',  path: AppRoutes.board),
    (icon: Icons.leaderboard_outlined, activeIcon: Icons.leaderboard_rounded, label: 'Ranking', path: AppRoutes.ranking),
    (icon: Icons.person_outline,       activeIcon: Icons.person_rounded,      label: 'Perfil',  path: AppRoutes.profile),
    (icon: Icons.groups_outlined,      activeIcon: Icons.groups_rounded,      label: 'Club',    path: AppRoutes.club),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    // Botón atrás de Android: desde cualquier pestaña que no sea Mapa, volvemos
    // a Mapa (en vez de cerrar la app). Solo desde Mapa el atrás sale de la app.
    return PopScope(
      canPop: idx == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.map);
      },
      child: _buildScaffold(context, idx),
    );
  }

  Widget _buildScaffold(BuildContext context, int idx) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          backgroundColor: AppColors.surface,
          indicatorColor:  AppColors.accent.withValues(alpha: 0.18),
          selectedIndex:   idx,
          onDestinationSelected: (i) => context.go(_tabs[i].path),
          destinations: _tabs.map((t) => NavigationDestination(
            icon:          Icon(t.icon,       color: AppColors.textSecondary),
            selectedIcon:  Icon(t.activeIcon, color: AppColors.accent),
            label:         t.label,
          )).toList(),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}
