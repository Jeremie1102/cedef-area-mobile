import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/cld.dart';
import '../models/mission.dart';
import '../models/mission_cld.dart';
import '../models/mission_user.dart';
import '../models/village.dart';

/// Une mission accompagnée d'informations d'affichage (nom du secteur, noms
/// des CLD concernés) calculées en une seule requête, pour l'écran « Mes
/// missions » — sur le même principe que `CldWithLocation` /
/// `MediaBatchSummary`.
class MissionSummary {
  final Mission mission;
  final String? secteurName;
  final List<String> cldNames;

  const MissionSummary({required this.mission, this.secteurName, required this.cldNames});
}

/// Missions dont le statut correspond à une mission "en cours" au sens large
/// (démarrée, éventuellement mise en pause).
const List<MissionStatus> _activeStatuses = [MissionStatus.inProgress, MissionStatus.paused];

/// Accès aux données locales des tables `missions`, `mission_users` et
/// `mission_clds`.
///
/// Ce repository ne contient aucune règle métier (transitions de statut,
/// validations) : celles-ci vivent dans `MissionService`. Il se limite à la
/// lecture/écriture en base, y compris les requêtes qui combinent plusieurs
/// tables pour l'affichage.
class MissionRepository {
  Future<int> insert(Mission mission) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.missions, mission.toMap()..remove('id'));
  }

  Future<int> update(Mission mission) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.missions,
      mission.toMap(),
      where: 'id = ?',
      whereArgs: [mission.id],
    );
  }

  Future<Mission?> getByServerId(int serverId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.missions,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Mission.fromMap(rows.first);
  }

  Future<Mission?> findById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.missions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Mission.fromMap(rows.first);
  }

  Future<List<Mission>> findAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.missions, orderBy: 'date_debut DESC');
    return rows.map(Mission.fromMap).toList();
  }

  /// Missions attribuées à un utilisateur donné, via `mission_users`.
  Future<List<Mission>> findByUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT m.* FROM ${DatabaseTables.missions} m
      INNER JOIN ${DatabaseTables.missionUsers} mu ON mu.mission_id = m.id
      WHERE mu.user_id = ?
      ORDER BY m.date_debut DESC
      ''',
      [userId],
    );
    return rows.map(Mission.fromMap).toList();
  }

  /// Vrai si la mission est bien attribuée à cet utilisateur (contrôle
  /// d'accès avant d'ouvrir ses détails ou de changer son statut).
  Future<bool> isAssignedToUser({required int missionId, required int userId}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.missionUsers,
      where: 'mission_id = ? AND user_id = ?',
      whereArgs: [missionId, userId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Mission actuellement active (`in_progress` ou `paused`) pour un
  /// utilisateur, s'il en existe une. Prépare la structure nécessaire au
  /// futur `GpsService` (voir `MissionService.getActiveMission`).
  Future<Mission?> getActiveMissionForUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final placeholders = _activeStatuses.map((_) => '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT m.* FROM ${DatabaseTables.missions} m
      INNER JOIN ${DatabaseTables.missionUsers} mu ON mu.mission_id = m.id
      WHERE mu.user_id = ? AND m.statut IN ($placeholders)
      ORDER BY m.started_at DESC
      LIMIT 1
      ''',
      [userId, ..._activeStatuses.map((s) => s.value)],
    );
    if (rows.isEmpty) return null;
    return Mission.fromMap(rows.first);
  }

  /// Missions de l'utilisateur avec le nom du secteur et des CLD concernés,
  /// pour l'écran « Mes missions ».
  Future<List<MissionSummary>> getSummariesByUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT m.*, s.nom AS secteur_nom,
        GROUP_CONCAT(c.nom, '||') AS cld_noms
      FROM ${DatabaseTables.missions} m
      INNER JOIN ${DatabaseTables.missionUsers} mu ON mu.mission_id = m.id
      LEFT JOIN ${DatabaseTables.secteurs} s ON m.secteur_id = s.id
      LEFT JOIN ${DatabaseTables.missionClds} mc ON mc.mission_id = m.id
      LEFT JOIN ${DatabaseTables.clds} c ON mc.cld_id = c.id
      WHERE mu.user_id = ?
      GROUP BY m.id
      ORDER BY m.date_debut DESC
      ''',
      [userId],
    );

    return rows.map((row) {
      final rawCldNames = row['cld_noms'] as String?;
      return MissionSummary(
        mission: Mission.fromMap(row),
        secteurName: row['secteur_nom'] as String?,
        cldNames: (rawCldNames == null || rawCldNames.isEmpty) ? [] : rawCldNames.split('||'),
      );
    }).toList();
  }

  // --- Agents affectés (table `mission_users`) --------------------------------

  /// Ignore silencieusement si déjà affecté (contrainte UNIQUE(mission_id,
  /// user_id)) : nécessaire car appelée à chaque synchronisation descendante,
  /// pas seulement une fois (voir `DownstreamSyncService`).
  Future<int> assignUser(MissionUser missionUser) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(
      DatabaseTables.missionUsers,
      missionUser.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<MissionUser>> findAssignments(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.missionUsers,
      where: 'mission_id = ?',
      whereArgs: [missionId],
    );
    return rows.map(MissionUser.fromMap).toList();
  }

  // --- Territoire de la mission (table `mission_clds`) ------------------------

  /// Ignore silencieusement si déjà affecté (contrainte UNIQUE(mission_id,
  /// cld_id)) : même raison que [assignUser].
  Future<int> assignCld(MissionCld missionCld) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(
      DatabaseTables.missionClds,
      missionCld.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<MissionCld>> findMissionClds(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.missionClds,
      where: 'mission_id = ?',
      whereArgs: [missionId],
    );
    return rows.map(MissionCld.fromMap).toList();
  }

  /// CLD concernés par une mission.
  Future<List<Cld>> getCldsForMission(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.* FROM ${DatabaseTables.clds} c
      INNER JOIN ${DatabaseTables.missionClds} mc ON mc.cld_id = c.id
      WHERE mc.mission_id = ?
      ORDER BY c.nom ASC
      ''',
      [missionId],
    );
    return rows.map(Cld.fromMap).toList();
  }

  /// Villages concernés par une mission, déduits des CLD qu'elle couvre
  /// (`Mission -> mission_clds -> CLD -> villages`) : aucune duplication de
  /// l'information territoriale dans `missions`.
  Future<List<Village>> getVillagesForMission(int missionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT v.* FROM ${DatabaseTables.villages} v
      INNER JOIN ${DatabaseTables.missionClds} mc ON mc.cld_id = v.cld_id
      WHERE mc.mission_id = ?
      ORDER BY v.nom ASC
      ''',
      [missionId],
    );
    return rows.map(Village.fromMap).toList();
  }

  Future<List<Mission>> findPendingSync() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.missions,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
    );
    return rows.map(Mission.fromMap).toList();
  }

  Future<int> countPendingSync() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.missions} WHERE sync_status = ?',
      [SyncStatus.pending.value],
    );
    return (result.first['total'] as int?) ?? 0;
  }
}
