import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/announcement_model.dart';

// Anuncios del tablón. Se ordenan en cliente (fijados primero, luego por fecha
// desc) para no exigir índices ni que cada doc tenga `createdAt` — los añade el
// admin a mano desde la consola de Firebase.
final announcementsProvider =
    StreamProvider.autoDispose<List<AnnouncementModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('announcements')
      .snapshots()
      .map((snap) {
    final items = snap.docs
        .map((doc) => AnnouncementModel.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final da = a.createdAt, db = b.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1; // sin fecha al final
      if (db == null) return -1;
      return db.compareTo(da); // más reciente primero
    });

    return items;
  });
});
