import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';

// Stream de mensajes del chat del club (más recientes primero, para ListView reverse).
final clubMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, clubId) {
  return FirebaseFirestore.instance
      .collection('clubs')
      .doc(clubId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ChatMessage.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

Future<void> sendClubMessage({
  required String clubId,
  required String text,
  required String senderName,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final body = text.trim();
  if (uid == null || body.isEmpty) return;

  await FirebaseFirestore.instance
      .collection('clubs')
      .doc(clubId)
      .collection('messages')
      .add({
    'senderId':   uid,
    'senderName': senderName,
    'text':       body,
    'createdAt':  FieldValue.serverTimestamp(),
  });
}
