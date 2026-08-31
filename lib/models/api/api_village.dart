/// Représente un `VillageResource` renvoyé par l'API Laravel.
class ApiVillage {
  final int id;
  final String nom;
  final int cldId;

  const ApiVillage({required this.id, required this.nom, required this.cldId});

  factory ApiVillage.fromJson(Map<String, dynamic> json) {
    return ApiVillage(
      id: json['id'] as int,
      nom: json['nom'] as String,
      cldId: json['cld_id'] as int,
    );
  }
}
