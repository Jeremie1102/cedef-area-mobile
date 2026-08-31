import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Correction du modèle de médias.
///
/// CEDEF AREA ne sert pas à prendre des photos : l'animateur sélectionne des
/// photos déjà présentes dans sa galerie et les regroupe en **lot**
/// correspondant à une même activité. La table `medias`, qui traitait
/// chaque photo comme une entité indépendante avec sa propre description,
/// est remplacée par deux tables :
///
/// * `media_batches` porte les informations communes à tout le lot
///   (activité, secteur/groupement/CLD/village, description, GPS, statut) ;
/// * `media_items` ne porte que les informations propres à chaque fichier
///   (chemin local, nom, taille, type MIME, ordre).
///
/// `medias` ne contenait encore aucune donnée réelle (aucune photo de
/// terrain n'a pu être synchronisée, l'API Laravel n'existant pas encore) :
/// elle est donc simplement supprimée plutôt que migrée, comme pour la
/// correction de hiérarchie territoriale en [MigrationV3].
class MigrationV4 {
  MigrationV4._();

  static Future<void> up(Database db) async {
    await db.execute('DROP TABLE IF EXISTS ${DatabaseTables.medias}');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.mediaBatches} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        user_id INTEGER NOT NULL,
        mission_id INTEGER,
        secteur_id INTEGER,
        groupement_id INTEGER,
        cld_id INTEGER,
        village_id INTEGER,
        activity TEXT,
        description TEXT,
        latitude REAL,
        longitude REAL,
        gps_accuracy REAL,
        captured_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${DatabaseTables.users} (id) ON DELETE CASCADE,
        FOREIGN KEY (mission_id) REFERENCES ${DatabaseTables.missions} (id) ON DELETE SET NULL,
        FOREIGN KEY (secteur_id) REFERENCES ${DatabaseTables.secteurs} (id) ON DELETE SET NULL,
        FOREIGN KEY (groupement_id) REFERENCES ${DatabaseTables.groupements} (id) ON DELETE SET NULL,
        FOREIGN KEY (cld_id) REFERENCES ${DatabaseTables.clds} (id) ON DELETE SET NULL,
        FOREIGN KEY (village_id) REFERENCES ${DatabaseTables.villages} (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.mediaItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        server_id INTEGER,
        batch_id INTEGER NOT NULL,
        local_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
        sort_order INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES ${DatabaseTables.mediaBatches} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_media_batches_user ON ${DatabaseTables.mediaBatches} (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_media_batches_mission ON ${DatabaseTables.mediaBatches} (mission_id)',
    );
    await db.execute(
      'CREATE INDEX idx_media_batches_cld ON ${DatabaseTables.mediaBatches} (cld_id)',
    );
    await db.execute(
      'CREATE INDEX idx_media_batches_sync_status ON ${DatabaseTables.mediaBatches} (sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_media_items_batch ON ${DatabaseTables.mediaItems} (batch_id)',
    );
  }
}
