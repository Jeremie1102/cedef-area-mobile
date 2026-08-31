import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/cld.dart';
import 'package:cedef_area/models/groupement.dart';
import 'package:cedef_area/models/media_batch.dart';
import 'package:cedef_area/models/media_item.dart';
import 'package:cedef_area/models/mission.dart';
import 'package:cedef_area/models/secteur.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/models/village.dart';
import 'package:cedef_area/repositories/cld_repository.dart';
import 'package:cedef_area/repositories/groupement_repository.dart';
import 'package:cedef_area/repositories/media_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/secteur_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/repositories/village_repository.dart';
import 'package:cedef_area/services/connectivity_service.dart';
import 'package:cedef_area/services/media_api_service.dart';
import 'package:cedef_area/services/media_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_api_client.dart';

/// Ces tests exercent [MediaSyncService] : recherche des lots à envoyer,
/// envoi réussi (mise à jour `server_id`/statut du lot et de ses photos),
/// gestion des erreurs (réseau, 403, 422, 401), traitement séquentiel de
/// plusieurs lots et reprise après échec. Aucun appel réseau réel : voir
/// `FakeApiClient`, injecté dans un vrai `MediaApiService`.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MediaRepository mediaRepository;
  late MissionRepository missionRepository;
  late CldRepository cldRepository;
  late VillageRepository villageRepository;
  late UserRepository userRepository;
  late SecteurRepository secteurRepository;
  late GroupementRepository groupementRepository;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_media_sync_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    mediaRepository = MediaRepository();
    missionRepository = MissionRepository();
    cldRepository = CldRepository();
    villageRepository = VillageRepository();
    userRepository = UserRepository();
    secteurRepository = SecteurRepository();
    groupementRepository = GroupementRepository();
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

  Future<int> insertMission({int? serverId}) async {
    final now = DateTime.now();
    return missionRepository.insert(
      Mission(
        localId: IdGenerator.generate(),
        serverId: serverId,
        titre: 'Sensibilisation communautaire',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> insertCld({int? serverId}) async {
    final now = DateTime.now();
    final secteurId = await secteurRepository.insert(
      Secteur(localId: IdGenerator.generate(), nom: 'Ngeba', createdAt: now, updatedAt: now),
    );
    final groupementId = await groupementRepository.insert(
      Groupement(
        localId: IdGenerator.generate(),
        secteurId: secteurId,
        nom: 'Groupement A',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return cldRepository.insert(
      Cld(
        localId: IdGenerator.generate(),
        serverId: serverId,
        groupementId: groupementId,
        nom: 'CLD Kimpemba',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> insertVillage({int? serverId, required int cldId}) async {
    final now = DateTime.now();
    return villageRepository.insert(
      Village(
        localId: IdGenerator.generate(),
        serverId: serverId,
        cldId: cldId,
        nom: 'Mbanza',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> insertBatch({
    required int userId,
    required int missionId,
    int? cldId,
    int? villageId,
  }) async {
    final now = DateTime.now();
    return mediaRepository.insertBatch(
      MediaBatch(
        localId: IdGenerator.generate(),
        userId: userId,
        missionId: missionId,
        cldId: cldId,
        villageId: villageId,
        description: 'Une activité de terrain.',
        capturedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<MediaItem> insertItem(int batchId) async {
    final now = DateTime.now();
    final localId = IdGenerator.generate();
    final id = await mediaRepository.insertItem(
      MediaItem(
        localId: localId,
        batchId: batchId,
        localPath: '/tmp/$localId.jpg',
        fileName: '$localId.jpg',
        fileSize: 1024,
        mimeType: 'image/jpeg',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await mediaRepository.getItemById(id))!;
  }

  Map<String, dynamic> successResponse({required int serverBatchId, Map<String, int>? itemIds}) {
    return {
      'message': 'Lot synchronisé avec succès.',
      'batch': {
        'id': serverBatchId,
        'local_id': 'ignored',
        'items': (itemIds ?? const {}).entries
            .map((e) => {'local_id': e.key, 'id': e.value})
            .toList(),
      },
    };
  }

  MediaSyncService buildService({required FakeApiClient client, ConnectivityService? connectivity}) {
    return MediaSyncService(
      mediaRepository: mediaRepository,
      missionRepository: missionRepository,
      cldRepository: cldRepository,
      villageRepository: villageRepository,
      connectivityService: connectivity ?? onlineService(),
      apiService: MediaApiService(client: client),
    );
  }

  test('ne tente rien hors ligne et conserve les lots en attente', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);

    final service = buildService(client: FakeApiClient(), connectivity: offlineService());

    final summary = await service.syncPendingBatches();

    expect(summary.outcome, MediaSyncOutcome.offline);
    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.syncStatus, SyncStatus.pending);
  });

  test('synchronise un lot en attente : server_id et statut mis à jour, local_id conservé', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    final item = await insertItem(batchId);
    final originalLocalId = (await mediaRepository.getBatchById(batchId))!.localId;

    final fakeClient = FakeApiClient(
      responses: {
        'POST /media-batches': successResponse(
          serverBatchId: 555,
          itemIds: {item.localId: 999},
        ),
      },
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.outcome, MediaSyncOutcome.completed);
    expect(summary.synced, 1);
    expect(summary.failed, 0);

    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.syncStatus, SyncStatus.synced);
    expect(batch.serverId, 555);
    expect(batch.localId, originalLocalId);

    final updatedItem = await mediaRepository.getItemById(item.id!);
    expect(updatedItem!.syncStatus, SyncStatus.synced);
    expect(updatedItem.serverId, 999);
    expect(updatedItem.localId, item.localId);
  });

  test('envoie le CLD et le village résolus par leur server_id', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final cldId = await insertCld(serverId: 7);
    final villageId = await insertVillage(serverId: 21, cldId: cldId);
    final batchId = await insertBatch(
      userId: userId,
      missionId: missionId,
      cldId: cldId,
      villageId: villageId,
    );
    final item = await insertItem(batchId);

    final fakeClient = FakeApiClient(
      responses: {'POST /media-batches': successResponse(serverBatchId: 1, itemIds: {item.localId: 1})},
    );
    final service = buildService(client: fakeClient);

    await service.syncPendingBatches();

    expect(fakeClient.lastMultipartFields!['mission_id'], '100');
    expect(fakeClient.lastMultipartFields!['cld_id'], '7');
    expect(fakeClient.lastMultipartFields!['village_id'], '21');
  });

  test('une mission jamais synchronisée (sans server_id) fait échouer le lot proprement', () async {
    final userId = await insertUser();
    final missionId = await insertMission(); // pas de serverId
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);

    final service = buildService(client: FakeApiClient());

    final summary = await service.syncPendingBatches();

    expect(summary.failed, 1);
    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.syncStatus, SyncStatus.failed);
  });

  test('une erreur réseau marque le lot failed et le conserve localement', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);

    final fakeClient = FakeApiClient(errors: {'POST /media-batches': const NetworkException()});
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.failed, 1);
    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch, isNotNull); // jamais supprimé localement
    expect(batch!.syncStatus, SyncStatus.failed);
  });

  test('un 403 (accès refusé) marque le lot failed', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);

    final fakeClient = FakeApiClient(errors: {'POST /media-batches': const ForbiddenException()});
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.failed, 1);
    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.syncStatus, SyncStatus.failed);
  });

  test('un 422 (validation) marque le lot failed', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);

    final fakeClient = FakeApiClient(
      errors: {
        'POST /media-batches': const ApiValidationException('Champs invalides.', {
          'description': ['La description est obligatoire.'],
        }),
      },
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.failed, 1);
    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.syncStatus, SyncStatus.failed);
  });

  test('un 401 arrête la synchronisation sans marquer le lot en échec (session, pas le lot)', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batch1Id = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batch1Id);
    final batch2Id = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batch2Id);

    final fakeClient = FakeApiClient(errors: {'POST /media-batches': const UnauthorizedException()});
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.outcome, MediaSyncOutcome.sessionExpired);
    final batch1 = await mediaRepository.getBatchById(batch1Id);
    final batch2 = await mediaRepository.getBatchById(batch2Id);
    expect(batch1!.syncStatus, SyncStatus.pending);
    expect(batch2!.syncStatus, SyncStatus.pending);
    // Un seul appel : le deuxième lot n'est jamais tenté après le 401.
    expect(fakeClient.calledPaths, hasLength(1));
  });

  test('plusieurs lots sont traités un par un, jamais en une seule requête groupée', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batch1Id = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batch1Id);
    final batch2Id = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batch2Id);
    final batch3Id = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batch3Id);

    final fakeClient = FakeApiClient(
      responses: {'POST /media-batches': successResponse(serverBatchId: 1)},
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.synced, 3);
    expect(fakeClient.calledPaths, hasLength(3));
    for (final id in [batch1Id, batch2Id, batch3Id]) {
      expect((await mediaRepository.getBatchById(id))!.syncStatus, SyncStatus.synced);
    }
  });

  test('reprise : un lot en échec est retenté au prochain appel', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    final item = await insertItem(batchId);

    final failingClient = FakeApiClient(errors: {'POST /media-batches': const NetworkException()});
    final firstAttempt = await buildService(client: failingClient).syncPendingBatches();
    expect(firstAttempt.failed, 1);
    expect((await mediaRepository.getBatchById(batchId))!.syncStatus, SyncStatus.failed);

    final workingClient = FakeApiClient(
      responses: {
        'POST /media-batches': successResponse(serverBatchId: 42, itemIds: {item.localId: 1}),
      },
    );
    final secondAttempt = await buildService(client: workingClient).syncPendingBatches();

    expect(secondAttempt.synced, 1);
    expect((await mediaRepository.getBatchById(batchId))!.syncStatus, SyncStatus.synced);
  });

  test('ne relance rien si aucun lot n\'est en attente ou en échec', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);
    final batch = (await mediaRepository.getBatchById(batchId))!;
    await mediaRepository.updateBatch(batch.copyWith(syncStatus: SyncStatus.synced));

    final fakeClient = FakeApiClient();
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingBatches();

    expect(summary.outcome, MediaSyncOutcome.completed);
    expect(summary.synced, 0);
    expect(fakeClient.calledPaths, isEmpty);
  });

  test('ne lance pas deux synchronisations en parallèle', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final batchId = await insertBatch(userId: userId, missionId: missionId);
    await insertItem(batchId);

    final fakeClient = FakeApiClient(
      responses: {'POST /media-batches': successResponse(serverBatchId: 1)},
    );
    final service = buildService(client: fakeClient);

    final first = service.syncPendingBatches();
    final second = await service.syncPendingBatches();
    final firstResult = await first;

    expect(second.outcome, MediaSyncOutcome.alreadyRunning);
    expect(firstResult.outcome, MediaSyncOutcome.completed);
  });
}
