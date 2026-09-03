/// Statut de synchronisation d'une donnée locale avec le serveur Laravel.
///
/// * [pending] : créée/modifiée localement, doit encore être envoyée.
/// * [syncing] : envoi en cours (évite qu'un autre passage de synchronisation
///   ne retraite la même donnée pendant qu'elle est déjà en cours d'envoi).
/// * [synced] : confirmée par le serveur.
/// * [failed] : la dernière tentative a échoué ; sera retentée plus tard.
///
/// Convention unique utilisée par toutes les tables (`sync_status`) et par
/// `sync_queue.status` : voir `SyncQueueRepository`.
enum SyncStatus { pending, syncing, synced, failed }

extension SyncStatusX on SyncStatus {
  String get value => name;

  static SyncStatus fromValue(String? value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

/// Opération représentée par une entrée de `sync_queue`.
///
/// [create]/[update]/[delete] couvrent les entités "classiques" (photos,
/// lots de médias, positions GPS, profil). Les missions ont en plus des
/// événements de cycle de vie ([start]/[pause]/[resume]/[complete]) : chacun
/// doit être transmis à Laravel comme un événement distinct plutôt que comme
/// une simple mise à jour, pour permettre un futur historique côté serveur.
enum SyncOperation { create, update, delete, start, pause, resume, complete }

extension SyncOperationX on SyncOperation {
  String get value => name;

  static SyncOperation fromValue(String? value) {
    return SyncOperation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncOperation.create,
    );
  }
}

/// Fonction occupée par un utilisateur de terrain.
enum UserFonction { animateur, mrv, sauvegarde, sig }

extension UserFonctionX on UserFonction {
  String get value => name;

  static UserFonction fromValue(String? value) {
    return UserFonction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserFonction.animateur,
    );
  }
}

/// Statut d'une mission de terrain.
enum MissionStatus { pending, inProgress, paused, completed, cancelled }

extension MissionStatusX on MissionStatus {
  String get value {
    switch (this) {
      case MissionStatus.pending:
        return 'pending';
      case MissionStatus.inProgress:
        return 'in_progress';
      case MissionStatus.paused:
        return 'paused';
      case MissionStatus.completed:
        return 'completed';
      case MissionStatus.cancelled:
        return 'cancelled';
    }
  }

  static MissionStatus fromValue(String? value) {
    switch (value) {
      case 'in_progress':
        return MissionStatus.inProgress;
      case 'paused':
        return MissionStatus.paused;
      case 'completed':
        return MissionStatus.completed;
      case 'cancelled':
        return MissionStatus.cancelled;
      case 'pending':
      default:
        return MissionStatus.pending;
    }
  }
}

/// Statut de validation d'un lot de médias par le responsable des médias.
enum MediaValidationStatus { pending, validated, rejected }

extension MediaValidationStatusX on MediaValidationStatus {
  String get value => name;

  static MediaValidationStatus fromValue(String? value) {
    return MediaValidationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MediaValidationStatus.pending,
    );
  }
}

/// Catégories officielles d'observations et constats terrain.
enum ObservationCategory {
  infrastructure,
  accessibilite,
  environnement,
  gouvernance,
  autre,
}

extension ObservationCategoryX on ObservationCategory {
  /// Code officiel utilisé pour le stockage et l'API
  String get code {
    switch (this) {
      case ObservationCategory.infrastructure:
        return 'INFRASTRUCTURE';
      case ObservationCategory.accessibilite:
        return 'ACCESSIBILITÉ';
      case ObservationCategory.environnement:
        return 'ENVIRONNEMENT';
      case ObservationCategory.gouvernance:
        return 'GOUVERNANCE';
      case ObservationCategory.autre:
        return 'AUTRE';
    }
  }

  /// Libellé utilisateur français
  String get label {
    switch (this) {
      case ObservationCategory.infrastructure:
        return 'Infrastructure';
      case ObservationCategory.accessibilite:
        return 'Accessibilité';
      case ObservationCategory.environnement:
        return 'Environnement';
      case ObservationCategory.gouvernance:
        return 'Gouvernance';
      case ObservationCategory.autre:
        return 'Autre';
    }
  }

  static ObservationCategory fromCode(String? code) {
    if (code == null) return ObservationCategory.autre;
    final normalized = code.trim().toUpperCase();
    switch (normalized) {
      case 'INFRASTRUCTURE':
        return ObservationCategory.infrastructure;
      case 'ACCESSIBILITÉ':
      case 'ACCESSIBILITE':
        return ObservationCategory.accessibilite;
      case 'ENVIRONNEMENT':
        return ObservationCategory.environnement;
      case 'GOUVERNANCE':
        return ObservationCategory.gouvernance;
      case 'AUTRE':
      default:
        return ObservationCategory.autre;
    }
  }
}

/// Niveaux de gravité d'un constat terrain.
enum ObservationSeverity {
  info,
  attention,
  critique,
}

extension ObservationSeverityX on ObservationSeverity {
  /// Code officiel utilisé pour le stockage et l'API
  String get code {
    switch (this) {
      case ObservationSeverity.info:
        return 'INFO';
      case ObservationSeverity.attention:
        return 'ATTENTION';
      case ObservationSeverity.critique:
        return 'CRITIQUE';
    }
  }

  /// Libellé utilisateur français
  String get label {
    switch (this) {
      case ObservationSeverity.info:
        return 'Information';
      case ObservationSeverity.attention:
        return 'Attention';
      case ObservationSeverity.critique:
        return 'Critique';
    }
  }

  static ObservationSeverity fromCode(String? code) {
    if (code == null) return ObservationSeverity.info;
    final normalized = code.trim().toUpperCase();
    switch (normalized) {
      case 'CRITIQUE':
        return ObservationSeverity.critique;
      case 'ATTENTION':
      case 'WARNING':
        return ObservationSeverity.attention;
      case 'INFO':
      case 'INFORMATION':
      default:
        return ObservationSeverity.info;
    }
  }
}

/// Liste des activités pouvant être associées à un média.
///
/// Cette liste est volontairement une simple liste de chaînes (et non un enum)
/// afin de pouvoir être facilement complétée plus tard sans casser les
/// données déjà enregistrées localement.
class ActivityCategories {
  ActivityCategories._();

  static const List<String> all = [
    'Réunion',
    'Sensibilisation',
    'Création de CLD',
    'Signature de consentement',
    'Identification de terrain',
    'Installation de pépinière',
    'Empotage',
    'Plantation',
    'Distribution de matériel',
    'Suivi des travaux',
    'Autre',
  ];
}
