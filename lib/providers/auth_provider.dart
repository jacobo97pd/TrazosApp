import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

// OAuth client web (client_type 3 de google-services.json): necesario para que
// google_sign_in devuelva un idToken válido para Firebase en Android.
const _googleServerClientId =
    '756598503122-e1lggntuvmipvm3reafeu1dfkfgrtfg6.apps.googleusercontent.com';
const _googleIosClientId =
    '756598503122-hocqseqqlbtau0nrdpgjsdktcqivfad2.apps.googleusercontent.com';

// Stream del usuario Firebase Auth
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Proveedor del perfil completo desde Firestore
final userProfileProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .withConverter<UserModel>(
        fromFirestore: (snap, _) => UserModel.fromFirestore(snap),
        toFirestore: (model, _) => model.toFirestore(),
      )
      .snapshots()
      .map((snap) => snap.data());
});

// Notifier para operaciones de auth
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(displayName);

      // Crear documento en Firestore
      final model = UserModel(
        uid: cred.user!.uid,
        displayName: displayName,
        email: email.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(model.toFirestore());
    });
  }

  // ── Login con Google ──────────────────────────────────────────────────────
  // Web: popup de Firebase. Móvil: google_sign_in → credencial → Firebase.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        final cred =
            await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
        if (cred.user != null) await _ensureUserDoc(cred.user!);
      } else {
        final googleUser = await _mobileGoogleSignIn().signIn();
        if (googleUser == null) return; // el usuario canceló
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final cred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (cred.user != null) await _ensureUserDoc(cred.user!);
      }
    });
  }

  // ── Login con Apple ───────────────────────────────────────────────────────
  // iOS/macOS: flujo nativo "Sign in with Apple" (requiere el entitlement
  // com.apple.developer.applesignin). Web: popup. Android: flujo web vía el
  // Services ID configurado en Firebase.
  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final cred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      if (cred.user != null) await _ensureUserDoc(cred.user!);
    });
  }

  // Crea el documento del usuario en Firestore si es su primer acceso.
  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final model = UserModel(
      uid: user.uid,
      displayName: user.displayName ?? 'Corredor',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
    await ref.set(model.toFirestore());
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _mobileGoogleSignIn().signOut();
      } catch (_) {/* no pasa nada si no había sesión de Google */}
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> resetPassword(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

GoogleSignIn _mobileGoogleSignIn() {
  final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  return GoogleSignIn(
    clientId: isApplePlatform ? _googleIosClientId : null,
    serverClientId: _googleServerClientId,
  );
}
