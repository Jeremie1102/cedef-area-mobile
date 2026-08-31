/// Métadonnées de l'affectation d'un agent à un CLD (table pivot `cld_user`).
class ApiCldAffectation {
  final String? dateDebut;
  final String? dateFin;
  final String? statut;

  const ApiCldAffectation({this.dateDebut, this.dateFin, this.statut});

  factory ApiCldAffectation.fromJson(Map<String, dynamic> json) {
    return ApiCldAffectation(
      dateDebut: json['date_debut'] as String?,
      dateFin: json['date_fin'] as String?,
      statut: json['statut'] as String?,
    );
  }
}
