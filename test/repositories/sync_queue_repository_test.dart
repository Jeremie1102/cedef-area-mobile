import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/database/database_tables.dart';
import 'package:cedef_area/repositories/sync_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent [SyncQueueRepository] : ajout à la file d'attente,
/// anti-doublon, transitions de statut, historique et métadonnées de
/// synchronisation — voir `test/services/sync_service_test.dart` pour le
/// traitement effectif de la file par [SyncService].
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final repository = SyncQueueRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_sync_queue_repository.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('ajoute une opération à la file et la retrouve parmi les éléments en attente', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-1',
      operation: SyncOperation.create,
    );

    final pending = await repository.getPendingItems();
    expect(pending, hasLength(1));
    expect(pending.first.entityTable, DatabaseTables.mediaBatches);
    expect(pending.first.entityLocalId, 'batch-1');
    expect(pending.first.operation, SyncOperation.create);
    expect(pending.first.status, SyncStatus.pending);
  });

  test('passe une entrée à syncing puis à synced', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.gpsPositions,
      entityLocalId: 'gps-1',
      operation: SyncOperation.create,
    );
    final id = (await repository.getPendingItems()).first.id!;

    await repository.markAsSyncing(id);
    final syncing = (await repository.getRecentHistory());
    // `syncing` n'apparaît pas dans l'historique (réservé à synced/failed) :
    // on vérifie plutôt qu'elle n'est plus comptée comme pending.
    expect(syncing, isEmpty);
    expect(await repository.countPending(), 0);

    await repository.markAsSynced(id);
    final history = await repository.getRecentHistory();
    expect(history, hasLength(1));
    expect(history.first.status, SyncStatus.synced);
  });

  test('un échec incrémente les tentatives et enregistre l\'erreur, sans supprimer l\'entrée', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-2',
      operation: SyncOperation.create,
    );
    final id = (await repository.getPendingItems()).first.id!;

    await repository.markAsFailed(id, error: 'Erreur réseau');

    final history = await repository.getRecentHistory();
    expect(history, hasLength(1));
    expect(history.first.status, SyncStatus.failed);
    expect(history.first.attempts, 1);
    expect(history.first.lastError, 'Erreur réseau');
  });

  test('une nouvelle tentative après échec peut de nouveau réussir', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-3',
      operation: SyncOperation.create,
    );
    final id = (await repository.getPendingItems()).first.id!;

    await repository.markAsFailed(id, error: 'Timeout');
    await repository.markAsSyncing(id);
    await repository.markAsSynced(id);

    final history = await repository.getRecentHistory();
    expect(history.first.status, SyncStatus.synced);
    expect(history.first.attempts, 1);
  });

  test('incrementAttempts augmente le compteur sans changer le statut', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-4',
      operation: SyncOperation.create,
    );
    final id = (await repository.getPendingItems()).first.id!;

    await repository.incrementAttempts(id);
    await repository.incrementAttempts(id);

    final pending = await repository.getPendingItems();
    expect(pending.first.attempts, 2);
    expect(pending.first.status, SyncStatus.pending);
  });

  test('plusieurs éléments dans la file sont tous retrouvés', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-a',
      operation: SyncOperation.create,
    );
    await repository.addToQueue(
      entityTable: DatabaseTables.gpsPositions,
      entityLocalId: 'gps-a',
      operation: SyncOperation.create,
    );
    await repository.addToQueue(
      entityTable: DatabaseTables.gpsPositions,
      entityLocalId: 'gps-b',
      operation: SyncOperation.create,
    );

    expect(await repository.countPending(), 3);
  });

  test('respecte l\'ordre de dépendance : missions avant GPS avant lots avant photos', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaItems,
      entityLocalId: 'item-1',
      operation: SyncOperation.create,
    );
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-1',
      operation: SyncOperation.create,
    );
    await repository.addToQueue(
      entityTable: DatabaseTables.gpsPositions,
      entityLocalId: 'gps-1',
      operation: SyncOperation.create,
    );
    await repository.addToQueue(
      entityTable: DatabaseTables.missions,
      entityLocalId: 'mission-1',
      operation: SyncOperation.start,
    );

    final ordered = await repository.getPendingItems();
    expect(ordered.map((e) => e.entityTable), [
      DatabaseTables.missions,
      DatabaseTables.gpsPositions,
      DatabaseTables.mediaBatches,
      DatabaseTables.mediaItems,
    ]);
  });

  group('anti-doublon (section 12)', () {
    test('deux create successifs pour la même entité ne créent qu\'une seule entrée', () async {
      await repository.addToQueue(
        entityTable: DatabaseTables.mediaBatches,
        entityLocalId: 'batch-dup',
        operation: SyncOperation.create,
        payload: {'v': 1},
      );
      await repository.addToQueue(
        entityTable: DatabaseTables.mediaBatches,
        entityLocalId: 'batch-dup',
        operation: SyncOperation.create,
        payload: {'v': 2},
      );

      final pending = await repository.getPendingItems();
      expect(pending, hasLength(1));
      expect(pending.first.payload?['v'], 2);
    });

    test('un update sur une entité déjà pending remplace l\'entrée existante', () async {
      await repository.addToQueue(
        entityTable: DatabaseTables.mediaBatches,
        entityLocalId: 'batch-upd',
        operation: SyncOperation.update,
      );
      await repository.addToQueue(
        entityTable: DatabaseTables.mediaBatches,
        entityLocalId: 'batch-upd',
        operation: SyncOperation.update,
      );

      expect(await repository.countPending(), 1);
    });

    test('supprimer une entité jamais envoyée retire simplement le create en attente', () async {
      await repository.addToQueue(
        entityTable: DatabaseTables.mediaItems,
        entityLocalId: 'item-never-sent',
        operation: SyncOperation.create,
      );

      await repository.addToQueue(
        entityTable: DatabaseTables.mediaItems,
        entityLocalId: 'item-never-sent',
        operation: SyncOperation.delete,
      );

      expect(await repository.countPending(), 0);
    });

    test('les événements de mission ne sont jamais fusionnés entre eux', () async {
      await repository.addToQueue(
        entityTable: DatabaseTables.missions,
        entityLocalId: 'mission-1',
        operation: SyncOperation.start,
      );
      await repository.addToQueue(
        entityTable: DatabaseTables.missions,
        entityLocalId: 'mission-1',
        operation: SyncOperation.pause,
      );

      expect(await repository.countPending(), 2);
    });
  });

  test('clearSyncedItems ne purge que les entrées synchronisées plus anciennes que la rétention', () async {
    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-old',
      operation: SyncOperation.create,
    );
    final oldId = (await repository.getPendingItems()).first.id!;
    await repository.markAsSynced(oldId);

    await repository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-recent-failed',
      operation: SyncOperation.create,
    );
    final failedId = (await repository.getPendingItems()).first.id!;
    await repository.markAsFailed(failedId, error: 'x');

    // Rétention négative : toute entrée synchronisée est considérée "trop
    // ancienne" immédiatement, pour tester la purge sans dépendre du temps.
    await repository.clearSyncedItems(retention: const Duration(seconds: -1));

    final history = await repository.getRecentHistory();
    expect(history, hasLength(1));
    expect(history.first.status, SyncStatus.failed);
  });

  test('mémorise et retrouve la date de dernière synchronisation', () async {
    expect(await repository.getLastSyncedAt(), isNull);

    final now = DateTime(2026, 8, 27, 14, 32);
    await repository.setLastSyncedAt(now);

    expect(await repository.getLastSyncedAt(), now);
  });
}
