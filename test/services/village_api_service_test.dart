import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/services/village_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';

void main() {
  test('getVillagesForCld extrait la liste depuis l\'enveloppe paginée', () async {
    final client = FakeApiClient(
      responses: {
        'GET /me/clds/6/villages': {
          'data': [
            {'id': 16, 'nom': 'Village Gibson', 'cld_id': 6},
          ],
          'links': {},
          'meta': {},
        },
      },
    );
    final service = VillageApiService(client: client);

    final villages = await service.getVillagesForCld(6);

    expect(villages, hasLength(1));
    expect(villages.first.nom, 'Village Gibson');
  });

  test('un CLD non autorisé propage ForbiddenException (403)', () async {
    final client = FakeApiClient(errors: {'GET /me/clds/1/villages': const ForbiddenException()});
    final service = VillageApiService(client: client);

    expect(() => service.getVillagesForCld(1), throwsA(isA<ForbiddenException>()));
  });
}
