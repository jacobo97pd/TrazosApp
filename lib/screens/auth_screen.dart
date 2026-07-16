import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../services/strava_service.dart';

// Paginas legales (Firebase Hosting).
const _kTermsUrl = 'https://trazos-database.web.app/terms.html';
const _kPrivacyUrl = 'https://trazos-database.web.app/privacy.html';

enum _AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Restablecer contraseña: envía el correo de reset al email introducido.
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Introduce tu email para restablecer la contraseña.');
      return;
    }
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);
      _snack('Te hemos enviado un correo para restablecer la contraseña.');
    } catch (e) {
      _snack('No se pudo enviar el correo: $e');
    }
  }

  Future<void> _openLegal(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok) _snack('No se pudo abrir el enlace.');
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final notifier = ref.read(authNotifierProvider.notifier);

    if (_mode == _AuthMode.signIn) {
      await notifier.signInWithEmail(_emailCtrl.text, _passCtrl.text);
    } else {
      await notifier.signUpWithEmail(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    authState.whenOrNull(
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppColors.accent),
      ),
    );
  }

  Future<void> _signInWithStrava() async {
    try {
      // Móvil: completa el login y devuelve true (el listener de authState navega).
      // Web: redirige la pestaña a Strava y devuelve false (vuelve tras autorizar).
      final started = await ref.read(stravaServiceProvider).signInWithStrava();
      if (!started && !kIsWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Inicio de sesión con Strava cancelado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error con Strava: $e'),
              backgroundColor: AppColors.accent),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    // El listener de authState navega al mapa si entra; aquí solo mostramos error.
    ref.read(authNotifierProvider).whenOrNull(
          error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error con Google: $e'),
                backgroundColor: AppColors.accent),
          ),
        );
  }

  Future<void> _signInWithApple() async {
    await ref.read(authNotifierProvider.notifier).signInWithApple();
    if (!mounted) return;
    ref.read(authNotifierProvider).whenOrNull(
          error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error con Apple: $e'),
                backgroundColor: AppColors.accent),
          ),
        );
  }

  // Apple exige "Sign in with Apple" en iOS si hay otros logins sociales.
  // También funciona en web; en Android usamos Google como nativo.
  bool get _showAppleButton =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null) context.go(AppRoutes.map);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('Bienvenido a\nTrazos', style: AppTextStyles.displayLarge),
                const SizedBox(height: 8),
                Text(
                  _mode == _AuthMode.signIn
                      ? 'Inicia sesión para seguir corriendo'
                      : 'Crea tu cuenta y empieza a conquistar',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),

                // Nombre (solo registro)
                if (_mode == _AuthMode.signUp) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Mínimo 2 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email no válido'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),

                // Confirmar contraseña (solo registro) — evita erratas.
                if (_mode == _AuthMode.signUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscurePass,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v != _passCtrl.text)
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                ],

                // ¿Olvidaste la contraseña? (solo inicio de sesión), entre el
                // campo de contraseña y el botón de acceso.
                if (_mode == _AuthMode.signIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading ? null : _forgotPassword,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),

                SizedBox(height: _mode == _AuthMode.signIn ? 12 : 28),

                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(_mode == _AuthMode.signIn
                          ? 'Iniciar sesión'
                          : 'Crear cuenta'),
                ),
                const SizedBox(height: 16),

                // Divider OR
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o', style: AppTextStyles.caption),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                // Botón Apple — login con Apple (obligatorio en iOS)
                if (_showAppleButton) ...[
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _signInWithApple,
                    icon: const Icon(Icons.apple, size: 22),
                    label: const Text('Continuar con Apple'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Botón Strava — login con Strava
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _signInWithStrava,
                  icon: const Icon(Icons.directions_run, size: 20),
                  label: const Text('Iniciar sesión con Strava'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFC4C02), // naranja Strava
                    side:
                        const BorderSide(color: Color(0xFFFC4C02), width: 1.5),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Google — login con Google
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.account_circle_rounded, size: 20),
                  label: const Text('Continuar con Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle modo
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _mode =
                        _mode == _AuthMode.signIn
                            ? _AuthMode.signUp
                            : _AuthMode.signIn),
                    child: Text(
                      _mode == _AuthMode.signIn
                          ? '¿Sin cuenta? Regístrate'
                          : '¿Ya tienes cuenta? Inicia sesión',
                    ),
                  ),
                ),

                // Acceso a Términos y Política de privacidad.
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Al continuar aceptas los ',
                          style: AppTextStyles.caption),
                      _LegalLink(
                        label: 'Términos',
                        onTap: () => _openLegal(_kTermsUrl),
                      ),
                      Text(' y la ', style: AppTextStyles.caption),
                      _LegalLink(
                        label: 'Política de privacidad',
                        onTap: () => _openLegal(_kPrivacyUrl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enlace de texto para las páginas legales.
class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
