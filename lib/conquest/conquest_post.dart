import 'zone_conquest.dart' show ConquestVisibility, LocationPrivacyMode;

export 'zone_conquest.dart' show ConquestVisibility, LocationPrivacyMode;

/// Tipo de contenido. Ampliable sin tocar el núcleo.
enum ConquestType {
  photo,
  selfie,
  text,
  story,
  achievementShare,
  zoneConquest,
  activityMoment,
}

/// Publicación ligada a una conquista/actividad/reto/logro. Contenido permanente
/// (o temporal si `expiresAt` != null, ver historias).
class ConquestPost {
  const ConquestPost({
    required this.id,
    required this.userId,
    required this.type,
    required this.visibility,
    required this.createdAt,
    this.updatedAt,
    this.zoneId,
    this.activityId,
    this.challengeId,
    this.achievementId,
    this.caption = '',
    this.mediaUrl,
    this.thumbnailUrl,
    this.expiresAt,
    this.isArchived = false,
    this.isDeleted = false,
    this.locationPrivacyMode = LocationPrivacyMode.city,
    this.zoneNameSnapshot = '',
    this.distanceSnapshot = 0,
    this.durationSnapshot = 0,
    this.paceSnapshot = 0,
    this.elevationSnapshot = 0,
    this.likesCount = 0,
    this.applauseCount = 0,
    this.commentsCount = 0,
    this.reportCount = 0,
    this.moderationStatus = 'ok',
  });

  final String id;
  final String userId;
  final ConquestType type;
  final ConquestVisibility visibility;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? zoneId;
  final String? activityId;
  final String? challengeId;
  final String? achievementId;
  final String caption;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final DateTime? expiresAt; // historias
  final bool isArchived;
  final bool isDeleted;
  final LocationPrivacyMode locationPrivacyMode;

  // Snapshots (recuerdo inmutable).
  final String zoneNameSnapshot;
  final double distanceSnapshot;
  final int durationSnapshot;
  final double paceSnapshot;
  final double elevationSnapshot;

  // Contadores (los gestiona backend/transacción; el cliente no los altera).
  final int likesCount;
  final int applauseCount;
  final int commentsCount;
  final int reportCount;
  final String moderationStatus; // ok | hidden | under_review | removed

  bool get isStory => expiresAt != null;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  ConquestPost copyWith({
    ConquestVisibility? visibility,
    String? caption,
    String? mediaUrl,
    String? thumbnailUrl,
    bool? isArchived,
    bool? isDeleted,
    DateTime? updatedAt,
    String? moderationStatus,
    int? likesCount,
    int? applauseCount,
    int? commentsCount,
    int? reportCount,
  }) =>
      ConquestPost(
        id: id,
        userId: userId,
        type: type,
        visibility: visibility ?? this.visibility,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        zoneId: zoneId,
        activityId: activityId,
        challengeId: challengeId,
        achievementId: achievementId,
        caption: caption ?? this.caption,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        expiresAt: expiresAt,
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
        locationPrivacyMode: locationPrivacyMode,
        zoneNameSnapshot: zoneNameSnapshot,
        distanceSnapshot: distanceSnapshot,
        durationSnapshot: durationSnapshot,
        paceSnapshot: paceSnapshot,
        elevationSnapshot: elevationSnapshot,
        likesCount: likesCount ?? this.likesCount,
        applauseCount: applauseCount ?? this.applauseCount,
        commentsCount: commentsCount ?? this.commentsCount,
        reportCount: reportCount ?? this.reportCount,
        moderationStatus: moderationStatus ?? this.moderationStatus,
      );
}
