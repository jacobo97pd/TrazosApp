import 'package:cloud_firestore/cloud_firestore.dart';

/// Mensaje del chat interno de un club: `clubs/{clubId}/messages/{id}`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id:         doc.id,
      senderId:   d['senderId']   as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      text:       d['text']       as String? ?? '',
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
