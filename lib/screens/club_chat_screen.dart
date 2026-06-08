import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../providers/club_chat_provider.dart';

class ClubChatScreen extends ConsumerStatefulWidget {
  const ClubChatScreen({super.key});

  @override
  ConsumerState<ClubChatScreen> createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends ConsumerState<ClubChatScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send(String clubId, String senderName) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await sendClubMessage(clubId: clubId, text: text, senderName: senderName);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user   = ref.watch(userProfileProvider).valueOrNull;
    final clubId = user?.clubId;
    final myUid  = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chat del club')),
      body: clubId == null
          ? const Center(child: Text('No estás en ningún club'))
          : Column(
              children: [
                Expanded(child: _MessageList(clubId: clubId, myUid: myUid)),
                _Composer(
                  controller: _ctrl,
                  sending: _sending,
                  onSend: () => _send(clubId, user?.displayName ?? 'Corredor'),
                ),
              ],
            ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.clubId, required this.myUid});
  final String clubId;
  final String? myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clubMessagesProvider(clubId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Text('Sé el primero en escribir 👋',
                style: AppTextStyles.caption),
          );
        }
        return ListView.builder(
          reverse: true, // el query viene desc → el más nuevo abajo
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (_, i) => _Bubble(
            message: messages[i],
            mine: messages[i].senderId == myUid,
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(message.senderName,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.cyan)),
            if (!mine) const SizedBox(height: 2),
            Text(message.text,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: mine ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Escribe un mensaje…'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
