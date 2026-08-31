import 'api_cld_affectation.dart';
import 'api_groupement.dart';

/// Représente un `CldResource` renvoyé par l'API Laravel.
class ApiCld {
  final int id;
  final String nom;
  final ApiGroupement? groupement;
  final ApiCldAffectation? affectation;

  const ApiCld({required this.id, required this.nom, this.groupement, this.affectation});

  factory ApiCld.fromJson(Map<String, dynamic> json) {
    final groupementJson = json['groupement'] as Map<String, dynamic>?;
    final affectationJson = json['affectation'] as Map<String, dynamic>?;
    return ApiCld(
      id: json['id'] as int,
      nom: json['nom'] as String,
      groupement: groupementJson != null ? ApiGroupement.fromJson(groupementJson) : null,
      affectation: affectationJson != null ? ApiCldAffectation.fromJson(affectationJson) : null,
    );
  }
}
