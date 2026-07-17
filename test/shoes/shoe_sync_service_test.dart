// ignore_for_file: prefer_const_declarations
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/shoes/running_shoe.dart';
import 'package:runrace/shoes/shoe_activity_link.dart';
import 'package:runrace/shoes/shoe_sync_service.dart';
import 'package:runrace/shoes/strava_gear.dart';

void main() {
  const sync = ShoeSyncService();
  final now = DateTime(2026, 1, 1);

  test('importa zapatilla nueva y asocia actividad con su km', () {
    final plan = sync.plan(
      userId: 'u',
      gears: const [StravaGear(id: 'g1', name: 'Nike Pegasus 40')],
      activities: const [
        StravaRunActivity(id: 'a1', distanceMeters: 5000, gearId: 'g1'),
      ],
      existingShoes: const [],
      existingLinks: const [],
      now: now,
    );
    final shoe = plan.shoes.single;
    expect(shoe.id, 'strava_g1');
    expect(shoe.brand, 'Nike');
    expect(shoe.syncedDistanceMeters, 5000);
    expect(plan.links.single.shoeId, 'strava_g1');
  });

  test('idempotente: reprocesar la misma actividad no duplica km', () {
    final gears = const [StravaGear(id: 'g1', name: 'Asics')];
    final acts = const [
      StravaRunActivity(id: 'a1', distanceMeters: 5000, gearId: 'g1')
    ];
    var plan = sync.plan(
        userId: 'u',
        gears: gears,
        activities: acts,
        existingShoes: const [],
        existingLinks: const [],
        now: now);
    // Segunda sync con las mismas zapatillas/actividades existentes.
    plan = sync.plan(
      userId: 'u',
      gears: gears,
      activities: acts,
      existingShoes: plan.shoes,
      existingLinks: plan.links,
      now: now,
    );
    final synced = plan.links
        .where((l) => l.shoeId == 'strava_g1')
        .fold<double>(0, (s, l) => s + l.distanceMeters);
    expect(synced, 5000); // un solo enlace, sin duplicar
  });

  test('actividad sin gear va a "unassigned"', () {
    final plan = sync.plan(
      userId: 'u',
      gears: const [],
      activities: const [
        StravaRunActivity(id: 'a1', distanceMeters: 4000, gearId: null)
      ],
      existingShoes: const [],
      existingLinks: const [],
      now: now,
    );
    expect(plan.links.single.shoeId, 'unassigned');
  });

  test('no sobrescribe marca editada de una zapatilla existente', () {
    final existing = RunningShoe(
      id: 'strava_g1',
      userId: 'u',
      source: ShoeSource.merged,
      stravaGearId: 'g1',
      brand: 'Marca corregida',
      createdAt: now,
      updatedAt: now,
    );
    final plan = sync.plan(
      userId: 'u',
      gears: const [StravaGear(id: 'g1', name: 'Nike Otro')],
      activities: const [
        StravaRunActivity(id: 'a1', distanceMeters: 3000, gearId: 'g1')
      ],
      existingShoes: [existing],
      existingLinks: const [],
      now: now,
    );
    // Se actualiza km, pero la marca del usuario se conserva.
    final updated = plan.shoes.firstWhere((s) => s.id == 'strava_g1');
    expect(updated.brand, 'Marca corregida');
    expect(updated.syncedDistanceMeters, 3000);
  });

  test('reasignación manual de actividad se respeta en re-sync', () {
    final manualLink = const ShoeActivityLink(
      userId: 'u',
      activityId: 'a1',
      shoeId: 'strava_g2', // el usuario la movió a otra zapatilla
      distanceMeters: 3000,
      source: 'manual',
    );
    final plan = sync.plan(
      userId: 'u',
      gears: const [StravaGear(id: 'g1', name: 'X')],
      activities: const [
        StravaRunActivity(id: 'a1', distanceMeters: 3000, gearId: 'g1')
      ],
      existingShoes: const [],
      existingLinks: [manualLink],
      now: now,
    );
    expect(plan.links.single.shoeId, 'strava_g2'); // respeta lo manual
  });
}
