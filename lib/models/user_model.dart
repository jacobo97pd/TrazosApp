import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.stravaId,
    this.stravaToken,
    this.stravaConnected = false,
    this.clubId,
    this.level = 1,
    this.totalKm = 0.0,
    this.totalAreaM2 = 0.0,
    this.capturedZones = const [],
    this.fcmToken,
    this.lastActive,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? stravaId;
  final String? stravaToken;
  final bool   stravaConnected;
  final String? clubId;
  final int    level;
  final double totalKm;
  final double totalAreaM2; // área total de territorio controlado (ranking)
  final List<String> capturedZones;

  double get totalAreaKm2 => totalAreaM2 / 1000000;
  final String? fcmToken;
  final DateTime? lastActive;

  // El flag stravaConnected lo escribe StravaService al guardar tokens en el
  // almacén seguro; stravaToken ya no se persiste en Firestore.
  bool get isStravaConnected => stravaConnected && stravaId != null;
  bool get isInClub          => clubId != null;

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserModel(
      uid:           doc.id,
      displayName:   d['displayName'] as String? ?? '',
      email:         d['email'] as String? ?? '',
      photoUrl:      d['photoUrl'] as String?,
      stravaId:      d['stravaId'] as String?,
      stravaToken:   d['stravaToken'] as String?,
      stravaConnected: d['stravaConnected'] as bool? ?? false,
      clubId:        d['clubId'] as String?,
      level:         (d['level'] as num?)?.toInt() ?? 1,
      totalKm:       (d['totalKm'] as num?)?.toDouble() ?? 0.0,
      totalAreaM2:   (d['totalAreaM2'] as num?)?.toDouble() ?? 0.0,
      capturedZones: List<String>.from(d['capturedZones'] as List? ?? []),
      fcmToken:      d['fcmToken'] as String?,
      lastActive:    (d['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'displayName':   displayName,
    'email':         email,
    if (photoUrl  != null) 'photoUrl':    photoUrl,
    if (stravaId  != null) 'stravaId':    stravaId,
    if (stravaToken != null) 'stravaToken': stravaToken,
    'stravaConnected': stravaConnected,
    if (clubId    != null) 'clubId':      clubId,
    'level':         level,
    'totalKm':       totalKm,
    'capturedZones': capturedZones,
    if (fcmToken  != null) 'fcmToken': fcmToken,
    'lastActive':    FieldValue.serverTimestamp(),
  };

  UserModel copyWith({
    String? displayName, String? photoUrl, String? stravaId,
    String? stravaToken, bool? stravaConnected, String? clubId, int? level,
    double? totalKm, List<String>? capturedZones, String? fcmToken,
  }) => UserModel(
    uid: uid, email: email,
    displayName:   displayName  ?? this.displayName,
    photoUrl:      photoUrl     ?? this.photoUrl,
    stravaId:      stravaId     ?? this.stravaId,
    stravaToken:   stravaToken  ?? this.stravaToken,
    stravaConnected: stravaConnected ?? this.stravaConnected,
    clubId:        clubId       ?? this.clubId,
    level:         level        ?? this.level,
    totalKm:       totalKm      ?? this.totalKm,
    capturedZones: capturedZones ?? this.capturedZones,
    fcmToken:      fcmToken     ?? this.fcmToken,
  );

  @override
  List<Object?> get props => [uid, displayName, email, level, totalKm, capturedZones];
}
