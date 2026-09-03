import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/observation.dart';

/// Accès aux données locales de la table `observations`.
///
/// Gère la persistance hors-ligne des constats terrain enregistrés par les agents
/// lors de leurs missions, leur statut de synchronisation et leurs mises à jour.
class ObservationRepository {
  /// Enregistre une nouvelle observation locale.
  Future<int> create(Observation observation) async {
    final db = await DatabaseHelper.instance.database;
    final map = observation.toMap()..remove('id');
    return db.insert(DatabaseTables.observations, map);
  }

  /// Recherche une observation par son identifiant SQLite interne.
  Future<Observation?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.observations,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Observation.fromMap(rows.first);
  }

  /// Recherche une observation par son UUID unique `local_id`.
  Future<Observation?> getByLocalId(String localId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.observations,
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : Observation.fromMap(rows.first);
  }

  /// Retourne toutes les observations associées à une mission donnée,
  /// ordonnées de la plus récente à la plus ancienne.
  Future<List<Observation>> getByMissionId(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.observations,
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'recorded_at DESC, id DESC',
    );
    return rows.map(Observation.fromMap).toList();
  }

  /// Retourne le nombre total d'observations enregistrées pour une mission.
  Future<int> countByMission(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM ${DatabaseTables.observations} WHERE mission_id = ?',
      [missionId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Retourne toutes les observations en attente de synchronisation (`pending`).
  Future<List<Observation>> getPendingObservations() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.observations,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(Observation.fromMap).toList();
  }

  /// Met à jour une observation locale.
  Future<int> update(Observation observation) async {
    if (observation.id == null) {
      throw ArgumentError('Impossible de mettre à jour une observation sans id.');
    }
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.observations,
      observation.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [observation.id],
    );
  }

  /// Supprime une observation par son identifiant SQLite.
  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.delete(
      DatabaseTables.observations,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une observation comme synchronisée (`synced`) et lui associe son
  /// `server_id` attribué par Laravel.
  Future<int> markSynced({required int id, int? serverId}) async {
    final db = await DatabaseHelper.instance.database;
    final values = <String, Object?>{
      'sync_status': SyncStatus.synced.value,
      'last_sync_error': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (serverId != null) {
      values['server_id'] = serverId;
    }
    return db.update(
      DatabaseTables.observations,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une observation en échec de synchronisation (`failed`),
  /// incrémente son compteur de tentatives et enregistre le message d'erreur.
  Future<int> markFailed({required int id, String? error}) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.observations}
      SET sync_status = ?, sync_attempts = sync_attempts + 1, last_sync_error = ?, updated_at = ?
      WHERE id = ?
      ''',
      [SyncStatus.failed.value, error, DateTime.now().toIso8601String(), id],
    );
  }

  /// Réinitialise les observations bloquées à l'état `syncing` vers `pending`
  /// suite à une interruption inattendue.
  Future<int> resetStaleSyncingStates() async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.observations,
      {
        'sync_status': SyncStatus.pending.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.syncing.value],
    );
  }
}
