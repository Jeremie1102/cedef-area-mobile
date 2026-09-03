import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Étape 8 — Module Observations et Constats Terrain.
///
/// Permet à l'agent de terrain de documenter de multiples constats
/// structurés et géolocalisés au cours d'une même mission (infrastructure,
/// accessibilité, environnement, gouvernance, autre), avec niveau de gravité,
/// coordonnées GPS réelles, et horodatage UTC.
///
/// Schéma totalement offline-first : clé primaire locale `id`, identifiant
/// unique UUID `local_id`, rattachement à la mission locale (`mission_id`,
/// `mission_local_id`) et synchronisation incrémentale.
class MigrationV8 {
  MigrationV8._();

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.observations} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        mission_id INTEGER NOT NULL,
        mission_local_id TEXT NOT NULL,
        mission_server_id INTEGER,
        user_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        accuracy REAL,
        recorded_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        last_sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES ${DatabaseTables.missions} (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_observations_mission_id ON ${DatabaseTables.observations} (mission_id)',
    );
    await db.execute(
      'CREATE INDEX idx_observations_mission_local_id ON ${DatabaseTables.observations} (mission_local_id)',
    );
    await db.execute(
      'CREATE INDEX idx_observations_sync_status ON ${DatabaseTables.observations} (sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_observations_recorded_at ON ${DatabaseTables.observations} (recorded_at)',
    );
  }
}
