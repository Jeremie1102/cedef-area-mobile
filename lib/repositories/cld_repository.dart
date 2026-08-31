import 'package:sqflite/sqflite.dart';

import '../core/utils/id_generator.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/cld.dart';
import '../models/user_cld.dart';

/// Un CLD accompagné du nom de son groupement et de son secteur, pratique
/// pour l'affichage (sélecteur de CLD, écran Territoire, section "Mes CLD"
/// du profil) sans avoir à recharger séparément la hiérarchie parente.
class CldWithLocation {
  final Cld cld;
  final String groupementName;
  final int secteurId;
  final String secteurName;

  const CldWithLocation({
    required this.cld,
    required this.groupementName,
    required this.secteurId,
    required this.secteurName,
  });
}

/// Accès aux données locales de la table `clds` ainsi qu'à la table
/// d'association `user_clds` (CLD en charge d'un utilisateur), sur le même
/// principe que `MissionRepository` pour `missions` / `mission_users`.
class CldRepository {
  Future<int> insert(Cld cld) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.clds, cld.toMap()..remove('id'));
  }

  Future<int> update(Cld cld) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(DatabaseTables.clds, cld.toMap(), where: 'id = ?', whereArgs: [cld.id]);
  }

  Future<Cld?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.clds, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Cld.fromMap(rows.first);
  }

  Future<Cld?> getByServerId(int serverId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.clds,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Cld.fromMap(rows.first);
  }

  Future<List<Cld>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.clds, orderBy: 'nom ASC');
    return rows.map(Cld.fromMap).toList();
  }

  Future<List<Cld>> getByGroupement(int groupementId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.clds,
      where: 'groupement_id = ?',
      whereArgs: [groupementId],
      orderBy: 'nom ASC',
    );
    return rows.map(Cld.fromMap).toList();
  }

  Future<List<Cld>> search(String query) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.clds,
      where: 'nom LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nom ASC',
    );
    return rows.map(Cld.fromMap).toList();
  }

  // --- CLD en charge d'un utilisateur (table `user_clds`) --------------------
  //
  // Ces affectations sont décidées par l'Assistant Technique depuis
  // l'administration Laravel (à venir) : l'application mobile ne propose
  // aucun écran permettant à l'animateur de s'attribuer ou de modifier ses
  // propres CLD. `assignToUser`/`unassignFromUser` existent uniquement pour
  // que le futur `SyncService` puisse appliquer localement les affectations
  // reçues du serveur.

  /// Associe un CLD à un utilisateur. Ignore silencieusement si déjà associé
  /// (contrainte UNIQUE(user_id, cld_id)).
  Future<void> assignToUser({required int userId, required int cldId}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final userCld = UserCld(
      localId: IdGenerator.generate(),
      userId: userId,
      cldId: cldId,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(
      DatabaseTables.userClds,
      userCld.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unassignFromUser({required int userId, required int cldId}) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseTables.userClds,
      where: 'user_id = ? AND cld_id = ?',
      whereArgs: [userId, cldId],
    );
  }

  /// CLD dont un utilisateur a la charge, via `user_clds`.
  Future<List<Cld>> getByUser(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.* FROM ${DatabaseTables.clds} c
      INNER JOIN ${DatabaseTables.userClds} uc ON uc.cld_id = c.id
      WHERE uc.user_id = ?
      ORDER BY c.nom ASC
      ''',
      [userId],
    );
    return rows.map(Cld.fromMap).toList();
  }

  // --- Variantes avec groupement/secteur (affichage) --------------------------

  static const String _locationJoin = '''
    FROM ${DatabaseTables.clds} c
    INNER JOIN ${DatabaseTables.groupements} g ON c.groupement_id = g.id
    INNER JOIN ${DatabaseTables.secteurs} s ON g.secteur_id = s.id
  ''';

  Future<List<CldWithLocation>> getAllWithLocation() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT c.*, g.nom AS groupement_nom, s.id AS secteur_id_resolved, s.nom AS secteur_nom $_locationJoin
      ORDER BY c.nom ASC
    ''');
    return _mapWithLocation(rows);
  }

  Future<List<CldWithLocation>> searchWithLocation(String query) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.*, g.nom AS groupement_nom, s.id AS secteur_id_resolved, s.nom AS secteur_nom $_locationJoin
      WHERE c.nom LIKE ? OR c.code LIKE ? OR g.nom LIKE ? OR s.nom LIKE ?
      ORDER BY c.nom ASC
      ''',
      ['%$query%', '%$query%', '%$query%', '%$query%'],
    );
    return _mapWithLocation(rows);
  }

  /// CLD identifiés par [ids], avec leur groupement/secteur — utilisé pour
  /// restreindre le choix du CLD d'un lot de médias à ceux d'une mission
  /// (voir `NewMediaBatchScreen`).
  Future<List<CldWithLocation>> getByIdsWithLocation(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT c.*, g.nom AS groupement_nom, s.id AS secteur_id_resolved, s.nom AS secteur_nom $_locationJoin
      WHERE c.id IN ($placeholders)
      ORDER BY c.nom ASC
      ''',
      ids,
    );
    return _mapWithLocation(rows);
  }

  Future<List<CldWithLocation>> getByUserWithLocation(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.*, g.nom AS groupement_nom, s.id AS secteur_id_resolved, s.nom AS secteur_nom $_locationJoin
      INNER JOIN ${DatabaseTables.userClds} uc ON uc.cld_id = c.id
      WHERE uc.user_id = ?
      ORDER BY c.nom ASC
      ''',
      [userId],
    );
    return _mapWithLocation(rows);
  }

  /// Recherche restreinte aux CLD affectés à [userId] (voir [getByUserWithLocation])
  /// — utilisée par le sélecteur de CLD des lots de médias, qui ne doit
  /// jamais proposer un CLD hors affectation de l'agent.
  Future<List<CldWithLocation>> searchByUserWithLocation(int userId, String query) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT c.*, g.nom AS groupement_nom, s.id AS secteur_id_resolved, s.nom AS secteur_nom $_locationJoin
      INNER JOIN ${DatabaseTables.userClds} uc ON uc.cld_id = c.id
      WHERE uc.user_id = ? AND (c.nom LIKE ? OR c.code LIKE ? OR g.nom LIKE ? OR s.nom LIKE ?)
      ORDER BY c.nom ASC
      ''',
      [userId, '%$query%', '%$query%', '%$query%', '%$query%'],
    );
    return _mapWithLocation(rows);
  }

  List<CldWithLocation> _mapWithLocation(List<Map<String, Object?>> rows) {
    return rows
        .map(
          (row) => CldWithLocation(
            cld: Cld.fromMap(row),
            groupementName: row['groupement_nom'] as String? ?? '',
            secteurId: row['secteur_id_resolved'] as int,
            secteurName: row['secteur_nom'] as String? ?? '',
          ),
        )
        .toList();
  }
}
