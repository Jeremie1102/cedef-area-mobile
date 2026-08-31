import 'package:sqflite/sqflite.dart';

import '../database_tables.dart';

/// Étape 5 — GPS et suivi des déplacements.
///
/// Complète `gps_positions` (créée par [MigrationV1]) avec la vitesse, le
/// cap et un `created_at` propre (jusqu'ici seul `recorded_at` existait, ce
/// qui ne permettait pas de distinguer l'horodatage du relevé lui-même de
/// celui de son enregistrement local) ; ajoute les index nécessaires pour
/// retrouver rapidement la dernière position d'une mission et les positions
/// non synchronisées.
///
/// N'altère jamais les données existantes : uniquement des ajouts. Aucune
/// position réelle n'a encore été enregistrée à ce stade du projet (le
/// suivi GPS n'existait pas avant cette étape), `created_at` est malgré tout
/// rétro-rempli à partir de `recorded_at` par prudence.
class MigrationV6 {
  MigrationV6._();

  static Future<void> up(Database db) async {
    await db.execute('ALTER TABLE ${DatabaseTables.gpsPositions} ADD COLUMN speed REAL');
    await db.execute('ALTER TABLE ${DatabaseTables.gpsPositions} ADD COLUMN heading REAL');
    await db.execute('ALTER TABLE ${DatabaseTables.gpsPositions} ADD COLUMN created_at TEXT');
    await db.execute(
      'UPDATE ${DatabaseTables.gpsPositions} SET created_at = recorded_at WHERE created_at IS NULL',
    );

    await db.execute(
      'CREATE INDEX idx_gps_positions_recorded_at ON ${DatabaseTables.gpsPositions} (recorded_at)',
    );
    await db.execute(
      'CREATE INDEX idx_gps_positions_sync_status ON ${DatabaseTables.gpsPositions} (sync_status)',
    );
  }
}
