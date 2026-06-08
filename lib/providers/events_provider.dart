import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_model.dart';

final _events = FirebaseFirestore.instance.collection('events');

List<EventModel> _parseSorted(QuerySnapshot<Map<String, dynamic>> snap) {
  final list = snap.docs
      .map((d) => EventModel.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
      .toList();
  // Orden en cliente (por fecha asc) para no exigir índices compuestos.
  list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return list;
}

// Eventos de un club concreto.
final clubEventsProvider =
    StreamProvider.autoDispose.family<List<EventModel>, String>((ref, clubId) {
  return _events.where('clubId', isEqualTo: clubId).snapshots().map(_parseSorted);
});

// Eventos públicos (para el tablón general).
final publicEventsProvider =
    StreamProvider.autoDispose<List<EventModel>>((ref) {
  return _events.where('isPublic', isEqualTo: true).snapshots().map(_parseSorted);
});

// ── Acciones sobre eventos ────────────────────────────────────────────────────
class EventsService {
  EventsService._();

  static Future<void> create({
    required String clubId,
    required String clubName,
    required String title,
    required String location,
    required DateTime dateTime,
    required String notes,
    required bool isPublic,
    required String creatorUid,
    required String creatorName,
  }) {
    final model = EventModel(
      id:        '',
      clubId:    clubId,
      clubName:  clubName,
      title:     title,
      location:  location,
      dateTime:  dateTime,
      createdBy: creatorUid,
      notes:     notes,
      isPublic:  isPublic,
      attendees: {creatorUid: creatorName}, // el creador se apunta automáticamente
    );
    return _events.add(model.toFirestore());
  }

  static Future<void> join(EventModel e, String uid, String name) =>
      _events.doc(e.id).update({'attendees.$uid': name});

  static Future<void> leave(EventModel e, String uid) =>
      _events.doc(e.id).update({'attendees.$uid': FieldValue.delete()});

  static Future<void> delete(String eventId) => _events.doc(eventId).delete();
}
