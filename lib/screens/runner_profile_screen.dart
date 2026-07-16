import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_model.dart';
import '../widgets/avatar_marker.dart';

/// Perfil público de otro corredor (se abre al tocar su avatar en el mapa).
class RunnerProfileScreen extends StatelessWidget {
  const RunnerProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final future = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .withConverter<UserModel>(
          fromFirestore: (s, _) => UserModel.fromFirestore(s),
          toFirestore: (m, _) => m.toFirestore(),
        )
        .get();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Corredor')),
      body: FutureBuilder<DocumentSnapshot<UserModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final user = snap.data?.data();
          if (user == null) {
            return const Center(child: Text('Corredor no encontrado'));
          }
          return _Content(user: user);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrl?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientAccent,
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.surfaceAlt,
              backgroundImage: hasPhoto ? NetworkImage(photo) : null,
              child: hasPhoto
                  ? null
                  : Text(initialsOf(user.displayName),
                      style: AppTextStyles.displayMedium),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName.trim().isEmpty ? 'Runner' : user.displayName,
            style: AppTextStyles.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('Nivel ${user.level}', style: AppTextStyles.caption),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'TERRITORIO',
                  value: _formatArea(user.totalAreaM2),
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'KM TOTALES',
                  value: user.totalKm.toStringAsFixed(user.totalKm >= 100 ? 0 : 1),
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.headlineMedium.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.statLabel),
        ],
      ),
    );
  }
}

String _formatArea(double m2) {
  if (m2 >= 100000) return '${(m2 / 1000000).toStringAsFixed(1)} km²';
  if (m2 >= 10000) return '${(m2 / 1000000).toStringAsFixed(2)} km²';
  return '${m2.round()} m²';
}
