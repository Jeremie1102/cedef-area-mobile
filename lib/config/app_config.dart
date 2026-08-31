/// Configuration globale de l'application CEDEF AREA.
class AppConfig {
  AppConfig._();

  static const String appName = 'CEDEF AREA';

  // Base de données locale
  static const String databaseName = 'cedef_area.db';
  static const int databaseVersion = 7;

  // Dossiers de stockage local
  static const String mediaFolderName = 'cedef_media';
  static const String profilePhotoFolderName = 'cedef_profile_photos';

  // API distante (Laravel).
  //
  // Une seule valeur à changer pour cibler un autre serveur : soit en
  // modifiant `_defaultApiHost` ci-dessous, soit sans toucher au code via
  // `flutter run --dart-define=API_BASE_URL=http://host:port/api`.
  //
  // 127.0.0.1 ne fonctionne QUE pour Windows/macOS/Linux/Web (Flutter tourne
  // alors sur la même machine que Laravel). Pour un téléphone physique ou un
  // émulateur, 127.0.0.1 désignerait l'appareil lui-même, jamais le PC :
  //   - téléphone physique : IP locale du PC sur le Wi-Fi (ex. 192.168.1.200)
  //   - émulateur Android (AVD) : 10.0.2.2 (alias spécial vers l'hôte)
  // Démarrer Laravel avec `php artisan serve --host=0.0.0.0 --port=8000`
  // pour qu'il accepte les connexions venant du réseau local.
  static const String _defaultApiHost = '192.168.1.200:8000';
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://$_defaultApiHost/api/$apiVersion',
  );
  static const Duration apiConnectTimeout = Duration(seconds: 15);
  static const Duration apiReceiveTimeout = Duration(seconds: 20);
  // Conservé pour compatibilité avec le code existant qui référence encore
  // une durée unique.
  static const Duration apiTimeout = apiReceiveTimeout;

  // Synchronisation (voir SyncService/SyncQueueRepository)
  //
  // Nombre maximal de tentatives avant qu'une entrée de la file d'attente ne
  // soit considérée en échec durable (elle reste toutefois `failed`, jamais
  // supprimée : voir section 13 du cahier des charges).
  static const int syncMaxAttempts = 5;
  // Durée de conservation des entrées déjà synchronisées dans `sync_queue`
  // (utilisées comme journal de synchronisation, voir SyncStatusScreen) avant
  // d'être purgées par `SyncQueueRepository.clearSyncedItems`.
  static const Duration syncHistoryRetention = Duration(days: 7);
  // Délai de la vérification d'accès réel à Internet (au-delà d'une simple
  // interface réseau active) — voir ConnectivityService.
  static const Duration connectivityCheckTimeout = Duration(seconds: 4);

  // GPS (voir GpsService) : le suivi n'a lieu que pendant une mission en
  // cours, à intervalle régulier plutôt qu'en continu, pour limiter la
  // consommation de batterie et le volume de données stockées.
  //
  // Intervalle entre deux relevés (recommandation : 30 à 60 secondes).
  static const int gpsIntervalSeconds = 45;
  // Distance minimale (mètres) depuis la dernière position enregistrée pour
  // qu'un nouveau relevé soit conservé : évite d'accumuler des positions
  // quasi identiques lorsque l'agent reste immobile.
  static const double gpsDistanceFilterMeters = 20;
  // Précision (mètres) au-delà de laquelle un relevé est jugé trop imprécis
  // pour être conservé (le suivi continue, ce relevé est simplement ignoré).
  static const double gpsAccuracyThresholdMeters = 50;

  // Synchronisation GPS (voir GpsSyncService) : nombre maximal de positions
  // envoyées par requête. Un suivi actif (relevé toutes les
  // `gpsIntervalSeconds`) peut accumuler plusieurs centaines de positions
  // pendant une coupure réseau prolongée sur le terrain ; les envoyer par
  // lots de 100 borne la taille de chaque requête et limite l'impact d'un
  // échec réseau à un seul lot plutôt qu'à tout l'historique en attente.
  static const int gpsSyncBatchSize = 100;

  // Médias (voir MediaService) : un lot ne prend jamais de photo, il
  // regroupe des photos déjà présentes dans la galerie. Chaque photo
  // sélectionnée est copiée dans le stockage privé de l'application (jamais
  // l'original) puis compressée au mieux, sans jamais bloquer l'enregistrement
  // du lot si la compression échoue.
  //
  // Qualité JPEG appliquée à la copie de travail (0-100). 85 conserve les
  // détails utiles au terrain tout en réduisant sensiblement la taille.
  static const int mediaCompressionQuality = 85;
  // Dimension maximale (largeur ou hauteur, en pixels) de la copie de
  // travail : au-delà, l'image est redimensionnée avant compression.
  static const int mediaCompressionMaxDimension = 1920;
  // Taille totale (Mo) au-delà de laquelle un avertissement est affiché à
  // l'utilisateur lors de la création d'un lot, sans jamais bloquer
  // l'enregistrement.
  static const int mediaBatchWarningSizeMb = 150;
  // Nombre maximal de photos par lot : suffisant pour couvrir largement une
  // activité de terrain type (voir l'exemple du cahier des charges, 5 photos)
  // tout en bornant la mémoire, le temps de copie et la grille d'aperçu sur
  // un téléphone modeste. Appliqué dès la sélection système
  // (`ImagePicker.pickMultiImage(limit: ...)`) pour ne jamais charger plus
  // que nécessaire en mémoire.
  static const int mediaBatchMaxPhotos = 30;
  // Longueur maximale de la description d'un lot : assez pour expliquer quoi,
  // pourquoi, quelle activité et par qui (voir section 11), sans devenir un
  // rapport complet.
  static const int mediaBatchDescriptionMaxLength = 500;
}
