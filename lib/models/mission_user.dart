import '../core/constants/app_constants.dart';

/// Table de liaison entre une [Mission] et les utilisateurs auxquels elle
/// est attribuée (relation plusieurs-à-plusieurs).
class MissionUser {
  final int? id;
  final String localId;
  final int? serverId;
  final int missionId;
  final int userId;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MissionUser({
    this.id,
    required this.localId,
    this.serverId,
    required this.missionId,
    required this.userId,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'server_id': serverId,
      'mission_id': missionId,
      'user_id': userId,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MissionUser.fromMap(Map<String, dynamic> map) {
    return MissionUser(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      missionId: map['mission_id'] as int,
      userId: map['user_id'] as int,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
