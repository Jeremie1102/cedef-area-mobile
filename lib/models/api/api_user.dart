/// Représente un `UserResource` renvoyé par l'API Laravel.
///
/// Modèle distinct du [User] local (SQLite) : ce dernier porte un
/// `passwordHash` local et n'a pas de champ `email`, ce qui reflète deux
/// besoins différents (compte créé hors-ligne vs profil authentifié
/// serveur). Les réconcilier appartient à la synchronisation, hors périmètre
/// de cette étape.
class ApiUser {
  final int id;
  final String nom;
  final String? postnom;
  final String? prenom;
  final String email;
  final String? fonction;
  final String? photoProfil;
  final bool actif;

  const ApiUser({
    required this.id,
    required this.nom,
    this.postnom,
    this.prenom,
    required this.email,
    this.fonction,
    this.photoProfil,
    required this.actif,
  });

  String get fullName => [nom, postnom, prenom].where((p) => p != null && p.isNotEmpty).join(' ');

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      id: json['id'] as int,
      nom: json['nom'] as String,
      postnom: json['postnom'] as String?,
      prenom: json['prenom'] as String?,
      email: json['email'] as String,
      fonction: json['fonction'] as String?,
      photoProfil: json['photo_profil'] as String?,
      actif: json['actif'] as bool,
    );
  }
}
