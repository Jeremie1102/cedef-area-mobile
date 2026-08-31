import '../core/constants/app_constants.dart';

class User {
  final int? id;
  final String localId;
  final int? serverId;
  final String nom;
  final String postNom;
  final String prenom;
  final UserFonction fonction;
  final String passwordHash;
  final String? photoProfil;
  final String? telephone;
  final bool isActive;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    this.id,
    required this.localId,
    this.serverId,
    required this.nom,
    required this.postNom,
    required this.prenom,
    required this.fonction,
    required this.passwordHash,
    this.photoProfil,
    this.telephone,
    this.isActive = true,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$nom $postNom $prenom'.trim();

  User copyWith({
    int? id,
    String? localId,
    int? serverId,
    String? nom,
    String? postNom,
    String? prenom,
    UserFonction? fonction,
    String? passwordHash,
    String? photoProfil,
    String? telephone,
    bool? isActive,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      nom: nom ?? this.nom,
      postNom: postNom ?? this.postNom,
      prenom: prenom ?? this.prenom,
      fonction: fonction ?? this.fonction,
      passwordHash: passwordHash ?? this.passwordHash,
      photoProfil: photoProfil ?? this.photoProfil,
      telephone: telephone ?? this.telephone,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'server_id': serverId,
      'nom': nom,
      'post_nom': postNom,
      'prenom': prenom,
      'fonction': fonction.value,
      'password_hash': passwordHash,
      'photo_profil': photoProfil,
      'telephone': telephone,
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      nom: map['nom'] as String,
      postNom: map['post_nom'] as String? ?? '',
      prenom: map['prenom'] as String? ?? '',
      fonction: UserFonctionX.fromValue(map['fonction'] as String?),
      passwordHash: map['password_hash'] as String,
      photoProfil: map['photo_profil'] as String?,
      telephone: map['telephone'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
