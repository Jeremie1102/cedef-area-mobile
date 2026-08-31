import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Étape 4 — Missions de terrain.
///
/// * ajoute à `missions` les horodatages du cycle de vie (démarrage, pause,
///   reprise, fin) ainsi qu'une observation de fin, nécessaires pour que le
///   suivi d'une mission fonctionne hors ligne et survive à la fermeture de
///   l'application ;
/// * crée `mission_clds`, la table d'association entre une [Mission] et les
///   CLD qu'elle concerne (relation plusieurs-à-plusieurs). Les villages
///   concernés par une mission se déduisent de ces CLD (`villages.cld_id`),
///   sans dupliquer l'information territoriale dans `missions` : une mission
///   peut ainsi couvrir un ou plusieurs CLD, chacun avec plusieurs villages.
///
/// N'altère jamais les données existantes : uniquement des ajouts.
class MigrationV5 {
  MigrationV5._();

  static Future<void> up(Database db) async {
    await db.execute('ALTER TABLE ${DatabaseTables.missions} ADD COLUMN started_at TEXT');
    await db.execute('ALTER TABLE ${DatabaseTables.missions} ADD COLUMN paused_at TEXT');
    await db.execute('ALTER TABLE ${DatabaseTables.missions} ADD COLUMN resumed_at TEXT');
    await db.execute('ALTER TABLE ${DatabaseTables.missions} ADD COLUMN ended_at TEXT');
    await db.execute('ALTER TABLE ${DatabaseTables.missions} ADD COLUMN end_observation TEXT');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.missionClds} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        mission_id INTEGER NOT NULL,
        cld_id INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES ${DatabaseTables.missions} (id) ON DELETE CASCADE,
        FOREIGN KEY (cld_id) REFERENCES ${DatabaseTables.clds} (id) ON DELETE CASCADE,
        UNIQUE (mission_id, cld_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_mission_clds_mission ON ${DatabaseTables.missionClds} (mission_id)',
    );
    await db.execute(
      'CREATE INDEX idx_mission_clds_cld ON ${DatabaseTables.missionClds} (cld_id)',
    );
  }
}
