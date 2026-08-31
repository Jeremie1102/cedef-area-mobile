import 'dart:io';

import 'package:cedef_area/config/app_config.dart';
import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/repositories/media_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/services/gps_service.dart';
import 'package:cedef_area/services/media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_path_provider_platform.dart';

/// Ces tests exercent [MediaService] : création d'un lot (copie des photos
/// dans un dossier dédié, validations), nettoyage en cas d'échec, suppression,
/// et interdiction de modifier/supprimer un lot déjà synchronisé. Aucune
/// vraie photo personnelle n'est utilisée (voir section 39 du cahier des
/// charges) : de petits fichiers factices tiennent lieu de photos, et le
/// « dossier documents » de l'application est un dossier temporaire du
/// système (voir `FakePathProviderPlatform`).
///
/// Le GPS n'est volontairement jamais autorisé ici (`GpsService`
/// injecté avec `permissionChecker: () async => false`) : la position d'un
/// lot est hors périmètre de ces tests (voir `GpsService`/`gps_service_test.dart`),
/// et cela évite tout appel réel au plugin `geolocator`.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late MediaRepository mediaRepository;
  late UserRepository userRepository;
  late MediaService mediaService;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_media_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    tempDir = await Directory.systemTemp.createTemp('cedef_media_service_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);

    mediaRepository = MediaRepository();
    userRepository = UserRepository();
    mediaService = MediaService(
      mediaRepository: mediaRepository,
      gpsService: GpsService(permissionChecker: () async => false),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
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

  Future<XFile> createFakePhoto(String name, {List<int>? bytes}) async {
    final sourceDir = await Directory.systemTemp.createTemp('cedef_media_source_');
    final file = File(p.join(sourceDir.path, name));
    await file.writeAsBytes(bytes ?? List.generate(16, (i) => i));
    return XFile(file.path);
  }

  Directory batchesDir() => Directory(p.join(tempDir.path, AppConfig.mediaFolderName, 'batches'));

  test('crée un lot avec plusieurs photos copiées dans un dossier dédié', () async {
    final userId = await insertUser();
    final photos = [await createFakePhoto('a.jpg'), await createFakePhoto('b.jpg')];

    final batch = await mediaService.createBatch(
      userId: userId,
      photos: photos,
      description: 'Séance de sensibilisation du CLD.',
      activity: 'Sensibilisation',
    );

    final items = await mediaRepository.getItemsByBatch(batch.id!);
    expect(items, hasLength(2));
    expect(items.map((i) => i.sortOrder), orderedEquals([0, 1]));
    for (final item in items) {
      expect(await File(item.localPath).exists(), isTrue);
    }
    expect(batch.description, 'Séance de sensibilisation du CLD.');
    expect(batch.syncStatus, SyncStatus.pending);
  });

  test('chaque lot reçoit son propre dossier (jamais un dossier partagé)', () async {
    final userId = await insertUser();
    final batch1 = await mediaService.createBatch(
      userId: userId,
      photos: [await createFakePhoto('x.jpg')],
      description: 'Premier lot.',
    );
    final batch2 = await mediaService.createBatch(
      userId: userId,
      photos: [await createFakePhoto('y.jpg')],
      description: 'Second lot.',
    );

    final item1 = (await mediaRepository.getItemsByBatch(batch1.id!)).single;
    final item2 = (await mediaRepository.getItemsByBatch(batch2.id!)).single;

    expect(p.dirname(item1.localPath), isNot(equals(p.dirname(item2.localPath))));
    expect(p.basename(p.dirname(item1.localPath)), batch1.localId);
    expect(p.basename(p.dirname(item2.localPath)), batch2.localId);
  });

  test('un échec de copie ne laisse aucun lot incomplet ni fichier orphelin', () async {
    final userId = await insertUser();
    final goodPhoto = await createFakePhoto('good.jpg');
    // Source inexistante : la copie échouera au milieu du traitement du lot.
    final missingPhoto = XFile(p.join(tempDir.path, 'ne_existe_pas.jpg'));

    await expectLater(
      mediaService.createBatch(
        userId: userId,
        photos: [goodPhoto, missingPhoto],
        description: 'Lot voué à échouer.',
      ),
      throwsA(isA<MediaException>()),
    );

    expect(await mediaRepository.getBatchSummariesByUser(userId), isEmpty);
    if (await batchesDir().exists()) {
      expect(await batchesDir().list().toList(), isEmpty);
    }
  });

  test('supprime un lot non synchronisé : lignes SQLite, fichiers et dossier disparaissent', () async {
    final userId = await insertUser();
    final batch = await mediaService.createBatch(
      userId: userId,
      photos: [await createFakePhoto('to_remove.jpg')],
      description: 'Lot à supprimer.',
    );
    final item = (await mediaRepository.getItemsByBatch(batch.id!)).single;
    final batchDir = Directory(p.dirname(item.localPath));
    expect(await batchDir.exists(), isTrue);

    await mediaService.deleteBatch(batch);

    expect(await mediaRepository.getBatchById(batch.id!), isNull);
    expect(await mediaRepository.getItemsByBatch(batch.id!), isEmpty);
    expect(await File(item.localPath).exists(), isFalse);
    expect(await batchDir.exists(), isFalse);
  });

  test('refuse de modifier ou supprimer un lot déjà synchronisé', () async {
    final userId = await insertUser();
    final batch = await mediaService.createBatch(
      userId: userId,
      photos: [await createFakePhoto('synced.jpg')],
      description: 'Lot déjà envoyé.',
    );
    final synced = batch.copyWith(syncStatus: SyncStatus.synced);
    await mediaRepository.updateBatch(synced);

    await expectLater(
      mediaService.updateBatch(synced.copyWith(description: 'Nouvelle description.')),
      throwsA(isA<MediaException>()),
    );
    await expectLater(mediaService.deleteBatch(synced), throwsA(isA<MediaException>()));
  });

  test('la description est obligatoire à la création comme à la modification', () async {
    final userId = await insertUser();

    await expectLater(
      mediaService.createBatch(userId: userId, photos: [await createFakePhoto('p.jpg')], description: '   '),
      throwsA(isA<MediaException>()),
    );
    expect(await mediaRepository.getBatchSummariesByUser(userId), isEmpty);

    final batch = await mediaService.createBatch(
      userId: userId,
      photos: [await createFakePhoto('p2.jpg')],
      description: 'Description valide.',
    );
    await expectLater(
      mediaService.updateBatch(batch.copyWith(description: '')),
      throwsA(isA<MediaException>()),
    );
  });

  test('refuse une description dépassant la longueur maximale', () async {
    final userId = await insertUser();
    final tooLong = 'x' * (AppConfig.mediaBatchDescriptionMaxLength + 1);

    await expectLater(
      mediaService.createBatch(userId: userId, photos: [await createFakePhoto('p.jpg')], description: tooLong),
      throwsA(isA<MediaException>()),
    );
  });

  test('refuse un lot dépassant le nombre maximal de photos', () async {
    final userId = await insertUser();
    // La validation du nombre de photos précède tout accès fichier : pas
    // besoin de fichiers réellement existants pour ce test.
    final tooMany = List.generate(
      AppConfig.mediaBatchMaxPhotos + 1,
      (i) => XFile('photo_$i.jpg'),
    );

    await expectLater(
      mediaService.createBatch(userId: userId, photos: tooMany, description: 'Trop de photos.'),
      throwsA(isA<MediaException>()),
    );
  });

  test('refuse de créer un lot sans aucune photo', () async {
    final userId = await insertUser();

    await expectLater(
      mediaService.createBatch(userId: userId, photos: [], description: 'Aucune photo.'),
      throwsA(isA<MediaException>()),
    );
  });
}
