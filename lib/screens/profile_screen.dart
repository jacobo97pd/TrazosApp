import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../progression/achievement_engine.dart';
import '../progression/progression_providers.dart';
import '../progression/runner_level_calculator.dart';
import '../progression/runner_progress.dart';
import '../progression/runner_star_calculator.dart';
import '../widgets/star_rating.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/strava_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () => context.push(AppRoutes.corredores),
            tooltip: 'Corredores',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Ajustes',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmSignOut(context, ref),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (user) => user != null
            ? _ProfileContent(user: user)
            : const Center(child: Text('Sin datos de usuario')),
      ),
    );
  }

  // Confirma antes de cerrar sesión para evitar toques accidentales.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            _ProfileAvatar(user: user),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: AppTextStyles.headlineLarge),
                  const SizedBox(height: 4),
                  Text(user.email,
                      style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  _LevelBadge(level: user.level),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _ProgressionSection(),
        const SizedBox(height: 20),

        // ── Stats ─────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _StatCard(
              label: 'ZONAS',
              value: '${user.capturedZones.length}',
              color: AppColors.accent,
              icon:  Icons.flag_rounded,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'KM TOTALES',
              value: user.totalKm.toStringAsFixed(0),
              color: AppColors.cyan,
              icon:  Icons.route_rounded,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'NIVEL',
              value: '${user.level}',
              color: AppColors.gold,
              icon:  Icons.star_rounded,
            )),
          ],
        ),
        const SizedBox(height: 24),

        // ── Strava ────────────────────────────────────────────────────────
        _StravaCard(user: user),
        const SizedBox(height: 16),

        // ── Historial de carreras TODO ─────────────────────────────────────
        Text('Carreras recientes', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        // TODO: StreamBuilder de runs/{runId} filtrado por userId
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text('Próximamente — historial de carreras',
                style: AppTextStyles.caption),
          ),
        ),
      ],
    );
  }
}

// Avatar tocable: muestra la foto (Strava o subida) con fallback a la inicial,
// y al tocarlo permite subir una imagen propia a Firebase Storage.
class _ProfileAvatar extends ConsumerStatefulWidget {
  const _ProfileAvatar({required this.user});
  final UserModel user;

  @override
  ConsumerState<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<_ProfileAvatar> {
  static const double _size = 72;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref('avatars/$uid/avatar.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': url});
      if (mounted) _snack('Foto de perfil actualizada.');
    } catch (e) {
      if (mounted) _snack('No se pudo subir la foto: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final url = widget.user.photoUrl;
    final initial = widget.user.displayName.isNotEmpty
        ? widget.user.displayName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _pickAndUpload,
      child: Stack(
        children: [
          Container(
            width: _size, height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: (url != null && url.isNotEmpty)
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    // En web, usa un <img> HTML si el fetch con CORS falla
                    // (Firebase Storage / Strava no envían cabeceras CORS).
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) => _initial(initial),
                  )
                : _initial(initial),
          ),

          // Indicador de subida
          if (_uploading)
            Container(
              width: _size, height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background.withValues(alpha: 0.6),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                ),
              ),
            ),

          // Badge de cámara
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String initial) => Center(
        child: Text(
          initial,
          style: AppTextStyles.displayMedium.copyWith(color: AppColors.accent),
        ),
      );
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.gradientGold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Nivel $level',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.background, fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.statNumber.copyWith(
              color: color, fontSize: 24)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.statLabel),
        ],
      ),
    );
  }
}

class _StravaCard extends ConsumerStatefulWidget {
  const _StravaCard({required this.user});
  final UserModel user;

  @override
  ConsumerState<_StravaCard> createState() => _StravaCardState();
}

class _StravaCardState extends ConsumerState<_StravaCard> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(stravaServiceProvider);
      final tokens  = await service.connectStrava();
      if (!mounted) return;
      if (tokens == null) {
        _snack('Conexión con Strava cancelada.');
      } else {
        _snack('Strava conectado como ${tokens.athleteName}.');
        // Importa el historial de km en segundo plano (idempotente)
        unawaited(service.importStravaHistory());
      }
    } catch (e) {
      if (mounted) _snack('No se pudo conectar con Strava: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await ref.read(stravaServiceProvider).disconnectStrava();
      if (mounted) _snack('Strava desconectado.');
    } catch (e) {
      if (mounted) _snack('Error al desconectar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    const stravaOrange = Color(0xFFFC4C02);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isStravaConnected
              ? stravaOrange.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_run_rounded,
              color: user.isStravaConnected ? stravaOrange : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Strava', style: AppTextStyles.titleMedium),
                Text(
                  user.isStravaConnected
                      ? 'Conectado · ID ${user.stravaId}'
                      : 'Sin conectar',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: stravaOrange),
            )
          else
            TextButton(
              onPressed: user.isStravaConnected ? _disconnect : _connect,
              style: TextButton.styleFrom(
                foregroundColor:
                    user.isStravaConnected ? AppColors.textSecondary : stravaOrange,
              ),
              child: Text(user.isStravaConnected ? 'Desconectar' : 'Conectar'),
            ),
        ],
      ),
    );
  }
}

// ── Progresión (nivel, estrellas, XP, logros, acceso a Retos) ─────────────────
class _ProgressionSection extends ConsumerWidget {
  const _ProgressionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(runnerProgressProvider).valueOrNull ?? const RunnerProgress();
    final stats = ref.watch(runnerStatsProvider);
    const levelCalc = RunnerLevelCalculator();
    const starCalc = RunnerStarCalculator();
    final lvl = levelCalc.fromTotalXp(progress.totalXp);
    final star = starCalc.forLevel(lvl.level);

    final statuses = const AchievementEngine()
        .evaluate(stats, unlockedAt: progress.achievementUnlockDates);
    final unlocked = statuses.where((s) => s.unlocked).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Nivel ${lvl.level}', style: AppTextStyles.titleLarge),
              const SizedBox(width: 10),
              StarRating(stars: star.stars, size: 18),
              const Spacer(),
              Text(star.label, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: lvl.progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('${lvl.xpIntoLevel} / ${lvl.xpForLevel} XP',
              style: AppTextStyles.caption),
          const SizedBox(height: 14),
          // Logros (icono en oro si desbloqueado).
          Text('Logros · $unlocked/${statuses.length}',
              style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in statuses)
                Icon(s.achievement.icon,
                    size: 22,
                    color: s.unlocked
                        ? AppColors.gold
                        : AppColors.border),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.challenges),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Retos'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.shoes),
                  icon: const Icon(Icons.directions_walk_rounded, size: 18),
                  label: const Text('Zapatillas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
