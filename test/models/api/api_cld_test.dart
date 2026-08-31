import 'package:cedef_area/models/api/api_cld.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiCld.fromJson', () {
    test('parses a CldResource payload with groupement/sector/affectation', () {
      final json = {
        'id': 6,
        'nom': 'CLD Wunsch',
        'groupement': {
          'id': 3,
          'nom': 'Groupement stad',
          'sector': {'id': 2, 'nom': 'Secteur Lake Nikki'},
        },
        'affectation': {'date_debut': '2026-07-27', 'date_fin': null, 'statut': 'active'},
      };

      final cld = ApiCld.fromJson(json);

      expect(cld.id, 6);
      expect(cld.nom, 'CLD Wunsch');
      expect(cld.groupement?.nom, 'Groupement stad');
      expect(cld.groupement?.sector?.nom, 'Secteur Lake Nikki');
      expect(cld.affectation?.statut, 'active');
      expect(cld.affectation?.dateFin, isNull);
    });

    test('handles missing groupement/affectation', () {
      final cld = ApiCld.fromJson({'id': 1, 'nom': 'CLD X'});

      expect(cld.groupement, isNull);
      expect(cld.affectation, isNull);
    });
  });
}
