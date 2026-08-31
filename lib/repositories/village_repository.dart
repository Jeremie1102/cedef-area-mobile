import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/village.dart';

/// Accès aux données locales de la table `villages`.
class VillageRepository {
  Future<int> insert(Village village) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.villages, village.toMap()..remove('id'));
  }

  Future<int> update(Village village) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.villages,
      village.toMap(),
      where: 'id = ?',
      whereArgs: [village.id],
    );
  }

  Future<Village?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.villages,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Village.fromMap(rows.first);
  }

  Future<Village?> getByServerId(int serverId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.villages,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Village.fromMap(rows.first);
  }

  Future<List<Village>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.villages, orderBy: 'nom ASC');
    return rows.map(Village.fromMap).toList();
  }

  Future<List<Village>> getByCld(int cldId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.villages,
      where: 'cld_id = ?',
      whereArgs: [cldId],
      orderBy: 'nom ASC',
    );
    return rows.map(Village.fromMap).toList();
  }

  Future<List<Village>> search(String query) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.villages,
      where: 'nom LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nom ASC',
    );
    return rows.map(Village.fromMap).toList();
  }
}
