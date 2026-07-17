import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../conquest/conquest_interaction.dart';
import '../conquest/conquest_interaction_providers.dart';
import '../core/theme.dart';
import '../services/analytics_service.dart';

Future<ReportConquestPostResult?> showConquestReportSheet(
  BuildContext context, {
  required String postId,
}) =>
    showModalBottomSheet<ReportConquestPostResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ConquestReportSheet(postId: postId),
    );

class _ConquestReportSheet extends ConsumerStatefulWidget {
  const _ConquestReportSheet({required this.postId});
  final String postId;

  @override
  ConsumerState<_ConquestReportSheet> createState() =>
      _ConquestReportSheetState();
}

class _ConquestReportSheetState extends ConsumerState<_ConquestReportSheet> {
  final _details = TextEditingController();
  ReportReason _reason = ReportReason.spam;
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(conquestInteractionControllerProvider)
          .report(widget.postId, _reason, details: _details.text);
      if (result.created) {
        logAnalyticsBestEffort(
          () => ref
              .read(analyticsServiceProvider)
              .logReportSubmitted(reason: _reason.wireValue),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ArgumentError catch (error) {
      _show(error.message?.toString() ?? 'Los detalles no son válidos.');
    } catch (_) {
      _show('No se pudo enviar el reporte.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reportar publicación',
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Revisaremos el contenido sin compartir tu identidad con el autor.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReportReason>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: [
                  for (final reason in ReportReason.values)
                    DropdownMenuItem(
                      value: reason,
                      child: Text(_reasonLabel(reason)),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _reason = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _details,
                maxLength: ConquestInteractionValidation.maxReportDetailsLength,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detalles (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined),
                label: const Text('Enviar reporte'),
              ),
            ],
          ),
        ),
      );
}

String _reasonLabel(ReportReason reason) => switch (reason) {
      ReportReason.spam => 'Spam',
      ReportReason.harassment => 'Acoso',
      ReportReason.hateSpeech => 'Discurso de odio',
      ReportReason.violence => 'Violencia',
      ReportReason.sexualContent => 'Contenido sexual',
      ReportReason.dangerousActivity => 'Actividad peligrosa',
      ReportReason.privacy => 'Privacidad',
      ReportReason.misinformation => 'Información falsa',
      ReportReason.other => 'Otro motivo',
    };
