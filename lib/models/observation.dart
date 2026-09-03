import '../core/constants/app_constants.dart';

/// Constat ou observation structurée saisie par l'agent pendant une mission de terrain.
///
/// Permet de documenter des constats factuels géolocalisés (infrastructure,
/// accessibilité, environnement, gouvernance, autre) avec niveau de gravité
/// (information, attention, critique), description détaillée, et horodatage UTC.
///
/// Modèle 100% offline-first : chaque observation possède un `localId` UUID
/// généré sur le téléphone et un `syncStatus` pour sa propagation ultérieure.
class Observation {
  final int? id;
  final String localId;
  final int? serverId;
  final int missionId;
  final String missionLocalId;
  final int? missionServerId;
  final int userId;

  final ObservationCategory category;
  final ObservationSeverity severity;

  final String title;
  final String description;

  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? accuracy;

  final DateTime recordedAt;

  final SyncStatus syncStatus;
  final int syncAttempts;
  final String? lastSyncError;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Observation({
    this.id,
    required this.localId,
    this.serverId,
    required this.missionId,
    required this.missionLocalId,
    this.missionServerId,
    required this.userId,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    required this.recordedAt,
    this.syncStatus = SyncStatus.pending,
    this.syncAttempts = 0,
    this.lastSyncError,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasGps => latitude != null && longitude != null;

  Observation copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? missionId,
    String? missionLocalId,
    int? missionServerId,
    int? userId,
    ObservationCategory? category,
    ObservationSeverity? severity,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    DateTime? recordedAt,
    SyncStatus? syncStatus,
    int? syncAttempts,
    String? lastSyncError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Observation(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      missionId: missionId ?? this.missionId,
      missionLocalId: missionLocalId ?? this.missionLocalId,
      missionServerId: missionServerId ?? this.missionServerId,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      recordedAt: recordedAt ?? this.recordedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'server_id': serverId,
      'mission_id': missionId,
      'mission_local_id': missionLocalId,
      'mission_server_id': missionServerId,
      'user_id': userId,
      'category': category.code,
      'severity': severity.code,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt.toIso8601String(),
      'sync_status': syncStatus.value,
      'sync_attempts': syncAttempts,
      'last_sync_error': lastSyncError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Observation.fromMap(Map<String, dynamic> map) {
    return Observation(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      missionId: map['mission_id'] as int,
      missionLocalId: map['mission_local_id'] as String,
      missionServerId: map['mission_server_id'] as int?,
      userId: map['user_id'] as int,
      category: ObservationCategoryX.fromCode(map['category'] as String?),
      severity: ObservationSeverityX.fromCode(map['severity'] as String?),
      title: map['title'] as String,
      description: map['description'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      syncAttempts: map['sync_attempts'] as int? ?? 0,
      lastSyncError: map['last_sync_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
