import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/gps_position.dart';
import 'package:cedef_area/models/mission.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/repositories/gps_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent [GpsRepository] (positions GPS) au-dessus d'une vraie
/// base SQLite via `sqflite_common_ffi` (voir `auth_service_test.dart` pour
/// le principe).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final gpsRepository = GpsRepository();
  final missionRepository = MissionRepository();
  final userRepository = UserRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_gps_repository.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

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

  Future<int> insertMission() async {
    final now = DateTime.now();
    return missionRepository.insert(
      Mission(
        localId: IdGenerator.generate(),
        titre: 'Sensibilisation communautaire',
        statut: MissionStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> insertPosition({
    required int missionId,
    required int userId,
    required DateTime recordedAt,
    double latitude = -4.3276,
    double longitude = 15.3136,
    SyncStatus syncStatus = SyncStatus.pending,
  }) {
    return gpsRepository.insert(
      GpsPosition(
        localId: IdGenerator.generate(),
        missionId: missionId,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        accuracy: 10,
        recordedAt: recordedAt,
        syncStatus: syncStatus,
        createdAt: recordedAt,
      ),
    );
  }

  test('crée une position et la retrouve parmi celles de la mission', () async {
    final userId = await insertUser();
    final missionId = await insertMission();
    final now = DateTime.now();

    await insertPosition(missionId: missionId, userId: userId, recordedAt: now);

    final positions = await gpsRepository.findByMission(missionId);

    expect(positions, hasLength(1));
    expect(positions.first.missionId, missionId);
    expect(positions.first.latitude, -4.3276);
  });

  test('les positions d\'une mission sont ordonnées de la plus ancienne à la plus récente', () async {
    final userId = await insertUser();
    final missionId = await insertMission();
    final now = DateTime.now();

    await insertPosition(missionId: missionId, userId: userId, recordedAt: now.add(const Duration(minutes: 2)));
    await insertPosition(missionId: missionId, userId: userId, recordedAt: now);
    await insertPosition(missionId: missionId, userId: userId, recordedAt: now.add(const Duration(minutes: 1)));

    final positions = await gpsRepository.findByMission(missionId);

    expect(
      positions.map((p) => p.recordedAt),
      orderedEquals([now, now.add(const Duration(minutes: 1)), now.add(const Duration(minutes: 2))]),
    );
  });

  test('retrouve les positions d\'un utilisateur, toutes missions confondues', () async {
    final userId = await insertUser();
    final autreUserId = await insertUser();
    final missionId = await insertMission();
    final now = DateTime.now();

    await insertPosition(missionId: missionId, userId: userId, recordedAt: now);
    await insertPosition(missionId: missionId, userId: autreUserId, recordedAt: now);

    final positions = await gpsRepository.findByUser(userId);

    expect(positions, hasLength(1));
    expect(positions.first.userId, userId);
  });

  test('retrouve la dernière position d\'une mission', () async {
    final userId = await insertUser();
    final missionId = await insertMission();
    final now = DateTime.now();

    await insertPosition(missionId: missionId, userId: userId, recordedAt: now, latitude: -4.30);
    await insertPosition(
      missionId: missionId,
      userId: userId,
      recordedAt: now.add(const Duration(minutes: 5)),
      latitude: -4.40,
    );

    final last = await gpsRepository.findLastForMission(missionId);

    expect(last, isNotNull);
    expect(last!.latitude, -4.40);
  });

  test('aucune dernière position si la mission n\'en a aucune', () async {
    final missionId = await insertMission();

    final last = await gpsRepository.findLastForMission(missionId);

    expect(last, isNull);
  });

  test('filtre les positions non synchronisées', () async {
    final userId = await insertUser();
    final missionId = await insertMission();
    final now = DateTime.now();

    await insertPosition(missionId: missionId, userId: userId, recordedAt: now, syncStatus: SyncStatus.pending);
    await insertPosition(
      missionId: missionId,
      userId: userId,
      recordedAt: now,
      syncStatus: SyncStatus.synced,
    );

    final pending = await gpsRepository.findPendingSync();

    expect(pending, hasLength(1));
    expect(pending.first.syncStatus, SyncStatus.pending);
  });

  group('findPendingOrFailedSync', () {
    test('inclut pending et failed, jamais synced ni syncing, dans l\'ordre chronologique', () async {
      final userId = await insertUser();
      final missionId = await insertMission();
      final now = DateTime.now();

      final pendingId = await insertPosition(
        missionId: missionId,
        userId: userId,
        recordedAt: now.add(const Duration(minutes: 2)),
        syncStatus: SyncStatus.pending,
      );
      final failedId = await insertPosition(
        missionId: missionId,
        userId: userId,
        recordedAt: now,
        syncStatus: SyncStatus.failed,
      );
      await insertPosition(
        missionId: missionId,
        userId: userId,
        recordedAt: now,
        syncStatus: SyncStatus.synced,
      );
      await insertPosition(
        missionId: missionId,
        userId: userId,
        recordedAt: now,
        syncStatus: SyncStatus.syncing,
      );

      final toRetry = await gpsRepository.findPendingOrFailedSync();

      expect(toRetry.map((p) => p.id), [failedId, pendingId]);
    });
  });

  group('updateSyncStatus / markSynced / countPendingOrFailedSync', () {
    test('updateSyncStatus applique le statut à plusieurs positions à la fois', () async {
      final userId = await insertUser();
      final missionId = await insertMission();
      final now = DateTime.now();
      final id1 = await insertPosition(missionId: missionId, userId: userId, recordedAt: now);
      final id2 = await insertPosition(missionId: missionId, userId: userId, recordedAt: now);

      await gpsRepository.updateSyncStatus([id1, id2], SyncStatus.syncing);

      expect((await gpsRepository.getById(id1))!.syncStatus, SyncStatus.syncing);
      expect((await gpsRepository.getById(id2))!.syncStatus, SyncStatus.syncing);
    });

    test('markSynced enregistre le server_id et passe la position à synced', () async {
      final userId = await insertUser();
      final missionId = await insertMission();
      final id = await insertPosition(missionId: missionId, userId: userId, recordedAt: DateTime.now());

      await gpsRepository.markSynced(id: id, serverId: 501);

      final updated = await gpsRepository.getById(id);
      expect(updated!.syncStatus, SyncStatus.synced);
      expect(updated.serverId, 501);
    });

    test('countPendingOrFailedSync compte pending et failed, jamais synced', () async {
      final userId = await insertUser();
      final missionId = await insertMission();
      final now = DateTime.now();
      await insertPosition(missionId: missionId, userId: userId, recordedAt: now, syncStatus: SyncStatus.pending);
      await insertPosition(missionId: missionId, userId: userId, recordedAt: now, syncStatus: SyncStatus.failed);
      await insertPosition(missionId: missionId, userId: userId, recordedAt: now, syncStatus: SyncStatus.synced);

      expect(await gpsRepository.countPendingOrFailedSync(), 2);
    });
  });

  group('findTrackSummaryRowsByUser', () {
    test('une ligne par mission, du parcours le plus récent au plus ancien', () async {
      final userId = await insertUser();
      final missionA = await insertMission();
      final missionB = await insertMission();
      final now = DateTime.now();

      await insertPosition(missionId: missionA, userId: userId, recordedAt: now.subtract(const Duration(days: 2)));
      await insertPosition(
        missionId: missionA,
        userId: userId,
        recordedAt: now.subtract(const Duration(days: 2)).add(const Duration(minutes: 10)),
      );
      await insertPosition(missionId: missionB, userId: userId, recordedAt: now);

      final rows = await gpsRepository.findTrackSummaryRowsByUser(userId);

      expect(rows, hasLength(2));
      expect(rows.first['mission_id'], missionB);
      expect(rows.first['position_count'], 1);
      expect(rows.last['mission_id'], missionA);
      expect(rows.last['position_count'], 2);
    });

    test('compte les positions encore en attente de synchronisation', () async {
      final userId = await insertUser();
      final missionId = await insertMission();
      final now = DateTime.now();

      await insertPosition(missionId: missionId, userId: userId, recordedAt: now, syncStatus: SyncStatus.pending);
      await insertPosition(
        missionId: missionId,
        userId: userId,
        recordedAt: now.add(const Duration(minutes: 1)),
        syncStatus: SyncStatus.synced,
      );

      final rows = await gpsRepository.findTrackSummaryRowsByUser(userId);

      expect(rows, hasLength(1));
      expect(rows.first['pending_count'], 1);
    });

    test('ignore les positions d\'un autre utilisateur', () async {
      final userId = await insertUser();
      final autreUserId = await insertUser();
      final missionId = await insertMission();
      final now = DateTime.now();

      await insertPosition(missionId: missionId, userId: autreUserId, recordedAt: now);

      final rows = await gpsRepository.findTrackSummaryRowsByUser(userId);

      expect(rows, isEmpty);
    });
  });
}
