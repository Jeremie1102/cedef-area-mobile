import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/models/gps_position.dart';
import 'package:cedef_area/services/gps_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';

/// Ces tests exercent [GpsApiService] : construction du lot JSON envoyé à
/// `POST /gps-positions` (résolution des `mission_id` serveur, champs
/// optionnels omis si absents, `captured_at` en UTC) et propagation des
/// erreurs de [ApiClient] sans transformation. Aucun appel réseau réel : voir
/// [FakeApiClient].
void main() {
  GpsPosition buildPosition({
    required String localId,
    int missionId = 1,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) {
    final recordedAt = DateTime(2026, 8, 29, 10, 42, 15);
    return GpsPosition(
      localId: localId,
      missionId: missionId,
      userId: 1,
      latitude: -4.123456,
      longitude: 15.123456,
      altitude: altitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      recordedAt: recordedAt,
      createdAt: recordedAt,
    );
  }

  Map<String, dynamic> emptyResponse() => {
    'message': 'ok',
    'accepted': [],
    'already_synced': [],
    'rejected': [],
  };

  test('envoie le mission_id serveur résolu, pas l\'id local', () async {
    final position = buildPosition(localId: 'GPS-1', missionId: 7, accuracy: 12.4);
    final fakeClient = FakeApiClient(responses: {'POST /gps-positions': emptyResponse()});
    final service = GpsApiService(client: fakeClient);

    await service.syncPositions([position], {7: 100});

    final sentPositions = fakeClient.lastPostData!['positions'] as List;
    expect(sentPositions, hasLength(1));
    expect(sentPositions.first['local_id'], 'GPS-1');
    expect(sentPositions.first['mission_id'], 100);
    expect(sentPositions.first['accuracy'], 12.4);
  });

  test('omet les champs optionnels absents (altitude, accuracy, speed, heading)', () async {
    final position = buildPosition(localId: 'GPS-2', missionId: 7);
    final fakeClient = FakeApiClient(responses: {'POST /gps-positions': emptyResponse()});
    final service = GpsApiService(client: fakeClient);

    await service.syncPositions([position], {7: 100});

    final sent = (fakeClient.lastPostData!['positions'] as List).first as Map;
    expect(sent.containsKey('altitude'), isFalse);
    expect(sent.containsKey('accuracy'), isFalse);
    expect(sent.containsKey('speed'), isFalse);
    expect(sent.containsKey('heading'), isFalse);
  });

  test('convertit captured_at en UTC sans changer l\'instant capturé', () async {
    final position = buildPosition(localId: 'GPS-3');
    final fakeClient = FakeApiClient(responses: {'POST /gps-positions': emptyResponse()});
    final service = GpsApiService(client: fakeClient);

    await service.syncPositions([position], {1: 1});

    final sent = (fakeClient.lastPostData!['positions'] as List).first as Map;
    final sentCapturedAt = DateTime.parse(sent['captured_at'] as String);
    expect(sentCapturedAt.isUtc, isTrue);
    expect(sentCapturedAt.toUtc(), position.recordedAt.toUtc());
  });

  test('un lot peut couvrir plusieurs missions, chacune avec son propre server_id', () async {
    final positionA = buildPosition(localId: 'GPS-A', missionId: 1);
    final positionB = buildPosition(localId: 'GPS-B', missionId: 2);
    final fakeClient = FakeApiClient(responses: {'POST /gps-positions': emptyResponse()});
    final service = GpsApiService(client: fakeClient);

    await service.syncPositions([positionA, positionB], {1: 100, 2: 200});

    final sent = fakeClient.lastPostData!['positions'] as List;
    expect(sent[0]['mission_id'], 100);
    expect(sent[1]['mission_id'], 200);
  });

  test('parse accepted / already_synced / rejected', () async {
    final position = buildPosition(localId: 'GPS-3');
    final fakeClient = FakeApiClient(
      responses: {
        'POST /gps-positions': {
          'message': 'ok',
          'accepted': [
            {'local_id': 'GPS-3', 'id': 10, 'uuid': 'u-3'},
          ],
          'already_synced': [
            {'local_id': 'GPS-4', 'id': 11, 'uuid': 'u-4'},
          ],
          'rejected': [
            {'local_id': 'GPS-5', 'reason': 'Mission non autorisée pour cet agent.'},
          ],
        },
      },
    );
    final service = GpsApiService(client: fakeClient);

    final result = await service.syncPositions([position], {1: 1});

    expect(result.acceptedServerIdsByLocalId, {'GPS-3': 10});
    expect(result.alreadySyncedServerIdsByLocalId, {'GPS-4': 11});
    expect(result.rejectedReasonsByLocalId, {'GPS-5': 'Mission non autorisée pour cet agent.'});
  });

  test('propage une erreur réseau sans la transformer', () async {
    final position = buildPosition(localId: 'GPS-6');
    final fakeClient = FakeApiClient(errors: {'POST /gps-positions': const NetworkException()});
    final service = GpsApiService(client: fakeClient);

    await expectLater(
      service.syncPositions([position], {1: 1}),
      throwsA(isA<NetworkException>()),
    );
  });

  test('propage un 401 sans la transformer', () async {
    final position = buildPosition(localId: 'GPS-7');
    final fakeClient = FakeApiClient(errors: {'POST /gps-positions': const UnauthorizedException()});
    final service = GpsApiService(client: fakeClient);

    await expectLater(
      service.syncPositions([position], {1: 1}),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
