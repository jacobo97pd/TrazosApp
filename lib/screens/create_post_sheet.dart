import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../conquest/conquest_post.dart';
import '../conquest/conquest_providers.dart';
import '../core/theme.dart';

/// Datos de la conquista para asociar la publicación.
class ConquestContext {
  const ConquestContext({
    this.zoneName = 'Territorio',
    this.activityId,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.paceMinPerKm = 0,
  });
  final String zoneName;
  final String? activityId;
  final double distanceMeters;
  final int durationSeconds;
  final double paceMinPerKm;
}

Future<void> showCreatePostSheet(BuildContext context, ConquestContext ctx) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CreatePostSheet(ctx: ctx),
  );
}

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet({required this.ctx});
  final ConquestContext ctx;
  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _caption = TextEditingController();
  ConquestVisibility _visibility =
      ConquestVisibility.onlyMe; // nunca público por defecto
  Uint8List? _pickedBytes;
  ConquestType _type = ConquestType.text;
  bool _isStory = false;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source, ConquestType type) async {
    final x = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front, // selfie
      maxWidth: 2000,
      imageQuality: 95,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _type = type;
    });
  }

  Future<void> _submit({required bool private}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? mediaUrl, thumbUrl;
      if (_pickedBytes != null) {
        final up = await ref
            .read(conquestMediaServiceProvider)
            .uploadImage(userId: uid, bytes: _pickedBytes!);
        mediaUrl = up.mediaUrl;
        thumbUrl = up.thumbnailUrl;
      }
      final now = DateTime.now();
      final post = ConquestPost(
        id: const Uuid().v4(),
        userId: uid,
        type: _pickedBytes != null ? _type : ConquestType.text,
        visibility: private ? ConquestVisibility.onlyMe : _visibility,
        createdAt: now,
        activityId: widget.ctx.activityId,
        caption: _caption.text.trim(),
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbUrl,
        expiresAt:
            _isStory ? ref.read(storyServiceProvider).expiresAtFrom(now) : null,
        zoneNameSnapshot: widget.ctx.zoneName,
        distanceSnapshot: widget.ctx.distanceMeters,
        durationSnapshot: widget.ctx.durationSeconds,
        paceSnapshot: widget.ctx.paceMinPerKm,
      );
      await ref.read(conquestPostRepositoryProvider).create(post);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Guardado.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Limita la altura y permite scroll: con el teclado abierto en pantallas
    // pequeñas el contenido nunca desborda.
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deja tu huella', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text('Conquistaste ${widget.ctx.zoneName}.',
                style: AppTextStyles.caption),
            const SizedBox(height: 16),
            if (_pickedBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_pickedBytes!,
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _pick(ImageSource.camera, ConquestType.selfie),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Selfie'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _pick(ImageSource.gallery, ConquestType.photo),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Foto'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Escribe algo (opcional)',
              ),
            ),
            Row(
              children: [
                Text('Visibilidad', style: AppTextStyles.caption),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<ConquestVisibility>(
                    value: _visibility,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    onChanged: (v) => setState(() => _visibility = v!),
                    items: const [
                      DropdownMenuItem(
                          value: ConquestVisibility.onlyMe,
                          child: Text('Solo yo')),
                      DropdownMenuItem(
                          value: ConquestVisibility.connections,
                          child: Text('Conexiones')),
                      DropdownMenuItem(
                          value: ConquestVisibility.public,
                          child: Text('Público en Trazos')),
                    ],
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isStory,
              activeThumbColor: AppColors.accent,
              onChanged:
                  _busy ? null : (value) => setState(() => _isStory = value),
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Compartir como historia'),
              subtitle: const Text('Desaparece automáticamente en 24 horas'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _submit(private: true),
                    child: const Text('Guardar en privado'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _submit(private: false),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
