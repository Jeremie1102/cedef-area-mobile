import 'api_sector.dart';

/// Représente un `GroupementResource` renvoyé par l'API Laravel.
class ApiGroupement {
  final int id;
  final String nom;
  final ApiSector? sector;

  const ApiGroupement({required this.id, required this.nom, this.sector});

  factory ApiGroupement.fromJson(Map<String, dynamic> json) {
    final sectorJson = json['sector'] as Map<String, dynamic>?;
    return ApiGroupement(
      id: json['id'] as int,
      nom: json['nom'] as String,
      sector: sectorJson != null ? ApiSector.fromJson(sectorJson) : null,
    );
  }
}
