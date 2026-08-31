import 'package:cedef_area/models/api/api_village.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiVillage.fromJson parses a VillageResource payload', () {
    final village = ApiVillage.fromJson({'id': 16, 'nom': 'Village Gibson', 'cld_id': 6});

    expect(village.id, 16);
    expect(village.nom, 'Village Gibson');
    expect(village.cldId, 6);
  });
}
