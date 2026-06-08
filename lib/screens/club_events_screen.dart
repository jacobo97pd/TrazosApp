import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../widgets/event_card.dart';

class ClubEventsScreen extends ConsumerWidget {
  const ClubEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubId = ref.watch(userProfileProvider).valueOrNull?.clubId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Eventos del club')),
      floatingActionButton: clubId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.createEvent),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear evento'),
            ),
      body: clubId == null
          ? const Center(child: Text('No estás en ningún club'))
          : ref.watch(clubEventsProvider(clubId)).when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (events) {
                  if (events.isEmpty) return const _EmptyEvents();
                  // Próximos primero (por fecha), pasados al final.
                  final sorted = [...events]..sort((a, b) {
                      if (a.isPast != b.isPast) return a.isPast ? 1 : -1;
                      return a.dateTime.compareTo(b.dateTime);
                    });
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) => EventCard(event: sorted[i]),
                  );
                },
              ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_rounded, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text('Aún no hay eventos',
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Crea uno con el botón de abajo y planifica con tu club.',
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
