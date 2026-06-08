import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ClubModel extends Equatable {
  const ClubModel({
    required this.id,
    required this.name,
    required this.city,
    required this.adminId,
    required this.inviteCode,
    this.logoUrl,
    this.members = const [],
    this.totalZones = 0,
    this.totalKm = 0.0,
  });

  final String id;
  final String name;
  final String city;
  final String adminId;
  final String inviteCode;
  final String? logoUrl;
  final List<String> members;
  final int    totalZones;
  final double totalKm;

  int get memberCount => members.length;

  factory ClubModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ClubModel(
      id:          doc.id,
      name:        d['name']       as String,
      city:        d['city']       as String,
      adminId:     d['adminId']    as String,
      inviteCode:  d['inviteCode'] as String,
      logoUrl:     d['logoUrl']    as String?,
      members:     List<String>.from(d['members'] as List? ?? []),
      totalZones:  (d['totalZones'] as num?)?.toInt() ?? 0,
      totalKm:     (d['totalKm']    as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name':       name,
    'city':       city,
    'adminId':    adminId,
    'inviteCode': inviteCode,
    if (logoUrl != null) 'logoUrl': logoUrl,
    'members':    members,
    'totalZones': totalZones,
    'totalKm':    totalKm,
  };

  @override
  List<Object?> get props => [id, name, totalZones, totalKm];
}
