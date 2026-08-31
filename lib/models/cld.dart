import '../core/constants/app_constants.dart';

/// CLD : Comité Local de Développement, rattaché à un groupement et composé
/// de plusieurs villages (Secteur > Groupement > CLD > Village).
///
/// L'affectation d'un CLD à un ou plusieurs utilisateurs se fait exclusivement
/// via la table d'association `user_clds` (voir `CldRepository`) : ce modèle
/// ne porte donc pas de champ "responsable" unique.
class Cld {
  final int? id;
  final String localId;
  final int? serverId;
  final int groupementId;
  final String nom;
  final String? code;
  final String? description;
  final bool isActive;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cld({
    this.id,
    required this.localId,
    this.serverId,
    required this.groupementId,
    required this.nom,
    this.code,
    this.description,
    this.isActive = true,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Cld copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? groupementId,
    String? nom,
    String? code,
    String? description,
    bool? isActive,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cld(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      groupementId: groupementId ?? this.groupementId,
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
      'groupement_id': groupementId,
      'nom': nom,
      'code': code,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Cld.fromMap(Map<String, dynamic> map) {
    return Cld(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      groupementId: map['groupement_id'] as int,
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
