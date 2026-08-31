import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Correction de la hiérarchie territoriale.
///
/// Les étapes précédentes avaient modélisé `Secteur > Groupement > Village >
/// CLD`. Le fonctionnement réel du CEDEF est en réalité
/// `Secteur > Groupement > CLD > Village` : un CLD regroupe plusieurs
/// villages, et non l'inverse. Cette migration recrée `clds` (qui pointait
/// vers `village_id`) et `villages` (qui pointait vers `groupement_id`) avec
/// les bonnes relations : `clds.groupement_id` et `villages.cld_id`.
///
/// La colonne `clds.responsable_user_id` est également supprimée : elle
/// dupliquait, avec une relation à un seul utilisateur, ce que `user_clds`
/// fait déjà correctement (un CLD peut être suivi par plusieurs agents, et
/// un agent peut avoir plusieurs CLD). `user_clds` reste la seule source de
/// vérité pour les affectations.
///
/// Ces deux tables ne contenaient encore, à ce stade du projet, que des
/// données de démonstration locales (aucune donnée Laravel réelle
/// n'existant encore) : on les recrée donc simplement plutôt que de tenter
/// de migrer des relations qui n'ont plus de sens dans le nouveau modèle.
/// Les affectations `user_clds` existantes sont supprimées pour la même
/// raison (elles pointaient vers des CLD qui n'existent plus).
class MigrationV3 {
  MigrationV3._();

  static Future<void> up(Database db) async {
    await db.execute('DELETE FROM ${DatabaseTables.userClds}');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseTables.clds}');
    await db.execute('DROP TABLE IF EXISTS ${DatabaseTables.villages}');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.clds} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        groupement_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        code TEXT,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (groupement_id) REFERENCES ${DatabaseTables.groupements} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.villages} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        cld_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        code TEXT,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cld_id) REFERENCES ${DatabaseTables.clds} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_clds_groupement ON ${DatabaseTables.clds} (groupement_id)');
    await db.execute('CREATE INDEX idx_villages_cld ON ${DatabaseTables.villages} (cld_id)');
  }
}
