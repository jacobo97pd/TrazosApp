/// Preferencias de privacidad social. Por defecto TODO restrictivo: hay que
/// activar el descubrimiento explícitamente (nunca en silencio).
class SocialPrivacy {
  const SocialPrivacy({
    this.discoverable = false,
    this.showProfile = true,
    this.showActivities = false,
    this.aggregatedOnly = true,
    this.allowPrivateChallenges = true,
    this.appearInLeaderboards = false,
    this.private = false,
  });

  /// Cuenta privada: los seguidores deben ser aprobados y solo ellos ven las
  /// conquistas/historias de nivel "conexiones".
  final bool private;

  /// "Permitir que otros usuarios conectados a Strava me encuentren en Trazos".
  final bool discoverable;
  final bool showProfile;
  final bool showActivities;
  final bool aggregatedOnly;
  final bool allowPrivateChallenges;
  final bool appearInLeaderboards;

  SocialPrivacy copyWith({
    bool? discoverable,
    bool? showProfile,
    bool? showActivities,
    bool? aggregatedOnly,
    bool? allowPrivateChallenges,
    bool? appearInLeaderboards,
    bool? private,
  }) =>
      SocialPrivacy(
        discoverable: discoverable ?? this.discoverable,
        showProfile: showProfile ?? this.showProfile,
        showActivities: showActivities ?? this.showActivities,
        aggregatedOnly: aggregatedOnly ?? this.aggregatedOnly,
        allowPrivateChallenges:
            allowPrivateChallenges ?? this.allowPrivateChallenges,
        appearInLeaderboards: appearInLeaderboards ?? this.appearInLeaderboards,
        private: private ?? this.private,
      );

  Map<String, dynamic> toMap() => {
        'discoverable': discoverable,
        'showProfile': showProfile,
        'showActivities': showActivities,
        'aggregatedOnly': aggregatedOnly,
        'allowPrivateChallenges': allowPrivateChallenges,
        'appearInLeaderboards': appearInLeaderboards,
        'private': private,
      };

  factory SocialPrivacy.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const SocialPrivacy();
    return SocialPrivacy(
      discoverable: m['discoverable'] as bool? ?? false,
      showProfile: m['showProfile'] as bool? ?? true,
      showActivities: m['showActivities'] as bool? ?? false,
      aggregatedOnly: m['aggregatedOnly'] as bool? ?? true,
      allowPrivateChallenges: m['allowPrivateChallenges'] as bool? ?? true,
      appearInLeaderboards: m['appearInLeaderboards'] as bool? ?? false,
      private: m['private'] as bool? ?? false,
    );
  }
}
