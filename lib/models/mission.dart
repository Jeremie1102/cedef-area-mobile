import '../core/constants/app_constants.dart';

class Mission {
  final int? id;
  final String localId;
  final int? serverId;
  final String titre;
  final String? description;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final int? secteurId;
  final MissionStatus statut;
  final String? instructions;

  /// Horodatages du cycle de vie de la mission, enregistrés localement à
  /// chaque changement de statut (voir `MissionService`). Une mission peut
  /// être mise en pause puis reprise plusieurs fois : seuls le dernier
  /// horodatage de pause et de reprise sont conservés, dans cette première
  /// étape qui ne calcule pas encore de durée cumulée.
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? endedAt;

  /// Observation simple saisie par l'animateur en terminant la mission.
  final String? endObservation;

  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Mission({
    this.id,
    required this.localId,
    this.serverId,
    required this.titre,
    this.description,
    this.dateDebut,
    this.dateFin,
    this.secteurId,
    this.statut = MissionStatus.pending,
    this.instructions,
    this.startedAt,
    this.pausedAt,
    this.resumedAt,
    this.endedAt,
    this.endObservation,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Mission copyWith({
    int? id,
    String? localId,
    int? serverId,
    String? titre,
    String? description,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? secteurId,
    MissionStatus? statut,
    String? instructions,
    DateTime? startedAt,
    DateTime? pausedAt,
    DateTime? resumedAt,
    DateTime? endedAt,
    String? endObservation,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Mission(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      secteurId: secteurId ?? this.secteurId,
      statut: statut ?? this.statut,
      instructions: instructions ?? this.instructions,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      resumedAt: resumedAt ?? this.resumedAt,
      endedAt: endedAt ?? this.endedAt,
      endObservation: endObservation ?? this.endObservation,
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
      'titre': titre,
      'description': description,
      'date_debut': dateDebut?.toIso8601String(),
      'date_fin': dateFin?.toIso8601String(),
      'secteur_id': secteurId,
      'statut': statut.value,
      'instructions': instructions,
      'started_at': startedAt?.toIso8601String(),
      'paused_at': pausedAt?.toIso8601String(),
      'resumed_at': resumedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'end_observation': endObservation,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      titre: map['titre'] as String,
      description: map['description'] as String?,
      dateDebut: map['date_debut'] != null ? DateTime.parse(map['date_debut'] as String) : null,
      dateFin: map['date_fin'] != null ? DateTime.parse(map['date_fin'] as String) : null,
      secteurId: map['secteur_id'] as int?,
      statut: MissionStatusX.fromValue(map['statut'] as String?),
      instructions: map['instructions'] as String?,
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at'] as String) : null,
      pausedAt: map['paused_at'] != null ? DateTime.parse(map['paused_at'] as String) : null,
      resumedAt: map['resumed_at'] != null ? DateTime.parse(map['resumed_at'] as String) : null,
      endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at'] as String) : null,
      endObservation: map['end_observation'] as String?,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
