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
