import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme.dart';

class MockRunner {
  const MockRunner({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.zones,
    required this.km,
    required this.level,
    required this.color,
    required this.route,
  });

  final String id;
  final String name;
  final String subtitle;
  final int zones;
  final double km;
  final int level;
  final Color color;
  final List<LatLng> route;
}

const mockRunners = [
  MockRunner(
    id: 'mock-jc',
    name: 'Jpedrero Run Club',
    subtitle: 'Madrid Centro',
    zones: 20,
    km: 82.4,
    level: 9,
    color: AppColors.gold,
    route: [
      LatLng(40.4183, -3.7058),
      LatLng(40.4198, -3.7028),
      LatLng(40.4189, -3.6992),
      LatLng(40.4164, -3.6998),
      LatLng(40.4154, -3.7031),
      LatLng(40.4169, -3.7060),
      LatLng(40.4183, -3.7058),
    ],
  ),
  MockRunner(
    id: 'mock-lucia',
    name: 'Lucia Torres',
    subtitle: 'Retiro',
    zones: 18,
    km: 76.8,
    level: 8,
    color: AppColors.accent,
    route: [
      LatLng(40.4152, -3.6889),
      LatLng(40.4185, -3.6876),
      LatLng(40.4202, -3.6847),
      LatLng(40.4178, -3.6814),
      LatLng(40.4144, -3.6828),
      LatLng(40.4127, -3.6863),
      LatLng(40.4152, -3.6889),
    ],
  ),
  MockRunner(
    id: 'mock-mario',
    name: 'Mario Vega',
    subtitle: 'Arganzuela',
    zones: 16,
    km: 70.1,
    level: 8,
    color: AppColors.cyan,
    route: [
      LatLng(40.4078, -3.7063),
      LatLng(40.4099, -3.7022),
      LatLng(40.4086, -3.6978),
      LatLng(40.4053, -3.6973),
      LatLng(40.4038, -3.7019),
      LatLng(40.4051, -3.7068),
      LatLng(40.4078, -3.7063),
    ],
  ),
  MockRunner(
    id: 'mock-nerea',
    name: 'Nerea Gomez',
    subtitle: 'Chamberi',
    zones: 15,
    km: 67.5,
    level: 7,
    color: AppColors.green,
    route: [
      LatLng(40.4315, -3.7078),
      LatLng(40.4337, -3.7049),
      LatLng(40.4321, -3.7009),
      LatLng(40.4288, -3.7018),
      LatLng(40.4276, -3.7055),
      LatLng(40.4298, -3.7085),
      LatLng(40.4315, -3.7078),
    ],
  ),
  MockRunner(
    id: 'mock-alvaro',
    name: 'Alvaro Ruiz',
    subtitle: 'Malasana',
    zones: 13,
    km: 61.2,
    level: 7,
    color: Color(0xFF9C7CFF),
    route: [
      LatLng(40.4253, -3.7072),
      LatLng(40.4269, -3.7037),
      LatLng(40.4252, -3.7008),
      LatLng(40.4225, -3.7014),
      LatLng(40.4214, -3.7048),
      LatLng(40.4231, -3.7077),
      LatLng(40.4253, -3.7072),
    ],
  ),
  MockRunner(
    id: 'mock-carmen',
    name: 'Carmen Sanz',
    subtitle: 'Lavapies',
    zones: 12,
    km: 57.9,
    level: 6,
    color: Color(0xFFFF7A45),
    route: [
      LatLng(40.4117, -3.7041),
      LatLng(40.4126, -3.7005),
      LatLng(40.4102, -3.6978),
      LatLng(40.4078, -3.6996),
      LatLng(40.4076, -3.7032),
      LatLng(40.4099, -3.7052),
      LatLng(40.4117, -3.7041),
    ],
  ),
  MockRunner(
    id: 'mock-diego',
    name: 'Diego Marin',
    subtitle: 'Salamanca',
    zones: 11,
    km: 52.6,
    level: 6,
    color: Color(0xFF46C2FF),
    route: [
      LatLng(40.4248, -3.6899),
      LatLng(40.4279, -3.6875),
      LatLng(40.4266, -3.6834),
      LatLng(40.4232, -3.6829),
      LatLng(40.4214, -3.6867),
      LatLng(40.4228, -3.6902),
      LatLng(40.4248, -3.6899),
    ],
  ),
  MockRunner(
    id: 'mock-ines',
    name: 'Ines Martin',
    subtitle: 'La Latina',
    zones: 10,
    km: 49.7,
    level: 5,
    color: Color(0xFFFF5FA2),
    route: [
      LatLng(40.4136, -3.7114),
      LatLng(40.4156, -3.7084),
      LatLng(40.4142, -3.7052),
      LatLng(40.4109, -3.7056),
      LatLng(40.4096, -3.7088),
      LatLng(40.4114, -3.7118),
      LatLng(40.4136, -3.7114),
    ],
  ),
  MockRunner(
    id: 'mock-pablo',
    name: 'Pablo Nieto',
    subtitle: 'Atocha',
    zones: 9,
    km: 43.3,
    level: 5,
    color: Color(0xFF7DD856),
    route: [
      LatLng(40.4092, -3.6937),
      LatLng(40.4117, -3.6908),
      LatLng(40.4102, -3.6869),
      LatLng(40.4069, -3.6876),
      LatLng(40.4059, -3.6915),
      LatLng(40.4074, -3.6942),
      LatLng(40.4092, -3.6937),
    ],
  ),
  MockRunner(
    id: 'mock-sara',
    name: 'Sara Cano',
    subtitle: 'Moncloa',
    zones: 8,
    km: 39.5,
    level: 4,
    color: Color(0xFFFFD166),
    route: [
      LatLng(40.4336, -3.7185),
      LatLng(40.4362, -3.7158),
      LatLng(40.4351, -3.7119),
      LatLng(40.4318, -3.7114),
      LatLng(40.4302, -3.7152),
      LatLng(40.4316, -3.7187),
      LatLng(40.4336, -3.7185),
    ],
  ),
];
