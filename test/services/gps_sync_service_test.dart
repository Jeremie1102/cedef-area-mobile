import 'package:cedef_area/config/app_config.dart';
import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/network/api_client.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/gps_position.dart';
import 'package:cedef_area/models/mission.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/repositories/gps_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/sync_queue_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/services/connectivity_service.dart';
import 'package:cedef_area/services/gps_api_service.dart';
import 'package:cedef_area/services/gps_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_api_client.dart';

/// Client [ApiClient] minimal qui laisse exécuter un hook juste avant de
/// répondre à un `post` — utilisé uniquement pour observer l'état
/// intermédiaire `syncing` d'une position pendant l'appel réseau simulé (voir
/// [FakeApiClient], qui ne permet pas d'observer cet instant).
class _HookedApiClient implements ApiClient {
  final Future<void> Function() beforeRespond;
  final dynamic response;

  _HookedApiClient({required this.beforeRespond, required this.response});

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) => throw UnimplementedError();

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? data}) async {
    await beforeRespond();
    return response;
  }

  @override
  Future<dynamic> postMultipart(String path, {Map<String, dynamic>? fields, List<ApiUploadFile>? files}) =>
      throw UnimplementedError();
}

/// Ces tests exercent [GpsSyncService] : recherche des positions à
/// (re)synchroniser, constitution des lots, transition
/// pending → syncing → synced/failed, gestion des erreurs (réseau, 401, 403,
/// 422), traitement séquentiel de plusieurs lots, idempotence locale et
/// conservation des positions en cas d'échec. Aucun appel réseau réel : voir
/// `FakeApiClient`, injecté dans un vrai `GpsApiService`.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late GpsRepository gpsRepository;
  late MissionRepository missionRepository;
  late UserRepository userRepository;
  late SyncQueueRepository syncQueueRepository;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_gps_sync_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    gpsRepository = GpsRepository();
    missionRepository = MissionRepository();
    userRepository = UserRepository();
    syncQueueRepository = SyncQueueRepository();
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
        statut: MissionStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<GpsPosition> insertPosition({
    required int userId,
    required int missionId,
    DateTime? recordedAt,
  }) async {
    final now = recordedAt ?? DateTime.now();
    final localId = IdGenerator.generate();
    final id = await gpsRepository.insert(
      GpsPosition(
        localId: localId,
        missionId: missionId,
        userId: userId,
        latitude: -4.3276,
        longitude: 15.3136,
        accuracy: 10,
        recordedAt: now,
        createdAt: now,
      ),
    );
    return (await gpsRepository.getById(id))!;
  }

  Map<String, dynamic> responseFor({
    List<String> accepted = const [],
    List<String> alreadySynced = const [],
    Map<String, String> rejected = const {},
    int startServerId = 1,
  }) {
    var nextId = startServerId;
    return {
      'message': 'ok',
      'accepted': accepted.map((localId) => {'local_id': localId, 'id': nextId++, 'uuid': 'u-$localId'}).toList(),
      'already_synced': alreadySynced
          .map((localId) => {'local_id': localId, 'id': nextId++, 'uuid': 'u-$localId'})
          .toList(),
      'rejected': rejected.entries.map((e) => {'local_id': e.key, 'reason': e.value}).toList(),
    };
  }

  GpsSyncService buildService({required ApiClient client, ConnectivityService? connectivity}) {
    return GpsSyncService(
      gpsRepository: gpsRepository,
      missionRepository: missionRepository,
      syncQueueRepository: syncQueueRepository,
      connectivityService: connectivity ?? onlineService(),
      apiService: GpsApiService(client: client),
    );
  }

  test('ne tente rien hors ligne et conserve les positions en attente', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final service = buildService(client: FakeApiClient(), connectivity: offlineService());

    final summary = await service.syncPendingPositions();

    expect(summary.outcome, GpsSyncOutcome.offline);
    expect((await gpsRepository.getById(position.id!))!.syncStatus, SyncStatus.pending);
  });

  test('synchronise une position en attente : server_id et statut mis à jour', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(
      responses: {'POST /gps-positions': responseFor(accepted: [position.localId], startServerId: 501)},
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.outcome, GpsSyncOutcome.completed);
    expect(summary.synced, 1);
    final updated = await gpsRepository.getById(position.id!);
    expect(updated!.syncStatus, SyncStatus.synced);
    expect(updated.serverId, 501);
    expect(updated.localId, position.localId);
  });

  test('passe les positions en syncing pendant l\'envoi du lot', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    SyncStatus? statusDuringCall;
    final client = _HookedApiClient(
      beforeRespond: () async {
        statusDuringCall = (await gpsRepository.getById(position.id!))!.syncStatus;
      },
      response: responseFor(accepted: [position.localId]),
    );
    final service = buildService(client: client);

    await service.syncPendingPositions();

    expect(statusDuringCall, SyncStatus.syncing);
  });

  test('une erreur réseau marque les positions failed et les conserve localement', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(errors: {'POST /gps-positions': const NetworkException()});
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.failed, 1);
    final stillThere = await gpsRepository.getById(position.id!);
    expect(stillThere, isNotNull); // jamais supprimée
    expect(stillThere!.syncStatus, SyncStatus.failed);
    expect(stillThere.latitude, position.latitude); // coordonnées intactes
  });

  test('un 403 (accès refusé) est traité comme un échec, jamais perdu', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(errors: {'POST /gps-positions': const ForbiddenException()});
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.failed, 1);
    expect((await gpsRepository.getById(position.id!))!.syncStatus, SyncStatus.failed);
  });

  test('un 422 (validation) est traité comme un échec, jamais perdu', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(
      errors: {'POST /gps-positions': const ApiValidationException('Champs invalides.', {})},
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.failed, 1);
    expect((await gpsRepository.getById(position.id!))!.syncStatus, SyncStatus.failed);
  });

  test('un 401 arrête la synchronisation et remet les positions à pending (pas failed)', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position1 = await insertPosition(userId: userId, missionId: missionId);
    final position2 = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(errors: {'POST /gps-positions': const UnauthorizedException()});
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.outcome, GpsSyncOutcome.sessionExpired);
    expect((await gpsRepository.getById(position1.id!))!.syncStatus, SyncStatus.pending);
    expect((await gpsRepository.getById(position2.id!))!.syncStatus, SyncStatus.pending);
  });

  test('une position rejetée par le serveur est comptée séparément et conservée', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(
      responses: {
        'POST /gps-positions': responseFor(rejected: {position.localId: 'Latitude hors intervalle.'}),
      },
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.rejected, 1);
    expect((await gpsRepository.getById(position.id!))!.syncStatus, SyncStatus.failed);
  });

  test('idempotence locale : une position déjà connue du serveur (already_synced) est marquée synced', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final fakeClient = FakeApiClient(
      responses: {
        'POST /gps-positions': responseFor(alreadySynced: [position.localId], startServerId: 999),
      },
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.alreadySynced, 1);
    expect(summary.synced, 0);
    final updated = await gpsRepository.getById(position.id!);
    expect(updated!.syncStatus, SyncStatus.synced);
    expect(updated.serverId, 999);
  });

  test('constitue des lots d\'au plus gpsSyncBatchSize positions', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final total = AppConfig.gpsSyncBatchSize + 20;
    for (var i = 0; i < total; i++) {
      await insertPosition(userId: userId, missionId: missionId);
    }
    final allPositions = await gpsRepository.findPendingOrFailedSync();
    final localIds = allPositions.map((p) => p.localId).toList();

    final fakeClient = FakeApiClient(
      responses: {'POST /gps-positions': responseFor(accepted: localIds)},
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    // 2 lots : gpsSyncBatchSize positions puis les 20 restantes.
    expect(fakeClient.calledPaths, hasLength(2));
    expect(summary.synced, total);
  });

  test('plusieurs lots sont traités séquentiellement, jamais en parallèle', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final total = AppConfig.gpsSyncBatchSize * 2;
    for (var i = 0; i < total; i++) {
      await insertPosition(userId: userId, missionId: missionId);
    }
    final localIds = (await gpsRepository.findPendingOrFailedSync()).map((p) => p.localId).toList();

    final fakeClient = FakeApiClient(
      responses: {'POST /gps-positions': responseFor(accepted: localIds)},
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(fakeClient.calledPaths, hasLength(2));
    expect(summary.synced, total);
  });

  test('reprise : une position en échec est retentée au prochain appel', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final failingClient = FakeApiClient(errors: {'POST /gps-positions': const NetworkException()});
    final firstAttempt = await buildService(client: failingClient).syncPendingPositions();
    expect(firstAttempt.failed, 1);
    expect((await gpsRepository.getById(position.id!))!.syncStatus, SyncStatus.failed);

    final workingClient = FakeApiClient(
      responses: {'POST /gps-positions': responseFor(accepted: [position.localId], startServerId: 77)},
    );
    final secondAttempt = await buildService(client: workingClient).syncPendingPositions();

    expect(secondAttempt.synced, 1);
    final updated = await gpsRepository.getById(position.id!);
    expect(updated!.syncStatus, SyncStatus.synced);
    expect(updated.serverId, 77);
  });

  test('une mission jamais synchronisée (sans server_id) fait échouer ses positions sans bloquer les autres', () async {
    final userId = await insertUser();
    final missionSansServeur = await insertMission();
    final missionSynced = await insertMission(serverId: 200);
    final positionBloquee = await insertPosition(userId: userId, missionId: missionSansServeur);
    final positionEnvoyable = await insertPosition(userId: userId, missionId: missionSynced);

    final fakeClient = FakeApiClient(
      responses: {'POST /gps-positions': responseFor(accepted: [positionEnvoyable.localId])},
    );
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.failed, 1);
    expect(summary.synced, 1);
    expect((await gpsRepository.getById(positionBloquee.id!))!.syncStatus, SyncStatus.failed);
    expect((await gpsRepository.getById(positionEnvoyable.id!))!.syncStatus, SyncStatus.synced);
  });

  test('marque l\'entrée sync_queue correspondante comme synced après succès', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);
    await syncQueueRepository.addToQueue(
      entityTable: 'gps_positions',
      entityLocalId: position.localId,
      operation: SyncOperation.create,
    );

    final fakeClient = FakeApiClient(
      responses: {'POST /gps-positions': responseFor(accepted: [position.localId])},
    );
    final service = buildService(client: fakeClient);

    await service.syncPendingPositions();

    expect(await syncQueueRepository.countPending(), 0);
  });

  test('ne relance rien si aucune position n\'est en attente ou en échec', () async {
    final fakeClient = FakeApiClient();
    final service = buildService(client: fakeClient);

    final summary = await service.syncPendingPositions();

    expect(summary.outcome, GpsSyncOutcome.completed);
    expect(summary.synced, 0);
    expect(fakeClient.calledPaths, isEmpty);
  });

  test('ne lance pas deux synchronisations en parallèle', () async {
    final userId = await insertUser();
    final missionId = await insertMission(serverId: 100);
    final position = await insertPosition(userId: userId, missionId: missionId);

    final client = _HookedApiClient(
      beforeRespond: () => Future.delayed(const Duration(milliseconds: 100)),
      response: responseFor(accepted: [position.localId]),
    );
    final service = buildService(client: client);

    final first = service.syncPendingPositions();
    final second = await service.syncPendingPositions();
    final firstResult = await first;

    expect(second.outcome, GpsSyncOutcome.alreadyRunning);
    expect(firstResult.outcome, GpsSyncOutcome.completed);
  });
}
