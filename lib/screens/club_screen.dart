import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../models/club_model.dart';
import '../providers/auth_provider.dart';

class ClubScreen extends ConsumerWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('RunClub')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (user) {
          if (user == null) return const SizedBox.shrink();
          return user.isInClub
              ? _ClubView(clubId: user.clubId!)
              : const _NoClubView();
        },
      ),
    );
  }
}

// ── Vista cuando el usuario YA tiene club ─────────────────────────────────────
class _ClubView extends ConsumerWidget {
  const _ClubView({required this.clubId});
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .withConverter<ClubModel>(
          fromFirestore: (s, _) => ClubModel.fromFirestore(s),
          toFirestore:   (m, _) => m.toFirestore(),
        )
        .snapshots();

    return StreamBuilder<DocumentSnapshot<ClubModel>>(
      stream: stream,
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final club = snap.data!.data();
        if (club == null) return const Center(child: Text('Club no encontrado'));

        final uid     = FirebaseAuth.instance.currentUser?.uid;
        final isAdmin = uid != null && uid == club.adminId;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header club
            Row(
              children: [
                _ClubAvatar(club: club, canEdit: isAdmin),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club.name, style: AppTextStyles.headlineLarge),
                      Text('${club.city} · ${club.memberCount} miembros',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Admin',
                        style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.gold, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats
            Row(children: [
              Expanded(child: _ClubStat(
                  label: 'ZONAS', value: '${club.totalZones}', color: AppColors.cyan)),
              const SizedBox(width: 12),
              Expanded(child: _ClubStat(
                  label: 'KM TOTALES', value: club.totalKm.toStringAsFixed(0), color: AppColors.green)),
            ]),
            const SizedBox(height: 24),

            // Código de invitación
            _InviteCodeCard(code: club.inviteCode),
            const SizedBox(height: 16),

            // Accesos: chat y eventos
            Row(
              children: [
                Expanded(
                  child: _ClubActionButton(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    color: AppColors.cyan,
                    onTap: () => context.push(AppRoutes.clubChat),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ClubActionButton(
                    icon: Icons.event_rounded,
                    label: 'Eventos',
                    color: AppColors.accent,
                    onTap: () => context.push(AppRoutes.clubEvents),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Abandonar club
            OutlinedButton.icon(
              onPressed: () => _confirmAndLeave(context, ref, club),
              icon:  const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Abandonar club'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'Eres el administrador. Si te vas, el club pasa al miembro más '
                'antiguo (o se elimina si eres el único).',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

// Avatar/logo del club. El admin puede tocarlo para subir un logo a Storage.
class _ClubAvatar extends ConsumerStatefulWidget {
  const _ClubAvatar({required this.club, required this.canEdit});
  final ClubModel club;
  final bool canEdit;

  @override
  ConsumerState<_ClubAvatar> createState() => _ClubAvatarState();
}

class _ClubAvatarState extends ConsumerState<_ClubAvatar> {
  static const double _size = 64;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (!widget.canEdit || _uploading) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref('club_logos/${widget.club.id}/logo.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.club.id)
          .update({'logoUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo del club actualizado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo subir el logo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.club.logoUrl;
    final name = widget.club.name;
    final initials =
        (name.length >= 2 ? name.substring(0, 2) : name).toUpperCase();

    return GestureDetector(
      onTap: widget.canEdit ? _pickAndUpload : null,
      child: Stack(
        children: [
          Container(
            width: _size, height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: (url != null && url.isNotEmpty)
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) => _initials(initials),
                  )
                : _initials(initials),
          ),
          if (_uploading)
            Container(
              width: _size, height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background.withValues(alpha: 0.6),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.cyan),
                ),
              ),
            ),
          if (widget.canEdit)
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.cyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 11, color: AppColors.background),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initials(String s) => Center(
        child: Text(s,
            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.cyan)),
      );
}

// Doble verificación antes de abandonar el club.
Future<void> _confirmAndLeave(
    BuildContext context, WidgetRef ref, ClubModel club) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final isAdmin = uid == club.adminId;

  final first = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Abandonar club'),
      content: Text(isAdmin
          ? 'Eres el administrador de ${club.name}. Si lo abandonas, el club '
              'pasará al miembro más antiguo (o se eliminará si eres el único). '
              '¿Continuar?'
          : '¿Seguro que quieres abandonar ${club.name}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(c, true),  child: const Text('Continuar')),
      ],
    ),
  );
  if (first != true || !context.mounted) return;

  final second = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Confirmar'),
      content: const Text('Esta acción no se puede deshacer. '
          '¿Confirmas que quieres salir del club?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          child: const Text('Sí, abandonar'),
        ),
      ],
    ),
  );
  if (second != true || !context.mounted) return;

  try {
    await _leaveClub(club, uid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Has abandonado el club.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al salir: $e'),
              backgroundColor: AppColors.accent));
    }
  }
}

// Si el admin se va, hereda el club el miembro más antiguo (primero en members);
// si era el único, el club se elimina. Atómico mediante WriteBatch.
Future<void> _leaveClub(ClubModel club, String uid) async {
  final db      = FirebaseFirestore.instance;
  final clubRef = db.collection('clubs').doc(club.id);
  final userRef = db.collection('users').doc(uid);
  final batch   = db.batch();

  if (uid == club.adminId) {
    final remaining = club.members.where((m) => m != uid).toList();
    if (remaining.isEmpty) {
      batch.delete(clubRef);
    } else {
      batch.update(clubRef, {
        'adminId': remaining.first, // el más antiguo hereda
        'members': remaining,
      });
    }
  } else {
    batch.update(clubRef, {'members': FieldValue.arrayRemove([uid])});
  }

  batch.update(userRef, {'clubId': FieldValue.delete()});
  await batch.commit();
}

class _ClubActionButton extends StatelessWidget {
  const _ClubActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(label, style: AppTextStyles.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubStat extends StatelessWidget {
  const _ClubStat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(value, style: AppTextStyles.statNumber.copyWith(color: color, fontSize: 28)),
        Text(label, style: AppTextStyles.statLabel),
      ]),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Código de invitación', style: AppTextStyles.caption),
              Text(code, style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Vista cuando el usuario NO tiene club ─────────────────────────────────────
class _NoClubView extends ConsumerStatefulWidget {
  const _NoClubView();

  @override
  ConsumerState<_NoClubView> createState() => _NoClubViewState();
}

class _NoClubViewState extends ConsumerState<_NoClubView> {
  final _nameCtrl   = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _isLoading   = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  // Mínimo 3 caracteres para el nombre del club (null = sin error).
  static const int _minClubNameLength = 3;
  String? get _nameError {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty) return null; // no molestamos hasta que empiece a escribir
    if (n.length < _minClubNameLength) {
      return 'Mínimo $_minClubNameLength caracteres';
    }
    return null;
  }

  bool get _canCreateClub =>
      _nameCtrl.text.trim().length >= _minClubNameLength &&
      _cityCtrl.text.trim().isNotEmpty;

  Future<void> _createClub() async {
    if (!_canCreateClub) return;
    setState(() => _isLoading = true);

    final uid  = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final clubId = const Uuid().v4();
    final code   = clubId.substring(0, 6).toUpperCase();

    final club = ClubModel(
      id:         clubId,
      name:       _nameCtrl.text.trim(),
      city:       _cityCtrl.text.trim(),
      adminId:    uid,
      inviteCode: code,
      members:    [uid],
    );

    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .set(club.toFirestore());

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'clubId': clubId});

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _joinClub() async {
    final code = _inviteCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _isLoading = true);

    final uid  = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('clubs')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (!mounted) return;

    if (snap.docs.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de club no encontrado'),
            backgroundColor: AppColors.accent),
      );
      return;
    }

    final clubId = snap.docs.first.id;
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .update({'members': FieldValue.arrayUnion([uid])});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'clubId': clubId});

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Únete o crea un club', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text('Corre en equipo y domina el ranking',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),

          // Crear club
          Text('Crear nuevo RunClub', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nombre del club',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ciudad'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_isLoading || !_canCreateClub) ? null : _createClub,
            icon:  const Icon(Icons.add_rounded),
            label: const Text('Crear club'),
          ),

          const SizedBox(height: 32),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('o únete con código', style: AppTextStyles.caption),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 24),

          // Unirse con código
          TextField(
            controller: _inviteCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Código de invitación',
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _isLoading ? null : _joinClub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
