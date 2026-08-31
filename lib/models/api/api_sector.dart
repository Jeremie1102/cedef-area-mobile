/// Représente un `SectorResource` renvoyé par l'API Laravel.
class ApiSector {
  final int id;
  final String nom;

  const ApiSector({required this.id, required this.nom});

  factory ApiSector.fromJson(Map<String, dynamic> json) {
    return ApiSector(id: json['id'] as int, nom: json['nom'] as String);
  }
}
