import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../conquest/conquest_interaction_providers.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../social/runner_connection.dart';
import '../social/social_providers.dart';

class BlockedRunnersScreen extends ConsumerStatefulWidget {
  const BlockedRunnersScreen({super.key, this.currentUserId});

  /// Permite aislar la pantalla en tests. En la app se obtiene desde Auth.
  final String? currentUserId;

  @override
  ConsumerState<BlockedRunnersScreen> createState() =>
      _BlockedRunnersScreenState();
}

class _BlockedRunnersScreenState extends ConsumerState<BlockedRunnersScreen> {
  final Set<String> _busyUserIds = {};

  Future<void> _confirmUnblock(String userId, String displayName) async {
    if (_busyUserIds.contains(userId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Desbloquear a $displayName?'),
        content: const Text(
          'Podréis volver a ver contenido público e interactuar. '
          'La conexión anterior no se restaurará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyUserIds.add(userId));
    try {
      await ref
          .read(conquestInteractionControllerProvider)
          .unblockRunner(userId);
      ref.invalidate(myConnectionsProvider);
      ref.invalidate(blockedRunnerIdsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName ha sido desbloqueado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo desbloquear al corredor.')),
      );
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUid = widget.currentUserId == null
        ? ref.watch(authStateProvider).valueOrNull?.uid
        : null;
    final currentUid = widget.currentUserId ?? authUid;
    final connections = ref.watch(myConnectionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Corredores bloqueados')),
      body: connections.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (_, __) => _LoadError(
          onRetry: () => ref.invalidate(myConnectionsProvider),
        ),
        data: (items) {
          if (currentUid == null) return const _EmptyBlockedRunners();
          final blockedIds = {
            for (final connection in items)
              if (connection.status == ConnectionStatus.blocked &&
                  connection.isBlockedBy(currentUid))
                connection.other(currentUid),
          }.toList(growable: false)
            ..sort();

          if (blockedIds.isEmpty) return const _EmptyBlockedRunners();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: blockedIds.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final userId = blockedIds[index];
              return _BlockedRunnerTile(
                userId: userId,
                busy: _busyUserIds.contains(userId),
                onUnblock: (displayName) =>
                    _confirmUnblock(userId, displayName),
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedRunnerTile extends ConsumerWidget {
  const _BlockedRunnerTile({
    required this.userId,
    required this.busy,
    required this.onUnblock,
  });

  final String userId;
  final bool busy;
  final ValueChanged<String> onUnblock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userModelProvider(userId)).valueOrNull;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Corredor';
    final photoUrl = user?.photoUrl?.trim();
    final initial = displayName[0].toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Semantics(
        image: true,
        label: 'Avatar de $displayName',
        excludeSemantics: true,
        child: CircleAvatar(
          backgroundColor: AppColors.surfaceAlt,
          foregroundImage: photoUrl == null || photoUrl.isEmpty
              ? null
              : NetworkImage(photoUrl),
          child: Text(initial, style: AppTextStyles.labelLarge),
        ),
      ),
      title: Text(displayName, style: AppTextStyles.bodyLarge),
      subtitle: const Text('No podéis ver ni interactuar con el contenido'),
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => onUnblock(displayName),
              child: const Text('Desbloquear'),
            ),
    );
  }
}

class _EmptyBlockedRunners extends StatelessWidget {
  const _EmptyBlockedRunners();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 52,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                'No has bloqueado a ningún corredor',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Aquí podrás revisar y retirar tus bloqueos.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudieron cargar los corredores bloqueados.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}
