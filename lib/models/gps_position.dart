import '../core/constants/app_constants.dart';

/// Une position GPS enregistrée pour un utilisateur pendant une mission.
///
/// Enregistrée localement par `GpsService` à intervalle régulier pendant
/// qu'une mission est `in_progress` (voir `MissionService`), afin de
/// reconstituer le parcours général de l'agent — pas un suivi continu.
class GpsPosition {
  final int? id;
  final String localId;
  final int? serverId;
  final int missionId;
  final int userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;
  final SyncStatus syncStatus;
  final DateTime createdAt;

  const GpsPosition({
    this.id,
    required this.localId,
    this.serverId,
    required this.missionId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.recordedAt,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
  });

  GpsPosition copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? missionId,
    int? userId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
    SyncStatus? syncStatus,
    DateTime? createdAt,
  }) {
    return GpsPosition(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      missionId: missionId ?? this.missionId,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      recordedAt: recordedAt ?? this.recordedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'server_id': serverId,
      'mission_id': missionId,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'recorded_at': recordedAt.toIso8601String(),
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GpsPosition.fromMap(Map<String, dynamic> map) {
    return GpsPosition(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      missionId: map['mission_id'] as int,
      userId: map['user_id'] as int,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as double?,
      altitude: map['altitude'] as double?,
      speed: map['speed'] as double?,
      heading: map['heading'] as double?,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.parse(map['recorded_at'] as String),
    );
  }
}
