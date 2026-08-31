import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Implémentation de [PathProviderPlatform] pour les tests : retourne un
/// dossier temporaire du système à la place du vrai dossier documents de
/// l'application (indisponible hors application réelle). Voir
/// `MediaService`/`FileStorageUtils`, seuls consommateurs de
/// `getApplicationDocumentsDirectory()` dans le projet.
///
/// Même principe que `FakeSecureSessionStore`/`FakeApiClient` : isoler une
/// dépendance plateforme derrière une interface déjà prévue pour ça.
class FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;

  FakePathProviderPlatform(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
