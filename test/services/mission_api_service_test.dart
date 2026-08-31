import 'package:cedef_area/services/mission_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';

void main() {
  test('getMyMissions extrait la liste depuis l\'enveloppe paginée', () async {
    final client = FakeApiClient(
      responses: {
        'GET /me/missions': {
          'data': [
            {
              'id': 2,
              'titre': 'Mission A',
              'description': null,
              'type_activite': null,
              'statut': 'planned',
              'date_debut_prevue': '2026-08-28',
              'date_fin_prevue': null,
              'observations': null,
              'sector': null,
              'groupement': null,
              'clds': [],
              'villages': [],
              'affectation': null,
            },
          ],
          'links': {},
          'meta': {},
        },
      },
    );
    final service = MissionApiService(client: client);

    final missions = await service.getMyMissions();

    expect(missions, hasLength(1));
    expect(missions.first.titre, 'Mission A');
  });
}
