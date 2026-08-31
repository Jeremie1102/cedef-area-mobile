/// Métadonnées de l'affectation d'un agent à une mission (table pivot
/// `mission_user`) : rôle de l'agent et statut de son affectation.
class ApiMissionAffectation {
  final String? role;
  final String? statut;
  final String? dateAffectation;

  const ApiMissionAffectation({this.role, this.statut, this.dateAffectation});

  factory ApiMissionAffectation.fromJson(Map<String, dynamic> json) {
    return ApiMissionAffectation(
      role: json['role'] as String?,
      statut: json['statut'] as String?,
      dateAffectation: json['date_affectation'] as String?,
    );
  }
}
