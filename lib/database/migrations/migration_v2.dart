import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Étape 3 — Territoire :
///
/// * ajoute `code`, `description` et `is_active` aux tables géographiques ;
/// * crée `user_clds`, la table d'association entre un utilisateur et les
///   CLD dont il a la charge (relation plusieurs-à-plusieurs).
///
/// N'altère jamais les données existantes : uniquement des ajouts.
///
/// Note : la hiérarchie `villages`/`clds` posée à cette étape (Village >
/// CLD) était incorrecte et a été corrigée par [MigrationV3]
/// (Secteur > Groupement > CLD > Village).
class MigrationV2 {
  MigrationV2._();

  static Future<void> up(Database db) async {
    for (final table in [
      DatabaseTables.secteurs,
      DatabaseTables.groupements,
      DatabaseTables.villages,
      DatabaseTables.clds,
    ]) {
      await db.execute('ALTER TABLE $table ADD COLUMN code TEXT');
      await db.execute('ALTER TABLE $table ADD COLUMN description TEXT');
      await db.execute(
        'ALTER TABLE $table ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
    }

    await db.execute('''
      CREATE TABLE ${DatabaseTables.userClds} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        user_id INTEGER NOT NULL,
        cld_id INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE CASCADE,
        FOREIGN KEY (cld_id) REFERENCES ${DatabaseTables.clds} (id) ON DELETE CASCADE,
        UNIQUE (user_id, cld_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_user_clds_user ON ${DatabaseTables.userClds} (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_clds_cld ON ${DatabaseTables.userClds} (cld_id)',
    );
  }
}
