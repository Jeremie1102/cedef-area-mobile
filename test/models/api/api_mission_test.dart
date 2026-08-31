import 'package:cedef_area/models/api/api_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiMission.fromJson parses a MissionResource payload with territoire et affectation', () {
    final json = {
      'id': 2,
      'titre': 'Sensibilisation villages',
      'description': 'Description de la mission.',
      'type_activite': 'enquete',
      'statut': 'planned',
      'date_debut_prevue': '2026-08-28',
      'date_fin_prevue': '2026-10-09',
      'observations': null,
      'sector': {'id': 2, 'nom': 'Secteur Lake Nikki'},
      'groupement': null,
      'clds': [
        {'id': 3, 'nom': 'CLD Schamberger'},
        {'id': 6, 'nom': 'CLD Wunsch'},
      ],
      'villages': [
        {'id': 1, 'nom': 'Village Kreiger', 'cld_id': 1},
      ],
      'affectation': {'role': 'agent_terrain', 'statut': 'active', 'date_affectation': '2026-08-27'},
    };

    final mission = ApiMission.fromJson(json);

    expect(mission.id, 2);
    expect(mission.titre, 'Sensibilisation villages');
    expect(mission.statut, 'planned');
    expect(mission.sector?.nom, 'Secteur Lake Nikki');
    expect(mission.groupement, isNull);
    expect(mission.clds, hasLength(2));
    expect(mission.villages, hasLength(1));
    expect(mission.affectation?.role, 'agent_terrain');
  });
}
