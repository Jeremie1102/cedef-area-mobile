import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Création initiale du schéma de la base de données locale (version 1).
class MigrationV1 {
  MigrationV1._();

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.users} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        nom TEXT NOT NULL,
        post_nom TEXT,
        prenom TEXT,
        fonction TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        photo_profil TEXT,
        telephone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.secteurs} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        nom TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.groupements} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        secteur_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (secteur_id) REFERENCES ${DatabaseTables.secteurs} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.villages} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        groupement_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (groupement_id) REFERENCES ${DatabaseTables.groupements} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.clds} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        village_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        responsable_user_id INTEGER,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (village_id) REFERENCES ${DatabaseTables.villages} (id) ON DELETE CASCADE,
        FOREIGN KEY (responsable_user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.missions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        titre TEXT NOT NULL,
        description TEXT,
        date_debut TEXT,
        date_fin TEXT,
        secteur_id INTEGER,
        statut TEXT NOT NULL DEFAULT 'pending',
        instructions TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (secteur_id) REFERENCES ${DatabaseTables.secteurs} (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.missionUsers} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        mission_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES ${DatabaseTables.missions} (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE CASCADE,
        UNIQUE (mission_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.medias} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        mission_id INTEGER,
        user_id INTEGER NOT NULL,
        secteur_id INTEGER,
        groupement_id INTEGER,
        village_id INTEGER,
        cld_id INTEGER,
        type TEXT NOT NULL DEFAULT 'photo',
        chemin_local TEXT NOT NULL,
        nom_fichier TEXT NOT NULL,
        description TEXT,
        activite TEXT,
        latitude REAL,
        longitude REAL,
        date_prise TEXT NOT NULL,
        statut_validation TEXT NOT NULL DEFAULT 'pending',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (mission_id) REFERENCES ${DatabaseTables.missions} (id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE CASCADE,
        FOREIGN KEY (secteur_id) REFERENCES ${DatabaseTables.secteurs} (id) ON DELETE SET NULL,
        FOREIGN KEY (groupement_id) REFERENCES ${DatabaseTables.groupements} (id) ON DELETE SET NULL,
        FOREIGN KEY (village_id) REFERENCES ${DatabaseTables.villages} (id) ON DELETE SET NULL,
        FOREIGN KEY (cld_id) REFERENCES ${DatabaseTables.clds} (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.gpsPositions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        mission_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        altitude REAL,
        recorded_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (mission_id) REFERENCES ${DatabaseTables.missions} (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.syncQueue} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_table TEXT NOT NULL,
        entity_local_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createIndexes(db);
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX idx_groupements_secteur ON ${DatabaseTables.groupements} (secteur_id)',
    );
    await db.execute(
      'CREATE INDEX idx_villages_groupement ON ${DatabaseTables.villages} (groupement_id)',
    );
    await db.execute('CREATE INDEX idx_clds_village ON ${DatabaseTables.clds} (village_id)');
    await db.execute(
      'CREATE INDEX idx_clds_responsable ON ${DatabaseTables.clds} (responsable_user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_missions_secteur ON ${DatabaseTables.missions} (secteur_id)',
    );
    await db.execute('CREATE INDEX idx_missions_statut ON ${DatabaseTables.missions} (statut)');
    await db.execute(
      'CREATE INDEX idx_mission_users_mission ON ${DatabaseTables.missionUsers} (mission_id)',
    );
    await db.execute(
      'CREATE INDEX idx_mission_users_user ON ${DatabaseTables.missionUsers} (user_id)',
    );
    await db.execute('CREATE INDEX idx_medias_mission ON ${DatabaseTables.medias} (mission_id)');
    await db.execute('CREATE INDEX idx_medias_user ON ${DatabaseTables.medias} (user_id)');
    await db.execute('CREATE INDEX idx_medias_cld ON ${DatabaseTables.medias} (cld_id)');
    await db.execute(
      'CREATE INDEX idx_medias_sync_status ON ${DatabaseTables.medias} (sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_gps_positions_mission ON ${DatabaseTables.gpsPositions} (mission_id)',
    );
    await db.execute(
      'CREATE INDEX idx_gps_positions_user ON ${DatabaseTables.gpsPositions} (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON ${DatabaseTables.syncQueue} (status)',
    );
  }
}
