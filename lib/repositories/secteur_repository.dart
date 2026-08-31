import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/secteur.dart';

/// Statistiques d'un secteur (nombre de groupements/villages/CLD qu'il
/// contient), utilisées pour l'écran Territoire.
class SecteurStats {
  final Secteur secteur;
  final int groupementsCount;
  final int villagesCount;
  final int cldsCount;

  const SecteurStats({
    required this.secteur,
    required this.groupementsCount,
    required this.villagesCount,
    required this.cldsCount,
  });
}

/// Accès aux données locales de la table `secteurs`.
class SecteurRepository {
  Future<int> insert(Secteur secteur) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.secteurs, secteur.toMap()..remove('id'));
  }

  Future<int> update(Secteur secteur) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.secteurs,
      secteur.toMap(),
      where: 'id = ?',
      whereArgs: [secteur.id],
    );
  }

  Future<Secteur?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.secteurs,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Secteur.fromMap(rows.first);
  }

  Future<Secteur?> getByServerId(int serverId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.secteurs,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Secteur.fromMap(rows.first);
  }

  Future<List<Secteur>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.secteurs, orderBy: 'nom ASC');
    return rows.map(Secteur.fromMap).toList();
  }

  Future<List<Secteur>> search(String query) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.secteurs,
      where: 'nom LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nom ASC',
    );
    return rows.map(Secteur.fromMap).toList();
  }

  /// Statistiques (nombre de groupements/villages/CLD) pour chaque secteur,
  /// calculées en une seule requête pour l'écran Territoire.
  Future<List<SecteurStats>> getAllWithStats() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT s.*,
        (SELECT COUNT(*) FROM ${DatabaseTables.groupements} g
           WHERE g.secteur_id = s.id) AS groupements_count,
        (SELECT COUNT(*) FROM ${DatabaseTables.villages} v
           INNER JOIN ${DatabaseTables.clds} c ON v.cld_id = c.id
           INNER JOIN ${DatabaseTables.groupements} g ON c.groupement_id = g.id
           WHERE g.secteur_id = s.id) AS villages_count,
        (SELECT COUNT(*) FROM ${DatabaseTables.clds} c
           INNER JOIN ${DatabaseTables.groupements} g ON c.groupement_id = g.id
           WHERE g.secteur_id = s.id) AS clds_count
      FROM ${DatabaseTables.secteurs} s
      ORDER BY s.nom ASC
    ''');

    return rows
        .map(
          (row) => SecteurStats(
            secteur: Secteur.fromMap(row),
            groupementsCount: (row['groupements_count'] as int?) ?? 0,
            villagesCount: (row['villages_count'] as int?) ?? 0,
            cldsCount: (row['clds_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }
}
