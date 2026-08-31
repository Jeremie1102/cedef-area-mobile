import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/groupement.dart';

/// Accès aux données locales de la table `groupements`.
class GroupementRepository {
  Future<int> insert(Groupement groupement) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.groupements, groupement.toMap()..remove('id'));
  }

  Future<int> update(Groupement groupement) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.groupements,
      groupement.toMap(),
      where: 'id = ?',
      whereArgs: [groupement.id],
    );
  }

  Future<Groupement?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.groupements,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Groupement.fromMap(rows.first);
  }

  Future<Groupement?> getByServerId(int serverId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.groupements,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Groupement.fromMap(rows.first);
  }

  Future<List<Groupement>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.groupements, orderBy: 'nom ASC');
    return rows.map(Groupement.fromMap).toList();
  }

  Future<List<Groupement>> getBySecteur(int secteurId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.groupements,
      where: 'secteur_id = ?',
      whereArgs: [secteurId],
      orderBy: 'nom ASC',
    );
    return rows.map(Groupement.fromMap).toList();
  }

  Future<List<Groupement>> search(String query) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.groupements,
      where: 'nom LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nom ASC',
    );
    return rows.map(Groupement.fromMap).toList();
  }
}
