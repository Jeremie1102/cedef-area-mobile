/// Noms des tables et des colonnes communes de synchronisation.
///
/// Centraliser les noms ici évite les fautes de frappe dans les requêtes SQL
/// écrites à la main dans les repositories.
class DatabaseTables {
  DatabaseTables._();

  static const String users = 'users';
  static const String secteurs = 'secteurs';
  static const String groupements = 'groupements';
  static const String villages = 'villages';
  static const String clds = 'clds';
  static const String userClds = 'user_clds';
  static const String missions = 'missions';
  static const String missionUsers = 'mission_users';
  static const String missionClds = 'mission_clds';

  /// Ancienne table (une photo = une entité indépendante), supprimée par
  /// `MigrationV4` au profit de [mediaBatches]/[mediaItems]. Conservée ici
  /// uniquement parce que `MigrationV1` (historique, jamais modifiée) y
  /// fait encore référence.
  static const String medias = 'medias';
  static const String mediaBatches = 'media_batches';
  static const String mediaItems = 'media_items';
  static const String gpsPositions = 'gps_positions';
  static const String syncQueue = 'sync_queue';
  static const String syncMeta = 'sync_meta';
}

/// Colonnes communes de synchronisation présentes sur la plupart des tables.
class SyncColumns {
  SyncColumns._();

  static const String localId = 'local_id';
  static const String serverId = 'server_id';
  static const String syncStatus = 'sync_status';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}
