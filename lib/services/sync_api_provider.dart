import '../models/sync_queue_entry.dart';

/// Résultat de l'envoi d'une entrée de la file d'attente à l'API.
class SyncApiResult {
  final bool success;

  /// Identifiant attribué par le serveur, à reporter sur `server_id` en cas
  /// de succès d'une opération [SyncOperation.create]. `null` sinon.
  final int? serverId;

  /// Message d'erreur technique en cas d'échec (voir
  /// `SyncQueueRepository.markAsFailed`) — jamais de donnée personnelle.
  final String? error;

  const SyncApiResult.success({this.serverId}) : success = true, error = null;

  const SyncApiResult.failure(this.error) : success = false, serverId = null;
}

/// Abstraction du transport réseau utilisé par [SyncService] pour envoyer une
/// entrée de `sync_queue` et pour recevoir les mises à jour des référentiels.
///
/// Aucune implémentation réelle n'existe encore : l'API Laravel n'est pas
/// développée à ce stade. `MockSyncProvider` (dans `test/helpers`) permet de
/// tester le moteur de synchronisation en simulant succès/échec/timeout ; une
/// future `LaravelApiProvider` remplacera cette interface sans que
/// `SyncService` n'ait à changer.
abstract class SyncApiProvider {
  /// Envoie une entrée de la file d'attente au serveur.
  Future<SyncApiResult> send(SyncQueueEntry entry);
}

/// Implémentation par défaut utilisée tant qu'aucun endpoint d'écriture
/// n'existe côté Laravel : toute tentative d'envoi échoue explicitement
/// plutôt que d'écrire silencieusement n'importe quoi sur un serveur qui ne
/// sait pas encore le recevoir. Le sens descendant (téléchargement) ne passe
/// plus par cette abstraction : voir `DownstreamSyncService`, qui consomme
/// directement `BootstrapApiService` (la vraie forme de l'API — un
/// `/bootstrap` agrégé — ne correspondait pas à l'interface `fetchUpdates`
/// par table spéculée avant que l'API n'existe).
class UnimplementedSyncApiProvider implements SyncApiProvider {
  const UnimplementedSyncApiProvider();

  @override
  Future<SyncApiResult> send(SyncQueueEntry entry) async {
    return const SyncApiResult.failure('L\'API Laravel n\'est pas encore disponible.');
  }
}
