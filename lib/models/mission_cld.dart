import '../core/constants/app_constants.dart';

/// Table de liaison entre une [Mission] et les CLD qu'elle concerne
/// (relation plusieurs-à-plusieurs) : une mission peut couvrir un ou
/// plusieurs CLD, chacun avec ses propres villages (voir `Village.cldId`).
class MissionCld {
  final int? id;
  final String localId;
  final int? serverId;
  final int missionId;
  final int cldId;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MissionCld({
    this.id,
    required this.localId,
    this.serverId,
    required this.missionId,
    required this.cldId,
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
      'cld_id': cldId,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MissionCld.fromMap(Map<String, dynamic> map) {
    return MissionCld(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      missionId: map['mission_id'] as int,
      cldId: map['cld_id'] as int,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
