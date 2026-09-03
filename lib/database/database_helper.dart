import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import 'migrations/migration_v1.dart';
import 'migrations/migration_v2.dart';
import 'migrations/migration_v3.dart';
import 'migrations/migration_v4.dart';
import 'migrations/migration_v5.dart';
import 'migrations/migration_v6.dart';
import 'migrations/migration_v7.dart';
import 'migrations/migration_v8.dart';

/// Point d'accès unique à la base de données SQLite locale.
///
/// Toute la persistance hors-ligne de l'application passe par cette classe.
/// Les migrations futures doivent être ajoutées dans `onUpgrade` en créant
/// un nouveau fichier `migration_vX.dart`.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Nom du fichier de base de données. Modifiable uniquement par les tests,
  /// pour que chaque suite de test utilise son propre fichier SQLite et ne
  /// se bloque pas mutuellement lorsque plusieurs fichiers de test tournent
  /// en parallèle.
  static String databaseFileName = AppConfig.databaseName;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, databaseFileName);

    return openDatabase(
      path,
      version: AppConfig.databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Une base fraîchement créée (nouvelle installation) doit obtenir le
  /// schéma complet : on rejoue donc toutes les migrations dans l'ordre,
  /// exactement comme le ferait une mise à niveau depuis la version 0.
  Future<void> _onCreate(Database db, int version) async {
    await MigrationV1.up(db);
    await MigrationV2.up(db);
    await MigrationV3.up(db);
    await MigrationV4.up(db);
    await MigrationV5.up(db);
    await MigrationV6.up(db);
    await MigrationV7.up(db);
    await MigrationV8.up(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await MigrationV2.up(db);
    if (oldVersion < 3) await MigrationV3.up(db);
    if (oldVersion < 4) await MigrationV4.up(db);
    if (oldVersion < 5) await MigrationV5.up(db);
    if (oldVersion < 6) await MigrationV6.up(db);
    if (oldVersion < 7) await MigrationV7.up(db);
    if (oldVersion < 8) await MigrationV8.up(db);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
