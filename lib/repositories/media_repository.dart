import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/media_batch.dart';
import '../models/media_item.dart';

/// Résumé d'un lot pour l'écran « Mes médias » : le lot, le nombre de photos
/// qu'il contient et le chemin de la première (utilisée comme aperçu),
/// calculés en une seule requête pour éviter de recharger chaque lot.
class MediaBatchSummary {
  final MediaBatch batch;
  final int itemCount;
  final String? coverPath;
  final String? cldName;
  final String? villageName;

  const MediaBatchSummary({
    required this.batch,
    required this.itemCount,
    this.coverPath,
    this.cldName,
    this.villageName,
  });
}

/// Accès aux données locales des tables `media_batches` et `media_items`,
/// sur le même principe que `MissionRepository` pour `missions` /
/// `mission_users`.
class MediaRepository {
  // --- Lots (media_batches) --------------------------------------------------

  Future<int> insertBatch(MediaBatch batch) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.mediaBatches, batch.toMap()..remove('id'));
  }

  Future<int> updateBatch(MediaBatch batch) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.mediaBatches,
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  Future<int> deleteBatch(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.delete(DatabaseTables.mediaBatches, where: 'id = ?', whereArgs: [id]);
  }

  Future<MediaBatch?> getBatchById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.mediaBatches,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MediaBatch.fromMap(rows.first);
  }

  Future<List<MediaBatch>> getBatchesByMission(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.mediaBatches,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'created_at DESC',
    );
    return rows.map(MediaBatch.fromMap).toList();
  }

  Future<List<MediaBatch>> getPendingSyncBatches() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.mediaBatches,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
    );
    return rows.map(MediaBatch.fromMap).toList();
  }

  /// Lots à (re)synchroniser : `pending` (jamais envoyés) et `failed` (une
  /// tentative précédente a échoué, voir `MediaSyncService`) — un lot en échec
  /// doit pouvoir être renvoyé plus tard sans action autre que relancer la
  /// synchronisation (section 3/25 du cahier des charges : « Réessayer »).
  Future<List<MediaBatch>> getPendingOrFailedSyncBatches() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.mediaBatches,
      where: 'sync_status IN (?, ?)',
      whereArgs: [SyncStatus.pending.value, SyncStatus.failed.value],
      orderBy: 'created_at ASC',
    );
    return rows.map(MediaBatch.fromMap).toList();
  }

  Future<int> countPendingSyncBatches() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.mediaBatches} WHERE sync_status = ?',
      [SyncStatus.pending.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Nombre de lots `pending` ou `failed` — pour l'écran d'état de
  /// synchronisation, où un lot en échec doit rester visible comme
  /// nécessitant une action, pas comme déjà traité.
  Future<int> countPendingOrFailedSyncBatches() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.mediaBatches} WHERE sync_status IN (?, ?)',
      [SyncStatus.pending.value, SyncStatus.failed.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Nombre de photos (toutes tables confondues) en attente de
  /// synchronisation, pour l'écran d'état de synchronisation.
  Future<int> countPendingSyncItems() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.mediaItems} WHERE sync_status = ?',
      [SyncStatus.pending.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Lots de l'utilisateur avec le nombre de photos et un aperçu, pour
  /// l'écran « Mes médias ».
  Future<List<MediaBatchSummary>> getBatchSummariesByUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT b.*,
        (SELECT COUNT(*) FROM ${DatabaseTables.mediaItems} i WHERE i.batch_id = b.id) AS item_count,
        (SELECT local_path FROM ${DatabaseTables.mediaItems} i
           WHERE i.batch_id = b.id ORDER BY i.sort_order ASC LIMIT 1) AS cover_path,
        c.nom AS cld_nom,
        v.nom AS village_nom
      FROM ${DatabaseTables.mediaBatches} b
      LEFT JOIN ${DatabaseTables.clds} c ON b.cld_id = c.id
      LEFT JOIN ${DatabaseTables.villages} v ON b.village_id = v.id
      WHERE b.user_id = ?
      ORDER BY b.created_at DESC
      ''',
      [userId],
    );

    return rows
        .map(
          (row) => MediaBatchSummary(
            batch: MediaBatch.fromMap(row),
            itemCount: (row['item_count'] as int?) ?? 0,
            coverPath: row['cover_path'] as String?,
            cldName: row['cld_nom'] as String?,
            villageName: row['village_nom'] as String?,
          ),
        )
        .toList();
  }

  // --- Photos du lot (media_items) --------------------------------------------

  Future<int> insertItem(MediaItem item) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.mediaItems, item.toMap()..remove('id'));
  }

  Future<List<MediaItem>> getItemsByBatch(int batchId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.mediaItems,
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }

  Future<int> updateItem(MediaItem item) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.mediaItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<MediaItem?> getItemById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.mediaItems, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return MediaItem.fromMap(rows.first);
  }

  /// Retire une photo d'un lot. Ne supprime que la ligne locale (et, côté
  /// service, la copie de travail associée) : la photo originale de la
  /// galerie n'est jamais concernée.
  Future<int> removeItem(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.delete(DatabaseTables.mediaItems, where: 'id = ?', whereArgs: [id]);
  }
}
