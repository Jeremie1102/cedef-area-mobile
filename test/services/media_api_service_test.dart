import 'dart:io';

import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/models/media_batch.dart';
import 'package:cedef_area/models/media_item.dart';
import 'package:cedef_area/services/media_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_api_client.dart';

/// Ces tests exercent [MediaApiService] : construction de la requête
/// multipart (champs + fichiers) envoyée à `POST /media-batches`, et
/// propagation des erreurs de [ApiClient] sans transformation. Aucun appel
/// réseau réel : voir [FakeApiClient].
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cedef_media_api_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> createFakePhoto(String name) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsBytes([1, 2, 3, 4]);
    return file.path;
  }

  MediaBatch buildBatch({String? activity}) {
    final now = DateTime.now();
    return MediaBatch(
      localId: 'BATCH-1',
      userId: 1,
      missionId: 10,
      activity: activity,
      description: 'Séance de sensibilisation.',
      capturedAt: DateTime(2026, 8, 29),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<MediaItem> buildItem(String localId, String fileName) async {
    final now = DateTime.now();
    return MediaItem(
      localId: localId,
      batchId: 1,
      localPath: await createFakePhoto(fileName),
      fileName: fileName,
      fileSize: 4,
      mimeType: 'image/jpeg',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('envoie les métadonnées du lot et un fichier par photo, dans l\'ordre', () async {
    final itemA = await buildItem('item-a', 'a.jpg');
    final itemB = await buildItem('item-b', 'b.jpg');
    final fakeClient = FakeApiClient(
      responses: {
        'POST /media-batches': {
          'message': 'Lot synchronisé avec succès.',
          'batch': {
            'id': 42,
            'local_id': 'BATCH-1',
            'items': [
              {'local_id': 'item-a', 'id': 101},
              {'local_id': 'item-b', 'id': 102},
            ],
          },
        },
      },
    );
    final service = MediaApiService(client: fakeClient);

    final result = await service.uploadBatch(
      batch: buildBatch(activity: 'Sensibilisation'),
      items: [itemA, itemB],
      missionServerId: 10,
      cldServerId: 5,
      villageServerId: 16,
    );

    expect(result.id, 42);
    expect(result.localId, 'BATCH-1');
    expect(result.itemServerIdsByLocalId, {'item-a': 101, 'item-b': 102});

    final fields = fakeClient.lastMultipartFields!;
    expect(fields['local_id'], 'BATCH-1');
    expect(fields['mission_id'], '10');
    expect(fields['cld_id'], '5');
    expect(fields['village_id'], '16');
    expect(fields['activite'], 'Sensibilisation');
    expect(fields['description'], 'Séance de sensibilisation.');
    expect(fields['date_activite'], '2026-08-29');
    expect(fields['photos_local_ids'], ['item-a', 'item-b']);

    final files = fakeClient.lastMultipartFiles!;
    expect(files, hasLength(2));
    expect(files.every((f) => f.field == 'photos'), isTrue);
    expect(files.map((f) => f.filename), ['a.jpg', 'b.jpg']);
  });

  test('omet les champs optionnels absents (cld/village/gps)', () async {
    final item = await buildItem('item-a', 'a.jpg');
    final fakeClient = FakeApiClient(
      responses: {
        'POST /media-batches': {
          'message': 'ok',
          'batch': {'id': 1, 'local_id': 'BATCH-1', 'items': []},
        },
      },
    );
    final service = MediaApiService(client: fakeClient);

    await service.uploadBatch(batch: buildBatch(), items: [item], missionServerId: 10);

    final fields = fakeClient.lastMultipartFields!;
    expect(fields.containsKey('cld_id'), isFalse);
    expect(fields.containsKey('village_id'), isFalse);
    expect(fields.containsKey('latitude'), isFalse);
  });

  test('propage une erreur API sans la transformer (ex : 422)', () async {
    final item = await buildItem('item-a', 'a.jpg');
    final fakeClient = FakeApiClient(
      errors: {
        'POST /media-batches': const ApiValidationException('Champs invalides.', {
          'description': ['La description est obligatoire.'],
        }),
      },
    );
    final service = MediaApiService(client: fakeClient);

    await expectLater(
      service.uploadBatch(batch: buildBatch(), items: [item], missionServerId: 10),
      throwsA(isA<ApiValidationException>()),
    );
  });

  test('propage une erreur réseau', () async {
    final item = await buildItem('item-a', 'a.jpg');
    final fakeClient = FakeApiClient(
      errors: {'POST /media-batches': const NetworkException()},
    );
    final service = MediaApiService(client: fakeClient);

    await expectLater(
      service.uploadBatch(batch: buildBatch(), items: [item], missionServerId: 10),
      throwsA(isA<NetworkException>()),
    );
  });
}
