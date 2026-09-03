import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/gps_position.dart';

/// Accès aux données locales de la table `gps_positions`.
class GpsRepository {
  Future<int> insert(GpsPosition position) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.gpsPositions, position.toMap()..remove('id'));
  }

  /// Positions d'une mission, de la plus ancienne à la plus récente (ordre
  /// nécessaire pour reconstituer le parcours et calculer une distance).
  Future<List<GpsPosition>> findByMission(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.gpsPositions,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(GpsPosition.fromMap).toList();
  }

  /// Positions enregistrées par un utilisateur, toutes missions confondues.
  Future<List<GpsPosition>> findByUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.gpsPositions,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(GpsPosition.fromMap).toList();
  }

  Future<GpsPosition?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.gpsPositions, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return GpsPosition.fromMap(rows.first);
  }

  /// Dernière position connue d'une mission, ou `null` si aucune n'a encore
  /// été enregistrée.
  Future<GpsPosition?> findLastForMission(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.gpsPositions,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GpsPosition.fromMap(rows.first);
  }

  Future<List<GpsPosition>> findPendingSync() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.gpsPositions,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
    );
    return rows.map(GpsPosition.fromMap).toList();
  }

  Future<int> countPendingSync() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.gpsPositions} WHERE sync_status = ?',
      [SyncStatus.pending.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Nombre de positions `pending` ou `failed` — pour le bandeau « Positions
  /// en attente » de l'écran « Mes parcours » (section 31).
  Future<int> countPendingOrFailedSync() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.gpsPositions} WHERE sync_status IN (?, ?)',
      [SyncStatus.pending.value, SyncStatus.failed.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Positions à (re)synchroniser : `pending` (jamais envoyées) et `failed`
  /// (tentative précédente en échec) — jamais `syncing`, qui n'existe qu'entre
  /// le moment où `GpsSyncService` commence un lot et celui où il se termine.
  /// Ordonnées par [recordedAt] croissant : l'ordre chronologique de capture
  /// doit être préservé lors de la constitution des lots (section 23/24).
  Future<List<GpsPosition>> findPendingOrFailedSync() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.gpsPositions,
      where: 'sync_status IN (?, ?)',
      whereArgs: [SyncStatus.pending.value, SyncStatus.failed.value],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(GpsPosition.fromMap).toList();
  }

  /// Fait passer des positions identifiées par leur `id` local au statut
  /// [status] (utilisé pour `syncing`/`failed`, appliqués à tout un lot en une
  /// fois par `GpsSyncService`). Ne fait rien si [ids] est vide.
  Future<void> updateSyncStatus(List<int> ids, SyncStatus status) async {
    if (ids.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.rawUpdate(
      'UPDATE ${DatabaseTables.gpsPositions} SET sync_status = ? WHERE id IN ($placeholders)',
      [status.value, ...ids],
    );
  }

  /// Confirme la synchronisation d'une position : statut `synced` et
  /// identifiant attribué par le serveur.
  Future<void> markSynced({required int id, required int serverId}) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseTables.gpsPositions,
      {'sync_status': SyncStatus.synced.value, 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Réinitialise les positions GPS restées à l'état `syncing` (ex: crash ou
  /// interruption réseau) en les remettant à `pending`.
  Future<int> resetStaleSyncingStates() async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.gpsPositions,
      {'sync_status': SyncStatus.pending.value},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.syncing.value],
    );
  }

  /// Une ligne par mission ayant au moins une position enregistrée par cet
  /// utilisateur (nombre de positions, bornes temporelles, nombre encore
  /// `pending`), du parcours le plus récent au plus ancien — pour l'écran
  /// « Mes parcours ». `GpsService.getMyTracks` complète chaque ligne avec la
  /// mission et la distance estimée.
  Future<List<Map<String, Object?>>> findTrackSummaryRowsByUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
      SELECT mission_id AS mission_id,
        COUNT(*) AS position_count,
        MIN(recorded_at) AS first_recorded_at,
        MAX(recorded_at) AS last_recorded_at,
        SUM(CASE WHEN sync_status = ? THEN 1 ELSE 0 END) AS pending_count
      FROM ${DatabaseTables.gpsPositions}
      WHERE user_id = ?
      GROUP BY mission_id
      ORDER BY MAX(recorded_at) DESC
      ''',
      [SyncStatus.pending.value, userId],
    );
  }
}
