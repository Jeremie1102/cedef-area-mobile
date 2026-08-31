import '../core/constants/app_constants.dart';

/// Table de liaison entre un [Cld] et les utilisateurs qui en ont la charge
/// (relation plusieurs-à-plusieurs : un utilisateur peut être en charge de
/// plusieurs CLD, et un CLD peut à terme être suivi par plusieurs agents).
class UserCld {
  final int? id;
  final String localId;
  final int? serverId;
  final int userId;
  final int cldId;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserCld({
    this.id,
    required this.localId,
    this.serverId,
    required this.userId,
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
      'user_id': userId,
      'cld_id': cldId,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserCld.fromMap(Map<String, dynamic> map) {
    return UserCld(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      userId: map['user_id'] as int,
      cldId: map['cld_id'] as int,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
