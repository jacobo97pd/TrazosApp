import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  DateTime _dateTime  = DateTime.now().add(const Duration(days: 1));
  bool _isPublic      = false;
  bool _saving        = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day,
          time?.hour ?? _dateTime.hour, time?.minute ?? _dateTime.minute);
    });
  }

  Future<void> _submit() async {
    final user   = ref.read(userProfileProvider).valueOrNull;
    final uid    = FirebaseAuth.instance.currentUser?.uid;
    final clubId = user?.clubId;
    if (uid == null || clubId == null) return;

    if (_titleCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon al menos título y lugar.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Necesitamos el nombre del club para denormalizarlo en el evento.
      final clubSnap =
          await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
      final clubName = clubSnap.data()?['name'] as String? ?? 'Club';

      await EventsService.create(
        clubId:      clubId,
        clubName:    clubName,
        title:       _titleCtrl.text.trim(),
        location:    _locationCtrl.text.trim(),
        dateTime:    _dateTime,
        notes:       _notesCtrl.text.trim(),
        isPublic:    _isPublic,
        creatorUid:  uid,
        creatorName: user?.displayName ?? 'Corredor',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al crear: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nuevo evento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Título del evento'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
                labelText: 'Lugar', hintText: 'Ej: Parque del Retiro, Puerta de Alcalá'),
          ),
          const SizedBox(height: 16),

          // Fecha y hora
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(DateFormat('EEE dd/MM/yyyy · HH:mm').format(_dateTime),
                      style: AppTextStyles.bodyLarge),
                  const Spacer(),
                  Text('Cambiar', style: AppTextStyles.labelLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _notesCtrl,
            minLines: 3, maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Notas', hintText: 'Ritmo, distancia, qué llevar…'),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            activeThumbColor: AppColors.accent,
            contentPadding: EdgeInsets.zero,
            title: const Text('Publicar en el tablón general'),
            subtitle: Text('Cualquiera podrá verlo y apuntarse, tenga club o no.',
                style: AppTextStyles.caption),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Crear evento'),
          ),
        ],
      ),
    );
  }
}
