import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/event_model.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';

/// Tarjeta de evento reutilizable (club y tablón). Permite apuntarse/salir,
/// muestra fecha, lugar, notas y la lista de asistentes.
class EventCard extends ConsumerStatefulWidget {
  const EventCard({super.key, required this.event, this.showClubName = false});
  final EventModel event;
  final bool showClubName;

  @override
  ConsumerState<EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<EventCard> {
  bool _busy = false;

  Future<void> _toggle(String uid, String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.event.isAttending(uid)) {
        await EventsService.leave(widget.event, uid);
      } else {
        await EventsService.join(widget.event, uid, name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${widget.event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await EventsService.delete(widget.event.id);
  }

  @override
  Widget build(BuildContext context) {
    final e    = widget.event;
    final user = ref.watch(userProfileProvider).valueOrNull;
    final uid  = user?.uid;
    final name = user?.displayName ?? 'Corredor';
    final attending = uid != null && e.isAttending(uid);
    final canManage = uid != null && uid == e.createdBy;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: e.isPast ? AppColors.border : AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(e.title, style: AppTextStyles.titleLarge)),
              if (e.isPublic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Público',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.green, fontWeight: FontWeight.w600)),
                ),
              if (canManage)
                GestureDetector(
                  onTap: _delete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          if (widget.showClubName && e.clubName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(e.clubName, style: AppTextStyles.caption.copyWith(color: AppColors.cyan)),
          ],
          const SizedBox(height: 12),
          _IconLine(icon: Icons.schedule_rounded,
              text: DateFormat('EEE dd/MM · HH:mm').format(e.dateTime)),
          const SizedBox(height: 6),
          _IconLine(icon: Icons.place_rounded, text: e.location),
          if (e.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            _IconLine(icon: Icons.notes_rounded, text: e.notes),
          ],
          const SizedBox(height: 14),

          // Asistentes
          Row(
            children: [
              const Icon(Icons.group_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('${e.attendeeCount} apuntado${e.attendeeCount == 1 ? '' : 's'}',
                  style: AppTextStyles.labelMedium),
            ],
          ),
          if (e.attendees.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: e.attendees.values
                  .map((n) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(n, style: AppTextStyles.caption),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: e.isPast
                ? const OutlinedButton(
                    onPressed: null,
                    child: Text('Evento finalizado'),
                  )
                : (attending
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : () => _toggle(uid, name),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Apuntado · Salir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.green,
                          side: const BorderSide(color: AppColors.green, width: 1.5),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: (_busy || uid == null) ? null : () => _toggle(uid, name),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Apuntarme'),
                      )),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
