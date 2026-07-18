import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../social/follow_providers.dart';
import '../social/social_providers.dart';
import '../widgets/avatar_marker.dart';

/// Lista de seguidores y seguidos de un corredor (estilo Instagram).
class FollowListScreen extends StatelessWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    this.showFollowingFirst = false,
  });

  final String userId;
  final bool showFollowingFirst;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: showFollowingFirst ? 1 : 0,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Comunidad'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Seguidores'),
              Tab(text: 'Siguiendo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RunnerIdList(provider: followersProvider(userId), emptyText: 'Todavía no tiene seguidores.'),
            _RunnerIdList(provider: followingProvider(userId), emptyText: 'Todavía no sigue a nadie.'),
          ],
        ),
      ),
    );
  }
}

class _RunnerIdList extends ConsumerWidget {
  const _RunnerIdList({required this.provider, required this.emptyText});

  final ProviderListenable<AsyncValue<List<String>>> provider;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(provider);
    return ids.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, __) => Center(
        child: Text('No se pudo cargar la lista.',
            style: AppTextStyles.caption),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text(emptyText, style: AppTextStyles.caption));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (_, i) => RunnerTile(uid: list[i]),
        );
      },
    );
  }
}

/// Fila de corredor (avatar + nombre) que abre su perfil al tocarla.
class RunnerTile extends ConsumerWidget {
  const RunnerTile({super.key, required this.uid, this.trailing});

  final String uid;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userModelProvider(uid)).valueOrNull;
    final name = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName.trim()
        : 'Corredor';
    final photo = user?.photoUrl?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;

    return ListTile(
      onTap: () => context.push('${AppRoutes.runner}/$uid'),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surfaceAlt,
        backgroundImage: hasPhoto ? NetworkImage(photo) : null,
        child: hasPhoto ? null : Text(initialsOf(name)),
      ),
      title: Text(name, style: AppTextStyles.bodyLarge),
      subtitle: user == null
          ? null
          : Text('Nivel ${user.level}', style: AppTextStyles.caption),
      trailing: trailing,
    );
  }
}

/// Solicitudes de seguimiento pendientes del usuario actual (cuenta privada).
class FollowRequestsScreen extends ConsumerWidget {
  const FollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myPendingRequestsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Solicitudes')),
      body: requests.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, __) => Center(
          child: Text('No se pudieron cargar las solicitudes.',
              style: AppTextStyles.caption),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('No tienes solicitudes pendientes.',
                  style: AppTextStyles.caption),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => RunnerTile(
              uid: list[i],
              trailing: _RequestActions(followerId: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _RequestActions extends ConsumerStatefulWidget {
  const _RequestActions({required this.followerId});
  final String followerId;

  @override
  ConsumerState<_RequestActions> createState() => _RequestActionsState();
}

class _RequestActionsState extends ConsumerState<_RequestActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final controller = ref.read(followControllerProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => _run(() => controller.approve(widget.followerId)),
          child: const Text('Aceptar'),
        ),
        IconButton(
          onPressed: () => _run(() => controller.reject(widget.followerId)),
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          tooltip: 'Rechazar',
        ),
      ],
    );
  }
}
