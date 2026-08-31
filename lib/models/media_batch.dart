import '../core/constants/app_constants.dart';

/// Un lot de médias : plusieurs photos sélectionnées par l'animateur dans sa
/// galerie pour illustrer une même activité de terrain.
///
/// Toutes les informations de contexte (activité, lieu, description, GPS)
/// sont portées par le lot, pas par chaque photo individuellement — voir
/// [MediaItem] pour les fichiers eux-mêmes.
///
/// `status` réutilise [MediaValidationStatus] (pending/validated/rejected) :
/// c'est le statut de validation du lot par le responsable des médias.
/// `syncStatus` reste le statut technique de synchronisation avec Laravel.
class MediaBatch {
  final int? id;
  final String localId;
  final int? serverId;
  final int userId;
  final int? missionId;
  final int? secteurId;
  final int? groupementId;
  final int? cldId;
  final int? villageId;
  final String? activity;
  final String? description;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final DateTime capturedAt;
  final MediaValidationStatus status;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaBatch({
    this.id,
    required this.localId,
    this.serverId,
    required this.userId,
    this.missionId,
    this.secteurId,
    this.groupementId,
    this.cldId,
    this.villageId,
    this.activity,
    this.description,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    required this.capturedAt,
    this.status = MediaValidationStatus.pending,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  MediaBatch copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? userId,
    int? missionId,
    int? secteurId,
    int? groupementId,
    int? cldId,
    int? villageId,
    String? activity,
    String? description,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    DateTime? capturedAt,
    MediaValidationStatus? status,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaBatch(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      missionId: missionId ?? this.missionId,
      secteurId: secteurId ?? this.secteurId,
      groupementId: groupementId ?? this.groupementId,
      cldId: cldId ?? this.cldId,
      villageId: villageId ?? this.villageId,
      activity: activity ?? this.activity,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      capturedAt: capturedAt ?? this.capturedAt,
      status: status ?? this.status,
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
      'user_id': userId,
      'mission_id': missionId,
      'secteur_id': secteurId,
      'groupement_id': groupementId,
      'cld_id': cldId,
      'village_id': villageId,
      'activity': activity,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'captured_at': capturedAt.toIso8601String(),
      'status': status.value,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MediaBatch.fromMap(Map<String, dynamic> map) {
    return MediaBatch(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      userId: map['user_id'] as int,
      missionId: map['mission_id'] as int?,
      secteurId: map['secteur_id'] as int?,
      groupementId: map['groupement_id'] as int?,
      cldId: map['cld_id'] as int?,
      villageId: map['village_id'] as int?,
      activity: map['activity'] as String?,
      description: map['description'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      gpsAccuracy: map['gps_accuracy'] as double?,
      capturedAt: DateTime.parse(map['captured_at'] as String),
      status: MediaValidationStatusX.fromValue(map['status'] as String?),
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
