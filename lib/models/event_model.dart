import 'package:cloud_firestore/cloud_firestore.dart';

/// Evento de un run club. Vive en la colección global `events` para poder
/// mostrarse tanto dentro del club como en el tablón general (si isPublic).
/// `attendees` es un mapa uid -> nombre para listar quién se apunta sin reads extra.
class EventModel {
  const EventModel({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.title,
    required this.location,
    required this.dateTime,
    required this.createdBy,
    this.notes = '',
    this.isPublic = false,
    this.attendees = const {},
  });

  final String id;
  final String clubId;
  final String clubName;
  final String title;
  final String location;
  final DateTime dateTime;
  final String createdBy;
  final String notes;
  final bool isPublic;
  final Map<String, String> attendees; // uid -> displayName

  int  get attendeeCount => attendees.length;
  bool isAttending(String uid) => attendees.containsKey(uid);
  bool get isPast => dateTime.isBefore(DateTime.now());

  factory EventModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EventModel(
      id:        doc.id,
      clubId:    d['clubId']    as String? ?? '',
      clubName:  d['clubName']  as String? ?? '',
      title:     d['title']     as String? ?? '',
      location:  d['location']  as String? ?? '',
      dateTime:  (d['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
      notes:     d['notes']     as String? ?? '',
      isPublic:  d['isPublic']  as bool? ?? false,
      attendees: Map<String, String>.from(d['attendees'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clubId':    clubId,
        'clubName':  clubName,
        'title':     title,
        'location':  location,
        'dateTime':  Timestamp.fromDate(dateTime),
        'createdBy': createdBy,
        'notes':     notes,
        'isPublic':  isPublic,
        'attendees': attendees,
      };
}
