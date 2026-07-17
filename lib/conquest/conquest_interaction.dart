/// Reaccion unica que un usuario puede mantener sobre una conquista.
enum ReactionType { like, applause }

extension ReactionTypeWire on ReactionType {
  String get wireValue => name;

  static ReactionType? tryParse(String? value) {
    for (final type in ReactionType.values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

/// Motivos que acepta el backend. Es un conjunto cerrado para evitar valores
/// arbitrarios y poder agrupar reportes durante la moderacion.
enum ReportReason {
  spam,
  harassment,
  hateSpeech,
  violence,
  sexualContent,
  dangerousActivity,
  privacy,
  misinformation,
  other,
}

extension ReportReasonWire on ReportReason {
  String get wireValue => switch (this) {
        ReportReason.spam => 'spam',
        ReportReason.harassment => 'harassment',
        ReportReason.hateSpeech => 'hate_speech',
        ReportReason.violence => 'violence',
        ReportReason.sexualContent => 'sexual_content',
        ReportReason.dangerousActivity => 'dangerous_activity',
        ReportReason.privacy => 'privacy',
        ReportReason.misinformation => 'misinformation',
        ReportReason.other => 'other',
      };

  static ReportReason? tryParse(String? value) {
    for (final reason in ReportReason.values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

enum ConquestModerationStatus { ok, underReview, hidden, removed }

extension ConquestModerationStatusWire on ConquestModerationStatus {
  String get wireValue => switch (this) {
        ConquestModerationStatus.ok => 'ok',
        ConquestModerationStatus.underReview => 'under_review',
        ConquestModerationStatus.hidden => 'hidden',
        ConquestModerationStatus.removed => 'removed',
      };

  static ConquestModerationStatus? tryParse(String? value) {
    for (final status in ConquestModerationStatus.values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

class ConquestReaction {
  const ConquestReaction({
    required this.postId,
    required this.userId,
    required this.kind,
    required this.createdAt,
    this.updatedAt,
  });

  final String postId;
  final String userId;
  final ReactionType kind;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Un usuario solo puede ocupar un documento de reaccion por post.
  static String documentPath(String postId, String userId) =>
      'conquest_posts/${ConquestInteractionValidation.documentId(postId)}/'
      'reactions/${ConquestInteractionValidation.documentId(userId)}';
}

class ConquestComment {
  const ConquestComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorPhotoUrl,
    this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.moderationStatus = ConquestModerationStatus.ok,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final ConquestModerationStatus moderationStatus;

  bool get isVisible =>
      !isDeleted && moderationStatus == ConquestModerationStatus.ok;

  static String documentPath(String postId, String commentId) =>
      'conquest_posts/${ConquestInteractionValidation.documentId(postId)}/'
      'comments/${ConquestInteractionValidation.documentId(commentId)}';
}

class ConquestReport {
  const ConquestReport({
    required this.postId,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    this.details,
  });

  final String postId;
  final String reporterId;
  final ReportReason reason;
  final String? details;
  final DateTime createdAt;

  /// El UID como ID hace que cada usuario solo pueda reportar una vez el post.
  static String documentPath(String postId, String reporterId) =>
      'conquest_posts/${ConquestInteractionValidation.documentId(postId)}/'
      'reports/${ConquestInteractionValidation.documentId(reporterId)}';
}

class SetConquestReactionResult {
  const SetConquestReactionResult({
    required this.changed,
    required this.reaction,
    required this.likesCount,
    required this.applauseCount,
  });

  final bool changed;
  final ReactionType? reaction;
  final int likesCount;
  final int applauseCount;
}

class CreateConquestCommentResult {
  const CreateConquestCommentResult({
    required this.commentId,
    required this.created,
  });

  final String commentId;
  final bool created;
}

class ReportConquestPostResult {
  const ReportConquestPostResult({
    required this.created,
    required this.reportCount,
    required this.moderationStatus,
  });

  final bool created;
  final int reportCount;
  final ConquestModerationStatus moderationStatus;
}

/// Guardas puras compartidas por UI, repositorio y tests.
class ConquestInteractionValidation {
  const ConquestInteractionValidation._();

  static const int minCommentLength = 1;
  static const int maxCommentLength = 500;
  static const int maxReportDetailsLength = 500;

  /// Recorta espacios exteriores y devuelve el valor listo para enviar.
  static String commentText(String raw) {
    final normalized = raw.trim();
    if (normalized.length < minCommentLength ||
        normalized.length > maxCommentLength) {
      throw ArgumentError(
        'El comentario debe tener entre 1 y 500 caracteres.',
        'text',
      );
    }
    return normalized;
  }

  /// Los detalles son opcionales. Un texto compuesto solo por espacios se
  /// representa como null para mantener estable el contrato del callable.
  static String? reportDetails(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.length > maxReportDetailsLength) {
      throw ArgumentError(
        'Los detalles no pueden superar 500 caracteres.',
        'details',
      );
    }
    return normalized;
  }

  /// Valida segmentos usados como IDs de documentos de Firestore.
  static String documentId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(value, 'id', 'ID de documento no valido.');
    }
    return normalized;
  }
}
