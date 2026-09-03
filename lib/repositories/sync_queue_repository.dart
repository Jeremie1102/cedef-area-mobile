import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/sync_queue_entry.dart';

/// Ordre de traitement des entités lors d'une synchronisation (voir section
/// 15 du cahier des charges) : le profil d'abord (les autres entités
/// dépendent de l'utilisateur côté serveur), puis les missions, puis les
/// données qu'elles produisent. Une entité absente de cette liste est traitée
/// en dernier (valeur par défaut ci-dessous).
const Map<String, int> _entityPriority = {
  DatabaseTables.users: 0,
  DatabaseTables.missions: 1,
  DatabaseTables.observations: 2,
  DatabaseTables.gpsPositions: 3,
  DatabaseTables.mediaBatches: 4,
  DatabaseTables.mediaItems: 5,
};

const int _defaultPriority = 99;

/// Accès aux données locales de `sync_queue` et de `sync_meta`.
///
/// Centralise toutes les opérations liées à la file d'attente de
/// synchronisation, pour que ni les écrans ni les autres services n'aient à
/// écrire de SQL directement (voir `MissionRepository`/`MediaRepository` pour
/// le même principe). [SyncService] est le seul consommateur métier de ce
/// repository.
class SyncQueueRepository {
  static const String _lastSyncedAtKey = 'last_synced_at';

  /// Ajoute une opération à la file d'attente.
  ///
  /// Anti-doublon (voir section 12) :
  /// * pour [SyncOperation.create]/[SyncOperation.update], si une entrée
  ///   `pending` existe déjà pour la même entité et la même opération, elle
  ///   est mise à jour (nouveau payload, nouvelle date) plutôt que dupliquée —
  ///   inutile d'envoyer deux fois la création d'une même ligne ;
  /// * pour [SyncOperation.delete], si une entrée `pending` de type `create`
  ///   existe encore pour cette entité, elle est simplement retirée : la
  ///   donnée n'a jamais été envoyée au serveur, il n'y a donc rien à lui
  ///   annoncer comme supprimé ;
  /// * les événements de mission ([SyncOperation.start] et consorts) sont
  ///   toujours ajoutés tels quels : chacun est un événement distinct, pas un
  ///   état à remplacer.
  Future<void> addToQueue({
    required String entityTable,
    required String entityLocalId,
    required SyncOperation operation,
    Map<String, dynamic>? payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    if (operation == SyncOperation.delete) {
      final pendingCreate = await _findPending(
        db,
        entityTable: entityTable,
        entityLocalId: entityLocalId,
        operation: SyncOperation.create,
      );
      if (pendingCreate != null) {
        await db.delete(DatabaseTables.syncQueue, where: 'id = ?', whereArgs: [pendingCreate['id']]);
        return;
      }
    }

    if (operation == SyncOperation.create || operation == SyncOperation.update) {
      final existing = await _findPending(
        db,
        entityTable: entityTable,
        entityLocalId: entityLocalId,
        operation: operation,
      );
      if (existing != null) {
        await db.update(
          DatabaseTables.syncQueue,
          SyncQueueEntry.fromMap(existing)
              .copyWith(payload: payload, updatedAt: now)
              .toMap()
            ..remove('id'),
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
        return;
      }
    }

    final entry = SyncQueueEntry(
      entityTable: entityTable,
      entityLocalId: entityLocalId,
      operation: operation,
      payload: payload,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(DatabaseTables.syncQueue, entry.toMap()..remove('id'));
  }

  Future<Map<String, dynamic>?> _findPending(
    Database db, {
    required String entityTable,
    required String entityLocalId,
    required SyncOperation operation,
  }) async {
    final rows = await db.query(
      DatabaseTables.syncQueue,
      where: 'entity_table = ? AND entity_local_id = ? AND operation = ? AND status = ?',
      whereArgs: [entityTable, entityLocalId, operation.value, SyncStatus.pending.value],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Éléments en attente, dans l'ordre de traitement (voir [_entityPriority]),
  /// puis du plus ancien au plus récent au sein d'une même entité.
  Future<List<SyncQueueEntry>> getPendingItems() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.syncQueue,
      where: 'status = ?',
      whereArgs: [SyncStatus.pending.value],
    );
    final entries = rows.map(SyncQueueEntry.fromMap).toList();
    entries.sort((a, b) {
      final priorityCompare = _priorityOf(a.entityTable).compareTo(_priorityOf(b.entityTable));
      if (priorityCompare != 0) return priorityCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
    return entries;
  }

  int _priorityOf(String entityTable) => _entityPriority[entityTable] ?? _defaultPriority;

  Future<int> countPending() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.syncQueue} WHERE status = ?',
      [SyncStatus.pending.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> markAsSyncing(int id) => _setStatus(id, SyncStatus.syncing);

  Future<void> markAsSynced(int id) => _setStatus(id, SyncStatus.synced);

  /// Marque l'entrée en échec, incrémente son nombre de tentatives et
  /// enregistre l'erreur (voir section 13 : jamais de suppression de la
  /// donnée locale, seulement un statut permettant de réessayer plus tard).
  Future<void> markAsFailed(int id, {String? error}) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.syncQueue}
      SET status = ?, attempts = attempts + 1, last_error = ?, updated_at = ?
      WHERE id = ?
      ''',
      [SyncStatus.failed.value, error, DateTime.now().toIso8601String(), id],
    );
  }

  /// Incrémente le compteur de tentatives sans changer le statut — utilisé
  /// séparément de [markAsFailed] lorsqu'un appelant a besoin de suivre les
  /// tentatives indépendamment de l'issue finale.
  Future<void> incrementAttempts(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.syncQueue}
      SET attempts = attempts + 1, updated_at = ?
      WHERE id = ?
      ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Marque `synced` l'entrée `pending` correspondant à [entityTable]/
  /// [entityLocalId], si elle existe — utilisée par `GpsSyncService`
  /// (chemin de synchronisation dédié, par lots, en dehors de ce moteur
  /// générique un-entrée-à-la-fois) pour que le journal de cette classe
  /// reste cohérent avec les positions réellement envoyées, plutôt que de
  /// laisser une entrée `pending` être retraitée plus tard par
  /// [SyncService] et marquée `failed` à tort. Ne fait rien si aucune
  /// entrée `pending` ne correspond (silencieux, jamais bloquant).
  Future<void> markSyncedByEntity({required String entityTable, required String entityLocalId}) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseTables.syncQueue,
      {'status': SyncStatus.synced.value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'entity_table = ? AND entity_local_id = ? AND status = ?',
      whereArgs: [entityTable, entityLocalId, SyncStatus.pending.value],
    );
  }

  /// Applique de manière transactionnelle la mise à jour de l'entité locale
  /// (`sync_status = synced`, `server_id`) et le statut `synced` de l'entrée `sync_queue`.
  Future<void> applyResultWithQueueStatus({
    required SyncQueueEntry entry,
    int? serverId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final entityValues = <String, Object?>{
      'sync_status': SyncStatus.synced.value,
      'updated_at': nowIso,
    };
    if (serverId != null) {
      entityValues['server_id'] = serverId;
    }

    await db.transaction((txn) async {
      await txn.update(
        entry.entityTable,
        entityValues,
        where: 'local_id = ?',
        whereArgs: [entry.entityLocalId],
      );
      if (entry.id != null) {
        await txn.update(
          DatabaseTables.syncQueue,
          {'status': SyncStatus.synced.value, 'updated_at': nowIso},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
    });
  }

  Future<void> _setStatus(int id, SyncStatus status) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseTables.syncQueue,
      {'status': status.value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Historique récent (succès et échecs), du plus récent au plus ancien —
  /// sert de journal de synchronisation simple (voir section 20). Ne contient
  /// jamais de donnée personnelle : uniquement l'entité, l'opération, le
  /// statut et l'erreur technique éventuelle.
  Future<List<SyncQueueEntry>> getRecentHistory({int limit = 20}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.syncQueue,
      where: 'status IN (?, ?)',
      whereArgs: [SyncStatus.synced.value, SyncStatus.failed.value],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(SyncQueueEntry.fromMap).toList();
  }

  /// Purge les entrées déjà synchronisées plus anciennes que [retention], pour
  /// éviter que la file d'attente ne grossisse indéfiniment. Ne touche jamais
  /// aux entrées `pending`/`syncing`/`failed`.
  Future<void> clearSyncedItems({Duration retention = AppConfig.syncHistoryRetention}) async {
    final db = await DatabaseHelper.instance.database;
    final threshold = DateTime.now().subtract(retention).toIso8601String();
    await db.delete(
      DatabaseTables.syncQueue,
      where: 'status = ? AND updated_at < ?',
      whereArgs: [SyncStatus.synced.value, threshold],
    );
  }

  /// Réinitialise les entrées restées bloquées à l'état `syncing` (par exemple
  /// suite à un arrêt brutal de l'application pendant une requête réseau)
  /// en les remettant à `pending` afin qu'elles puissent être retraitées.
  Future<int> resetStaleSyncingStates() async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.syncQueue,
      {'status': SyncStatus.pending.value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'status = ?',
      whereArgs: [SyncStatus.syncing.value],
    );
  }

  // --- Métadonnées de synchronisation (`sync_meta`) ---------------------------

  Future<DateTime?> getLastSyncedAt() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.syncMeta,
      where: 'key = ?',
      whereArgs: [_lastSyncedAtKey],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['value'] == null) return null;
    return DateTime.tryParse(rows.first['value'] as String);
  }

  Future<void> setLastSyncedAt(DateTime time) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseTables.syncMeta, {
      'key': _lastSyncedAtKey,
      'value': time.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
