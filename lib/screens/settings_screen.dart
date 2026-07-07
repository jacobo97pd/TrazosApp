import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

// Páginas legales (Firebase Hosting).
const _kTermsUrl = 'https://trazos-database.web.app/terms.html';
const _kPrivacyUrl = 'https://trazos-database.web.app/privacy.html';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok) _snack('No se pudo abrir el enlace.');
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Limpiar caché?'),
        content: const Text(
          'Se borran las imágenes guardadas temporalmente (fotos de perfil, '
          'logos…). Tu cuenta y tus datos no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _clearing = true);
    try {
      // Caché en memoria de Flutter + caché en disco de imágenes de red.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await CachedNetworkImage.evictFromCache('');
      await DefaultCacheManager().emptyCache();
      _snack('Caché limpiada.');
    } catch (e) {
      _snack('No se pudo limpiar la caché: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (email != null && email.isNotEmpty) ...[
            const _SectionHeader('Cuenta'),
            _SettingsTile(
              icon: Icons.email_outlined,
              title: 'Correo',
              subtitle: email,
            ),
          ],

          const _SectionHeader('Aplicación'),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Limpiar caché',
            subtitle: 'Libera espacio borrando imágenes temporales',
            trailing: _clearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
            onTap: _clearing ? null : _clearCache,
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Versión',
            subtitle: _version.isEmpty ? '…' : _version,
          ),

          const _SectionHeader('Legal'),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Términos de servicio',
            trailing: const Icon(Icons.open_in_new_rounded,
                size: 18, color: AppColors.textSecondary),
            onTap: () => _openUrl(_kTermsUrl),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            trailing: const Icon(Icons.open_in_new_rounded,
                size: 18, color: AppColors.textSecondary),
            onTap: () => _openUrl(_kPrivacyUrl),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(title.toUpperCase(),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          )),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.bodyLarge),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
