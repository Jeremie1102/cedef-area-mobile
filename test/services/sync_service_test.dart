import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/database/database_tables.dart';
import 'package:cedef_area/models/media_batch.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/repositories/media_repository.dart';
import 'package:cedef_area/repositories/sync_queue_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/services/bootstrap_api_service.dart';
import 'package:cedef_area/services/connectivity_service.dart';
import 'package:cedef_area/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/mock_sync_provider.dart';

/// Fait échouer `GET /bootstrap` immédiatement, sans dépendre d'un vrai
/// serveur : [SyncService.downloadUpdates] absorbe l'échec et retourne 0,
/// exactement comme hors ligne. Ces tests portent sur le moteur d'envoi
/// (`syncPendingData`), pas sur la synchronisation descendante (voir
/// `downstream_sync_service_test.dart`) — la file d'attente locale ne doit
/// jamais dépendre du téléchargement pour être traitée.
BootstrapApiService emptyBootstrapApiService() {
  return BootstrapApiService(
    client: FakeApiClient(errors: {'GET /bootstrap': const NetworkException()}),
  );
}

/// Ces tests exercent [SyncService] : traitement de la file d'attente,
/// répercussion du résultat sur la donnée locale (`server_id`, `sync_status`),
/// gestion des échecs/timeouts, absence de synchronisation concurrente et
/// comportement hors ligne. [MockSyncProvider] simule l'API Laravel (qui
/// n'existe pas encore) — voir sa documentation.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final queueRepository = SyncQueueRepository();
  final mediaRepository = MediaRepository();
  final userRepository = UserRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_sync_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  ConnectivityService onlineService() => ConnectivityService(
    networkInterfaceChecker: () async => true,
    reachabilityChecker: () async => true,
  );
  ConnectivityService offlineService() => ConnectivityService(
    networkInterfaceChecker: () async => false,
    reachabilityChecker: () async => false,
  );

  Future<int> insertUser() async {
    final now = DateTime.now();
    return userRepository.insert(
      User(
        localId: IdGenerator.generate(),
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        passwordHash: 'x',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> insertPendingBatch(String localId, {required int userId}) async {
    final now = DateTime.now();
    final id = await mediaRepository.insertBatch(
      MediaBatch(
        localId: localId,
        userId: userId,
        activity: 'Réunion',
        capturedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await queueRepository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: localId,
      operation: SyncOperation.create,
    );
    return id;
  }

  test('synchronise un lot en attente et lui attribue un server_id', () async {
    final userId = await insertUser();
    final localId = IdGenerator.generate();
    final batchId = await insertPendingBatch(localId, userId: userId);
    final mock = MockSyncProvider();
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: onlineService(),
      apiProvider: mock,
    );

    final summary = await service.syncAll();

    expect(summary.outcome, SyncOutcome.completed);
    expect(summary.uploaded, 1);
    expect(summary.failed, 0);

    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.syncStatus, SyncStatus.synced);
    expect(batch.serverId, isNotNull);
  });

  test('un échec réseau marque l\'entrée failed et conserve la donnée locale', () async {
    final userId = await insertUser();
    final localId = IdGenerator.generate();
    final batchId = await insertPendingBatch(localId, userId: userId);
    final mock = MockSyncProvider(behaviorFor: (_) => MockSyncBehavior.failure);
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: onlineService(),
      apiProvider: mock,
    );

    final summary = await service.syncAll();

    expect(summary.failed, 1);
    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch, isNotNull); // jamais supprimée localement
    expect(batch!.syncStatus, SyncStatus.pending);

    final history = await queueRepository.getRecentHistory();
    expect(history.first.status, SyncStatus.failed);
    expect(history.first.lastError, isNotNull);
  });

  test('un timeout est traité comme un échec, pas comme un blocage', () async {
    final userId = await insertUser();
    final localId = IdGenerator.generate();
    await insertPendingBatch(localId, userId: userId);
    final mock = MockSyncProvider(
      behaviorFor: (_) => MockSyncBehavior.timeout,
      timeoutDelay: const Duration(seconds: 5),
    );
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: onlineService(),
      apiProvider: mock,
      sendTimeout: const Duration(milliseconds: 100),
    );

    final summary = await service.syncAll();

    expect(summary.outcome, SyncOutcome.completed);
    expect(summary.failed, 1);
  });

  test('ne tente rien hors ligne', () async {
    final userId = await insertUser();
    final localId = IdGenerator.generate();
    await insertPendingBatch(localId, userId: userId);
    final mock = MockSyncProvider();
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: offlineService(),
      apiProvider: mock,
    );

    final summary = await service.syncAll();

    expect(summary.outcome, SyncOutcome.offline);
    expect(mock.sentEntries, isEmpty);
    expect(await queueRepository.countPending(), 1);
  });

  test('ne lance pas deux synchronisations en parallèle', () async {
    final userId = await insertUser();
    for (var i = 0; i < 3; i++) {
      await insertPendingBatch(IdGenerator.generate(), userId: userId);
    }
    final mock = MockSyncProvider(timeoutDelay: const Duration(milliseconds: 200));
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: onlineService(),
      apiProvider: mock,
    );

    final first = service.syncAll();
    final second = await service.syncAll();
    final firstResult = await first;

    expect(second.outcome, SyncOutcome.alreadyRunning);
    expect(firstResult.outcome, SyncOutcome.completed);
  });

  test('reprend après une interruption : seules les entrées encore pending sont retraitées', () async {
    final userId = await insertUser();
    final localId1 = IdGenerator.generate();
    final localId2 = IdGenerator.generate();
    await insertPendingBatch(localId1, userId: userId);
    await insertPendingBatch(localId2, userId: userId);

    // Première synchronisation : simule une interruption après le premier
    // élément (le second reste "syncing", comme si l'application avait été
    // fermée en plein envoi).
    final firstItems = await queueRepository.getPendingItems();
    await queueRepository.markAsSynced(firstItems[0].id!);
    await queueRepository.markAsSyncing(firstItems[1].id!);

    expect(await queueRepository.countPending(), 0);

    // Au prochain lancement, l'entrée restée "syncing" doit être retraitée :
    // on la repasse "pending" (ce qu'un vrai redémarrage ferait au moment de
    // relire la file, une entrée "syncing" ne pouvant pas survivre à la
    // fermeture de l'application).
    await queueRepository.markAsFailed(firstItems[1].id!, error: 'Application fermée pendant l\'envoi.');

    final mock = MockSyncProvider();
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: onlineService(),
      apiProvider: mock,
    );

    // L'entrée "failed" est retentée automatiquement au prochain passage :
    // on simule cela en la repassant en attente puis en relançant la sync.
    await queueRepository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: localId2,
      operation: SyncOperation.create,
    );

    final summary = await service.syncAll();

    expect(summary.uploaded, 1);
    expect(mock.sentEntries, hasLength(1));
    expect(mock.sentEntries.first.entityLocalId, localId2);
  });

  test('synchronise plusieurs éléments dans l\'ordre missions puis GPS puis médias', () async {
    final now = DateTime.now();
    await queueRepository.addToQueue(
      entityTable: DatabaseTables.mediaBatches,
      entityLocalId: 'batch-x',
      operation: SyncOperation.create,
    );
    await queueRepository.addToQueue(
      entityTable: DatabaseTables.gpsPositions,
      entityLocalId: 'gps-x',
      operation: SyncOperation.create,
    );
    await queueRepository.addToQueue(
      entityTable: DatabaseTables.missions,
      entityLocalId: 'mission-x',
      operation: SyncOperation.start,
      payload: {'occurred_at': now.toIso8601String()},
    );

    final mock = MockSyncProvider();
    final service = SyncService(
      queueRepository: queueRepository,
      bootstrapApiService: emptyBootstrapApiService(),
      connectivityService: onlineService(),
      apiProvider: mock,
    );

    await service.syncAll();

    expect(mock.sentEntries.map((e) => e.entityTable), [
      DatabaseTables.missions,
      DatabaseTables.gpsPositions,
      DatabaseTables.mediaBatches,
    ]);
  });
}
