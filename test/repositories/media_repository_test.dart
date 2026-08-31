import 'package:cedef_area/core/constants/app_constants.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent la nouvelle architecture des médias (un lot regroupant
/// plusieurs photos, au lieu d'une photo isolée) au-dessus d'une vraie base
/// SQLite via `sqflite_common_ffi` (voir `auth_service_test.dart` pour le
/// principe).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final mediaRepository = MediaRepository();
  final userRepository = UserRepository();
  final secteurRepository = SecteurRepository();
  final groupementRepository = GroupementRepository();
  final cldRepository = CldRepository();
  final villageRepository = VillageRepository();
  final missionRepository = MissionRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_media_repository.db';
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

  Future<int> insertBatch(int userId, {String? activity}) async {
    final now = DateTime.now();
    return mediaRepository.insertBatch(
      MediaBatch(
        localId: IdGenerator.generate(),
        userId: userId,
        activity: activity ?? 'Sensibilisation communautaire',
        description: 'Séance de sensibilisation du CLD.',
        capturedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Insère Secteur > Groupement > CLD > Village et une mission couvrant ce
  /// CLD, pour les tests qui vérifient l'association d'un lot à un
  /// territoire réel (les colonnes `media_batches.*_id` sont contraintes par
  /// des clés étrangères).
  Future<(int secteurId, int groupementId, int cldId, int villageId, int missionId)>
  insertHierarchy() async {
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
    final cldId = await cldRepository.insert(
      Cld(
        localId: IdGenerator.generate(),
        groupementId: groupementId,
        nom: 'CLD Ngeba 001',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final villageId = await villageRepository.insert(
      Village(
        localId: IdGenerator.generate(),
        cldId: cldId,
        nom: 'Kimpemba',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final missionId = await missionRepository.insert(
      Mission(
        localId: IdGenerator.generate(),
        titre: 'Sensibilisation Saison A',
        secteurId: secteurId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (secteurId, groupementId, cldId, villageId, missionId);
  }

  Future<void> insertItem(int batchId, int sortOrder) async {
    final now = DateTime.now();
    await mediaRepository.insertItem(
      MediaItem(
        localId: IdGenerator.generate(),
        batchId: batchId,
        localPath: '/tmp/photo_$sortOrder.jpg',
        fileName: 'photo_$sortOrder.jpg',
        fileSize: 1024,
        mimeType: 'image/jpeg',
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('crée un lot et le retrouve par id', () async {
    final userId = await insertUser();
    final batchId = await insertBatch(userId);

    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch, isNotNull);
    expect(batch!.activity, 'Sensibilisation communautaire');
    expect(batch.userId, userId);
  });

  test('un lot regroupe plusieurs photos (media_items)', () async {
    final userId = await insertUser();
    final batchId = await insertBatch(userId);

    await insertItem(batchId, 0);
    await insertItem(batchId, 1);
    await insertItem(batchId, 2);

    final items = await mediaRepository.getItemsByBatch(batchId);
    expect(items, hasLength(3));
    expect(items.map((i) => i.sortOrder), orderedEquals([0, 1, 2]));
  });

  test('les résumés de lots exposent le nombre de photos et l\'aperçu', () async {
    final userId = await insertUser();
    final batchId = await insertBatch(userId);
    await insertItem(batchId, 0);
    await insertItem(batchId, 1);

    final summaries = await mediaRepository.getBatchSummariesByUser(userId);
    expect(summaries, hasLength(1));
    expect(summaries.first.itemCount, 2);
    expect(summaries.first.coverPath, '/tmp/photo_0.jpg');
  });

  test('compte les lots en attente de synchronisation', () async {
    final userId = await insertUser();
    await insertBatch(userId, activity: 'Réunion');
    await insertBatch(userId, activity: 'Plantation');

    final pendingCount = await mediaRepository.countPendingSyncBatches();
    expect(pendingCount, 2);

    final synced = await mediaRepository.getBatchById(
      (await mediaRepository.getPendingSyncBatches()).first.id!,
    );
    await mediaRepository.updateBatch(synced!.copyWith(syncStatus: SyncStatus.synced));

    expect(await mediaRepository.countPendingSyncBatches(), 1);
  });

  test('getPendingOrFailedSyncBatches inclut les lots en attente et en échec, jamais les synchronisés', () async {
    final userId = await insertUser();
    final pendingId = await insertBatch(userId, activity: 'En attente');
    final failedId = await insertBatch(userId, activity: 'En échec');
    final syncedId = await insertBatch(userId, activity: 'Synchronisé');

    final failed = (await mediaRepository.getBatchById(failedId))!;
    await mediaRepository.updateBatch(failed.copyWith(syncStatus: SyncStatus.failed));
    final synced = (await mediaRepository.getBatchById(syncedId))!;
    await mediaRepository.updateBatch(synced.copyWith(syncStatus: SyncStatus.synced));

    final toRetry = await mediaRepository.getPendingOrFailedSyncBatches();

    expect(toRetry.map((b) => b.id), containsAll([pendingId, failedId]));
    expect(toRetry.map((b) => b.id), isNot(contains(syncedId)));
  });

  test('countPendingOrFailedSyncBatches compte les lots en attente et en échec, jamais les synchronisés', () async {
    final userId = await insertUser();
    await insertBatch(userId, activity: 'En attente');
    final failedId = await insertBatch(userId, activity: 'En échec');
    final syncedId = await insertBatch(userId, activity: 'Synchronisé');

    final failed = (await mediaRepository.getBatchById(failedId))!;
    await mediaRepository.updateBatch(failed.copyWith(syncStatus: SyncStatus.failed));
    final synced = (await mediaRepository.getBatchById(syncedId))!;
    await mediaRepository.updateBatch(synced.copyWith(syncStatus: SyncStatus.synced));

    expect(await mediaRepository.countPendingOrFailedSyncBatches(), 2);
  });

  test('retire une photo d\'un lot sans toucher aux autres', () async {
    final userId = await insertUser();
    final batchId = await insertBatch(userId);
    await insertItem(batchId, 0);
    await insertItem(batchId, 1);
    await insertItem(batchId, 2);

    final items = await mediaRepository.getItemsByBatch(batchId);
    await mediaRepository.removeItem(items[1].id!);

    final remaining = await mediaRepository.getItemsByBatch(batchId);
    expect(remaining, hasLength(2));
    expect(remaining.map((i) => i.sortOrder), orderedEquals([0, 2]));
  });

  test('getItemById retrouve une photo par son id', () async {
    final userId = await insertUser();
    final batchId = await insertBatch(userId);
    await insertItem(batchId, 0);
    final inserted = (await mediaRepository.getItemsByBatch(batchId)).first;

    final found = await mediaRepository.getItemById(inserted.id!);

    expect(found, isNotNull);
    expect(found!.localPath, inserted.localPath);
  });

  test('supprime un lot non synchronisé et ses photos (cascade)', () async {
    final userId = await insertUser();
    final batchId = await insertBatch(userId);
    await insertItem(batchId, 0);
    await insertItem(batchId, 1);

    await mediaRepository.deleteBatch(batchId);

    expect(await mediaRepository.getBatchById(batchId), isNull);
    expect(await mediaRepository.getItemsByBatch(batchId), isEmpty);
  });

  test('modifie l\'activité, la description et le village d\'un lot existant', () async {
    final (_, _, _, villageId, _) = await insertHierarchy();
    final userId = await insertUser();
    final batchId = await insertBatch(userId, activity: 'Réunion');
    final batch = (await mediaRepository.getBatchById(batchId))!;

    await mediaRepository.updateBatch(
      batch.copyWith(
        activity: 'Plantation',
        description: 'Nouvelle description du lot.',
        villageId: villageId,
      ),
    );

    final updated = await mediaRepository.getBatchById(batchId);
    expect(updated!.activity, 'Plantation');
    expect(updated.description, 'Nouvelle description du lot.');
    expect(updated.villageId, villageId);
  });

  test('conserve l\'association mission / CLD / village d\'un lot', () async {
    final (secteurId, groupementId, cldId, villageId, missionId) = await insertHierarchy();
    final userId = await insertUser();
    final now = DateTime.now();
    final batchId = await mediaRepository.insertBatch(
      MediaBatch(
        localId: IdGenerator.generate(),
        userId: userId,
        missionId: missionId,
        secteurId: secteurId,
        groupementId: groupementId,
        cldId: cldId,
        villageId: villageId,
        activity: 'Sensibilisation',
        capturedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final batch = await mediaRepository.getBatchById(batchId);
    expect(batch!.missionId, missionId);
    expect(batch.cldId, cldId);
    expect(batch.villageId, villageId);

    final byMission = await mediaRepository.getBatchesByMission(missionId);
    expect(byMission.map((b) => b.id), contains(batchId));
  });
}
