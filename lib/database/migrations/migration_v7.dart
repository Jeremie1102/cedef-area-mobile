import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Étape 7 — Architecture de synchronisation Offline/Online.
///
/// * `sync_meta` : petite table clé/valeur pour les informations globales de
///   synchronisation (par exemple la date de la dernière synchronisation
///   réussie) — inutile de créer une table dédiée à une seule valeur pour
///   chaque information de ce type ;
/// * un index sur `sync_queue (entity_table, entity_local_id)` : la file
///   d'attente est systématiquement consultée par entité pour éviter d'y
///   ajouter des doublons (voir `SyncQueueRepository.addToQueue`).
///
/// N'altère jamais les données existantes : uniquement des ajouts.
class MigrationV7 {
  MigrationV7._();

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.syncMeta} (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sync_queue_entity ON ${DatabaseTables.syncQueue} (entity_table, entity_local_id)',
    );
  }
}
