import 'package:flutter/material.dart';

/// Categoría del logro.
enum AchievementCategory {
  distance,
  consistency,
  exploration,
  challenges,
  strava
}

/// Rareza — SOLO visual, sin valor económico. Depende de la dificultad objetiva
/// del hito, nunca de azar.
enum AchievementRarity { common, uncommon, rare, epic, legendary }

/// Métrica del corredor sobre la que se mide el criterio de un logro.
enum AchievementMetric {
  totalKm,
  longestRunKm,
  distinctStreets,
  distinctNeighborhoods,
  distinctCities,
  distinctCountries,
  currentStreakDays,
  activeWeeks,
  activeMonths,
  activeMonthsInARow,
  challengesCompleted,
  legendaryChallengesCompleted,
  monthlyChallengeSweeps,
  stravaImports,
  stravaConnectedDays,
  shoesRegistered,
  retiredShoes,
  shoesInRotation,
  singleShoeMaxKm,
  totalShoeKm,
  zonesConquered,
  sharedConquests,
  citiesDocumented,
}

/// Definición inmutable de un logro (hito permanente).
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.rarity,
    required this.metric,
    required this.target,
  });

  /// Identificador ESTABLE (no cambiar nunca: es la clave de desbloqueo).
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final IconData icon;
  final AchievementRarity rarity;

  /// Criterio de desbloqueo: la [metric] debe alcanzar [target].
  final AchievementMetric metric;
  final num target;
}

/// Snapshot de las métricas del corredor para evaluar los logros.
/// Es un valor plano y testeable; lo alimenta la capa de datos.
class RunnerStats {
  const RunnerStats({
    this.totalKm = 0,
    this.longestRunKm = 0,
    this.distinctStreets = 0,
    this.distinctNeighborhoods = 0,
    this.distinctCities = 0,
    this.distinctCountries = 0,
    this.currentStreakDays = 0,
    this.activeWeeks = 0,
    this.activeMonths = 0,
    this.activeMonthsInARow = 0,
    this.challengesCompleted = 0,
    this.legendaryChallengesCompleted = 0,
    this.monthlyChallengeSweeps = 0,
    this.stravaImports = 0,
    this.stravaConnectedDays = 0,
    this.shoesRegistered = 0,
    this.retiredShoes = 0,
    this.shoesInRotation = 0,
    this.singleShoeMaxKm = 0,
    this.totalShoeKm = 0,
    this.zonesConquered = 0,
    this.sharedConquests = 0,
    this.citiesDocumented = 0,
  });

  final double totalKm;
  final double longestRunKm;
  final int distinctStreets;
  final int distinctNeighborhoods;
  final int distinctCities;
  final int distinctCountries;
  final int currentStreakDays;
  final int activeWeeks;
  final int activeMonths;
  final int activeMonthsInARow;
  final int challengesCompleted;
  final int legendaryChallengesCompleted;
  final int monthlyChallengeSweeps;
  final int stravaImports;
  final int stravaConnectedDays;
  final int shoesRegistered;
  final int retiredShoes;
  final int shoesInRotation;
  final double singleShoeMaxKm;
  final double totalShoeKm;
  final int zonesConquered;
  final int sharedConquests;
  final int citiesDocumented;

  num valueOf(AchievementMetric metric) => switch (metric) {
        AchievementMetric.totalKm => totalKm,
        AchievementMetric.longestRunKm => longestRunKm,
        AchievementMetric.distinctStreets => distinctStreets,
        AchievementMetric.distinctNeighborhoods => distinctNeighborhoods,
        AchievementMetric.distinctCities => distinctCities,
        AchievementMetric.distinctCountries => distinctCountries,
        AchievementMetric.currentStreakDays => currentStreakDays,
        AchievementMetric.activeWeeks => activeWeeks,
        AchievementMetric.activeMonths => activeMonths,
        AchievementMetric.activeMonthsInARow => activeMonthsInARow,
        AchievementMetric.challengesCompleted => challengesCompleted,
        AchievementMetric.legendaryChallengesCompleted =>
          legendaryChallengesCompleted,
        AchievementMetric.monthlyChallengeSweeps => monthlyChallengeSweeps,
        AchievementMetric.stravaImports => stravaImports,
        AchievementMetric.stravaConnectedDays => stravaConnectedDays,
        AchievementMetric.shoesRegistered => shoesRegistered,
        AchievementMetric.retiredShoes => retiredShoes,
        AchievementMetric.shoesInRotation => shoesInRotation,
        AchievementMetric.singleShoeMaxKm => singleShoeMaxKm,
        AchievementMetric.totalShoeKm => totalShoeKm,
        AchievementMetric.zonesConquered => zonesConquered,
        AchievementMetric.sharedConquests => sharedConquests,
        AchievementMetric.citiesDocumented => citiesDocumented,
      };
}

/// Estado de un logro para un corredor: progreso + desbloqueo.
class AchievementStatus {
  const AchievementStatus({
    required this.achievement,
    required this.current,
    required this.unlockedAt,
  });

  final Achievement achievement;
  final num current;
  final DateTime? unlockedAt; // null = bloqueado (aún no desbloqueado)

  bool get unlocked => unlockedAt != null;
  bool get criterionMet => current >= achievement.target;

  double get progress => achievement.target == 0
      ? 1.0
      : (current / achievement.target).clamp(0.0, 1.0);
}
