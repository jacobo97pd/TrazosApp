import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../core/constants.dart';
import '../providers/run_provider.dart';
import '../providers/zones_provider.dart';
import '../services/zone_capture_service.dart';
import '../widgets/adaptive_map.dart';

class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  final _mapController = AdaptiveMapController();
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(runProvider.notifier).startRun();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(runProvider.notifier).stopRun();
    if (!mounted) return;
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    final run      = ref.watch(runProvider);
    final polygons = ref.watch(mapPolygonsProvider);

    // Seguir al usuario en el mapa
    ref.listen(runProvider.select((s) => s.currentPosition), (_, pos) {
      if (pos != null) {
        _mapController.animateTo(MapPoint(pos.latitude, pos.longitude));
      }
    });

    // Confeti al capturar con éxito
    ref.listen(runProvider.select((s) => s.captureResult), (_, result) {
      if (result == ZoneCaptureResult.success) _confetti.play();
    });

    final lines = [
      if (run.route.length > 1)
        MapLineData(
          id: 'route',
          points: [
            for (final p in run.route) MapPoint(p.latitude, p.longitude),
          ],
          color: run.isPolygonClosed ? AppColors.green : AppColors.accent,
          width: 5,
        ),
    ];

    final markers = [
      if (run.route.isNotEmpty)
        MapMarkerData(
          id: 'start',
          point: MapPoint(run.route.first.latitude, run.route.first.longitude),
          kind: MapMarkerKind.start,
        ),
    ];

    final start = run.currentPosition;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Mapa (NO interactivo; la cámara sigue al corredor por código) ──
          IgnorePointer(
            child: AdaptiveMap(
              controller: _mapController,
              initialTarget: start != null
                  ? MapPoint(start.latitude, start.longitude)
                  : const MapPoint(40.4168, -3.7038),
              initialZoom: 16.5,
              myLocationEnabled: true,
              lines: lines,
              polygons: polygons,
              markers: markers,
              gesturesEnabled: false,
            ),
          ),

          // ── Confetti ───────────────────────────────────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppColors.accent, AppColors.cyan, AppColors.green, AppColors.gold,
              ],
              numberOfParticles: 60,
            ),
          ),

          // ── HUD superior ───────────────────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: _RunHud(run: run)),

          // ── Zona inferior ──────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: run.captureResult != null
                ? _ResultCard(
                    result:   run.captureResult!,
                    zoneName: run.capturedZoneName,
                    onFinish: _finish,
                  )
                : _RunBottom(
                    run: run,
                    onPause: () {
                      final n = ref.read(runProvider.notifier);
                      run.isPaused ? n.resumeRun() : n.pauseRun();
                    },
                    onStop: _finish,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── HUD con stats ─────────────────────────────────────────────────────────────
class _RunHud extends StatelessWidget {
  const _RunHud({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.95),
            AppColors.background.withValues(alpha: 0),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _HudStat(label: 'TIEMPO', value: run.formattedDuration),
          _HudDivider(),
          _HudStat(label: 'KM',     value: run.distanceKm.toStringAsFixed(2)),
          _HudDivider(),
          _HudStat(label: 'RITMO',  value: run.formattedPace),
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.statNumber),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.statLabel),
      ],
    );
  }
}

class _HudDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 40, child: VerticalDivider(color: AppColors.border));
}

// ── Controles inferiores (corriendo) ──────────────────────────────────────────
class _RunBottom extends StatelessWidget {
  const _RunBottom({required this.run, required this.onPause, required this.onStop});
  final RunState run;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.97),
            AppColors.background.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusHint(run: run),
          const SizedBox(height: 16),
          Row(
            children: [
              _CircleBtn(
                icon:  run.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: AppColors.surfaceAlt,
                onTap: onPause,
              ),
              const SizedBox(width: 12),
              // Parar / finalizar (ocupa el resto)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStop,
                  icon:  const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Finalizar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Pista de estado: progreso a la distancia mínima o "vuelve al inicio".
class _StatusHint extends StatelessWidget {
  const _StatusHint({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    if (!run.reachedMinDistance) {
      final progress = (run.distanceMeters /
              AppConstants.minRunDistanceMeters)
          .clamp(0.0, 1.0);
      return _ProgressBar(
        progress: progress,
        label: '${run.distanceMeters.toInt()} / '
            '${AppConstants.minRunDistanceMeters.toInt()} m mínimos',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flag_circle_rounded, color: AppColors.green, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Vuelve al punto de inicio para cerrar el cerco '
              '(${run.distanceToStartMeters.toInt()} m)',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de resultado (cerco cerrado) ──────────────────────────────────────
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.zoneName,
    required this.onFinish,
  });
  final ZoneCaptureResult result;
  final String? zoneName;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final success = result == ZoneCaptureResult.success;
    final color   = success ? AppColors.green : AppColors.gold;
    final title   = success
        ? '¡Zona ${zoneName ?? ''} capturada!'
        : 'Cerco cerrado';
    final message = success
        ? 'Has conquistado este territorio. ¡Defiéndelo!'
        : ZoneCaptureService.messageFor(result);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 28, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(success ? Icons.emoji_events_rounded : Icons.info_rounded,
              color: color, size: 48),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? AppColors.green : AppColors.accent,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Volver al mapa'),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        color,
      shape:        const CircleBorder(),
      child: InkWell(
        onTap:        onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.label});
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           progress,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight:  6,
          ),
        ),
      ],
    );
  }
}
