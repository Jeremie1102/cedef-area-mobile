import 'api_cld.dart';
import 'api_groupement.dart';
import 'api_mission_affectation.dart';
import 'api_sector.dart';
import 'api_village.dart';

/// Représente un `MissionResource` renvoyé par l'API Laravel.
///
/// Pas de `uuid` : contrairement aux positions GPS/médias (alimentés depuis
/// le mobile), les missions sont créées côté backend par l'Assistant
/// Technique — voir la conception de la base de données métier.
class ApiMission {
  final int id;
  final String titre;
  final String? description;
  final String? typeActivite;
  final String? statut;
  final String? dateDebutPrevue;
  final String? dateFinPrevue;
  final String? observations;
  final ApiSector? sector;
  final ApiGroupement? groupement;
  final List<ApiCld> clds;
  final List<ApiVillage> villages;
  final ApiMissionAffectation? affectation;

  const ApiMission({
    required this.id,
    required this.titre,
    this.description,
    this.typeActivite,
    this.statut,
    this.dateDebutPrevue,
    this.dateFinPrevue,
    this.observations,
    this.sector,
    this.groupement,
    this.clds = const [],
    this.villages = const [],
    this.affectation,
  });

  factory ApiMission.fromJson(Map<String, dynamic> json) {
    final sectorJson = json['sector'] as Map<String, dynamic>?;
    final groupementJson = json['groupement'] as Map<String, dynamic>?;
    final affectationJson = json['affectation'] as Map<String, dynamic>?;
    final cldsJson = json['clds'] as List<dynamic>? ?? const [];
    final villagesJson = json['villages'] as List<dynamic>? ?? const [];

    return ApiMission(
      id: json['id'] as int,
      titre: json['titre'] as String,
      description: json['description'] as String?,
      typeActivite: json['type_activite'] as String?,
      statut: json['statut'] as String?,
      dateDebutPrevue: json['date_debut_prevue'] as String?,
      dateFinPrevue: json['date_fin_prevue'] as String?,
      observations: json['observations'] as String?,
      sector: sectorJson != null ? ApiSector.fromJson(sectorJson) : null,
      groupement: groupementJson != null ? ApiGroupement.fromJson(groupementJson) : null,
      clds: cldsJson.map((e) => ApiCld.fromJson(e as Map<String, dynamic>)).toList(),
      villages: villagesJson.map((e) => ApiVillage.fromJson(e as Map<String, dynamic>)).toList(),
      affectation: affectationJson != null ? ApiMissionAffectation.fromJson(affectationJson) : null,
    );
  }
}
