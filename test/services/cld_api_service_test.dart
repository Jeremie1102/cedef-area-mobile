import 'package:cedef_area/services/cld_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';

void main() {
  test('getMyClds extrait la liste depuis l\'enveloppe paginée Laravel', () async {
    final client = FakeApiClient(
      responses: {
        'GET /me/clds': {
          'data': [
            {'id': 6, 'nom': 'CLD Wunsch', 'groupement': null, 'affectation': null},
            {'id': 8, 'nom': 'CLD Feil', 'groupement': null, 'affectation': null},
          ],
          'links': {'first': '...', 'last': '...', 'prev': null, 'next': null},
          'meta': {'current_page': 1, 'total': 2},
        },
      },
    );
    final service = CldApiService(client: client);

    final clds = await service.getMyClds();

    expect(clds, hasLength(2));
    expect(clds.first.nom, 'CLD Wunsch');
  });
}
