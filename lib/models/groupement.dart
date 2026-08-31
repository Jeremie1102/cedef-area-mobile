import '../core/constants/app_constants.dart';

class Groupement {
  final int? id;
  final String localId;
  final int? serverId;
  final int secteurId;
  final String nom;
  final String? code;
  final String? description;
  final bool isActive;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Groupement({
    this.id,
    required this.localId,
    this.serverId,
    required this.secteurId,
    required this.nom,
    this.code,
    this.description,
    this.isActive = true,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Groupement copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? secteurId,
    String? nom,
    String? code,
    String? description,
    bool? isActive,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Groupement(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      secteurId: secteurId ?? this.secteurId,
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
      'secteur_id': secteurId,
      'nom': nom,
      'code': code,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Groupement.fromMap(Map<String, dynamic> map) {
    return Groupement(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      secteurId: map['secteur_id'] as int,
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
