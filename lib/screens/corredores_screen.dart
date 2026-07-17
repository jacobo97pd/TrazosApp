// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../social/runner_connection.dart';
import '../social/social_providers.dart';
import '../widgets/avatar_marker.dart';

class CorredoresScreen extends ConsumerWidget {
  const CorredoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final privacy = ref.watch(socialPrivacyProvider).valueOrNull;
    final conns = ref.watch(myConnectionsProvider).valueOrNull ?? const [];
    final suggestions = ref.watch(suggestionsProvider);

    final pending = conns
        .where((c) =>
            c.status == ConnectionStatus.pending && c.recipientUserId == myUid)
        .toList();
    final accepted =
        conns.where((c) => c.status == ConnectionStatus.accepted).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Corredores')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Descubrimiento (consentimiento explícito).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accent,
              value: privacy?.discoverable ?? false,
              onChanged: (myUid == null || privacy == null)
                  ? null
                  : (v) =>
                      ref.read(connectionControllerProvider).setDiscoverable(v),
              title: Text('Que otros me encuentren',
                  style: AppTextStyles.bodyLarge),
              subtitle: Text(
                'Aparece en el directorio para usuarios de Trazos con Strava.',
                style: AppTextStyles.caption,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (pending.isNotEmpty) ...[
            _Header('Solicitudes'),
            for (final c in pending)
              _RunnerTile(
                uid: c.requesterUserId,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _MiniBtn('Aceptar', AppColors.green,
                      () => _c(ref).accept(c.requesterUserId)),
                  const SizedBox(width: 6),
                  _MiniBtn('Ignorar', AppColors.textSecondary,
                      () => _c(ref).decline(c.requesterUserId)),
                ]),
              ),
            const SizedBox(height: 16),
          ],

          _Header('Conexiones'),
          if (accepted.isEmpty)
            _EmptyLine('Aún no tienes conexiones.')
          else
            for (final c in accepted)
              _RunnerTile(
                uid: c.other(myUid ?? ''),
                onTap: () =>
                    context.push('${AppRoutes.runner}/${c.other(myUid ?? '')}'),
                trailing: IconButton(
                  icon: const Icon(Icons.more_horiz,
                      color: AppColors.textSecondary),
                  onPressed: () => _menu(context, ref, c.other(myUid ?? '')),
                ),
              ),
          const SizedBox(height: 16),

          _Header('Sugerencias'),
          suggestions.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _EmptyLine('No se pudieron cargar.'),
            data: (list) {
              if (privacy?.discoverable != true) {
                return _EmptyLine(
                    'Activa el descubrimiento para ver sugerencias.');
              }
              if (list.isEmpty) return _EmptyLine('Sin sugerencias por ahora.');
              return Column(children: [
                for (final u in list)
                  _RunnerTile(
                    uid: u.uid,
                    user: u,
                    trailing: _MiniBtn(
                        'Añadir',
                        AppColors.accent,
                        () => _c(ref)
                            .request(u.uid, ConnectionSource.stravaMatch)),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  ConnectionController _c(WidgetRef ref) =>
      ref.read(connectionControllerProvider);

  void _menu(BuildContext context, WidgetRef ref, String other) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Eliminar conexión'),
            onTap: () {
              _c(ref).remove(other);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: AppColors.accent),
            title: const Text('Bloquear'),
            onTap: () {
              _c(ref).block(other);
              Navigator.pop(context);
            },
          ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
      );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: AppTextStyles.caption),
      );
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            foregroundColor: color, minimumSize: const Size(0, 32)),
        child: Text(label),
      );
}

class _RunnerTile extends ConsumerWidget {
  const _RunnerTile({
    required this.uid,
    this.user,
    this.trailing,
    this.onTap,
  });
  final String uid;
  final UserModel? user;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user ?? ref.watch(userModelProvider(uid)).valueOrNull;
    final name =
        u?.displayName.trim().isNotEmpty == true ? u!.displayName : 'Runner';
    final photo = u?.photoUrl?.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.surfaceAlt,
        backgroundImage:
            (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
        child: (photo == null || photo.isEmpty)
            ? Text(initialsOf(name), style: AppTextStyles.labelMedium)
            : null,
      ),
      title: Text(name, style: AppTextStyles.bodyLarge),
      trailing: trailing,
    );
  }
}
