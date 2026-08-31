import '../core/constants/app_constants.dart';

/// Un village, dernier échelon de la hiérarchie géographique, rattaché à un
/// CLD (Secteur > Groupement > CLD > Village).
class Village {
  final int? id;
  final String localId;
  final int? serverId;
  final int cldId;
  final String nom;
  final String? code;
  final String? description;
  final bool isActive;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Village({
    this.id,
    required this.localId,
    this.serverId,
    required this.cldId,
    required this.nom,
    this.code,
    this.description,
    this.isActive = true,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Village copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? cldId,
    String? nom,
    String? code,
    String? description,
    bool? isActive,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Village(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      cldId: cldId ?? this.cldId,
      nom: nom ?? this.nom,
      code: code ?? this.code,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'server_id': serverId,
      'cld_id': cldId,
      'nom': nom,
      'code': code,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Village.fromMap(Map<String, dynamic> map) {
    return Village(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      cldId: map['cld_id'] as int,
      nom: map['nom'] as String,
      code: map['code'] as String?,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
