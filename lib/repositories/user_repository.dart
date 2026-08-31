import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/user.dart';

/// Accès aux données locales de la table `users`.
class UserRepository {
  Future<int> insert(User user) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(DatabaseTables.users, user.toMap()..remove('id'));
  }

  Future<int> update(User user) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      DatabaseTables.users,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.delete(DatabaseTables.users, where: 'id = ?', whereArgs: [id]);
  }

  Future<User?> findById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.users, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> getByServerId(int serverId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> findByLocalId(String localId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  /// Recherche par numéro de téléphone, utilisée lors de la connexion locale.
  Future<User?> findByTelephone(String telephone) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'telephone = ?',
      whereArgs: [telephone],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  /// Recherche par nom, post-nom et prénom (insensible à la casse), utilisée
  /// pour empêcher la création de deux comptes locaux identiques lorsque le
  /// numéro de téléphone n'a pas été renseigné.
  Future<User?> findByFullName({
    required String nom,
    required String postNom,
    required String prenom,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'LOWER(nom) = ? AND LOWER(post_nom) = ? AND LOWER(prenom) = ?',
      whereArgs: [nom.trim().toLowerCase(), postNom.trim().toLowerCase(), prenom.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<List<User>> findAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.users, orderBy: 'nom ASC');
    return rows.map(User.fromMap).toList();
  }

  Future<List<User>> findPendingSync() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.users,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
    );
    return rows.map(User.fromMap).toList();
  }
}
