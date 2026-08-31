import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/sync_queue_entry.dart';
import '../repositories/sync_queue_repository.dart';
import 'bootstrap_api_service.dart';
import 'connectivity_service.dart';
import 'downstream_sync_service.dart';
import 'sync_api_provider.dart';

/// État du moteur de synchronisation, pour les écrans qui veulent réagir en
/// direct (voir `SyncStatusScreen`) — même principe que
/// `GpsService.statusNotifier`.
enum SyncRunState { idle, syncing }

/// Pourquoi une synchronisation ne s'est pas exécutée (ou son résultat), pour
/// que l'écran puisse afficher un message pertinent sans avoir à connaître le
/// détail du moteur.
enum SyncOutcome { completed, alreadyRunning, offline }

class SyncRunSummary {
  final SyncOutcome outcome;
  final int uploaded;
  final int failed;
  final int downloaded;

  const SyncRunSummary({
    required this.outcome,
    this.uploaded = 0,
    this.failed = 0,
    this.downloaded = 0,
  });
}

/// Moteur de synchronisation Offline/Online (voir cahier des charges, étape 7).
///
/// Principe (offline first) : toute donnée de terrain est d'abord enregistrée
/// dans SQLite avec `sync_status = pending`, puis une entrée est ajoutée à
/// `sync_queue` par le service producteur (`MissionService`, `GpsService`,
/// `MediaService`, `AuthService`). Ce service ne fait qu'une chose : quand une
/// connexion est disponible, traiter cette file dans l'ordre (voir
/// `SyncQueueRepository.getPendingItems`), envoyer chaque entrée via
/// [SyncApiProvider], puis répercuter le résultat sur la ligne locale
/// concernée (`server_id`, `sync_status`).
///
/// Aucun appel réseau réel n'est effectué pour le moment : [SyncApiProvider]
/// est une abstraction que l'API Laravel viendra implémenter plus tard (voir
/// `UnimplementedSyncApiProvider` et, pour les tests, `MockSyncProvider`).
class SyncService {
  final SyncQueueRepository _queueRepository;
  final ConnectivityService _connectivityService;
  final SyncApiProvider _apiProvider;
  final BootstrapApiService _bootstrapApiService;
  final DownstreamSyncService _downstreamSyncService;
  final Duration _sendTimeout;

  SyncService({
    SyncQueueRepository? queueRepository,
    ConnectivityService? connectivityService,
    SyncApiProvider? apiProvider,
    BootstrapApiService? bootstrapApiService,
    DownstreamSyncService? downstreamSyncService,
    Duration? sendTimeout,
  }) : _queueRepository = queueRepository ?? SyncQueueRepository(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _apiProvider = apiProvider ?? const UnimplementedSyncApiProvider(),
       _bootstrapApiService = bootstrapApiService ?? BootstrapApiService(),
       _downstreamSyncService = downstreamSyncService ?? DownstreamSyncService(),
       _sendTimeout = sendTimeout ?? AppConfig.apiTimeout;

  /// Instance partagée utilisée par l'application (déclenchement automatique
  /// à la reconnexion, bouton "Synchroniser maintenant", ...) — même
  /// principe que `GpsService.instance`. Les tests créent leurs propres
  /// instances avec un [SyncApiProvider] simulé plutôt que d'utiliser celle-ci.
  static final SyncService instance = SyncService();

  final ValueNotifier<SyncRunState> stateNotifier = ValueNotifier(SyncRunState.idle);

  bool get isSyncing => stateNotifier.value == SyncRunState.syncing;

  /// Point d'entrée unique pour déclencher une synchronisation complète
  /// (automatique à la reconnexion, manuelle depuis `SyncStatusScreen`, ou au
  /// démarrage de l'application). Ne lance jamais deux synchronisations en
  /// parallèle (voir section 11) : un appel pendant qu'une autre est en cours
  /// retourne immédiatement [SyncOutcome.alreadyRunning].
  Future<SyncRunSummary> syncAll() async {
    // Le drapeau doit être posé de façon strictement synchrone, avant tout
    // `await` : deux appels à `syncAll()` déclenchés sans attendre l'un
    // l'autre (démarrage de l'app + reconnexion, par exemple) doivent tous
    // les deux voir l'état à jour au moment de la vérification, plutôt que
    // de passer la vérification tous les deux avant qu'aucun n'ait eu la
    // main pour la poser.
    if (isSyncing) {
      return const SyncRunSummary(outcome: SyncOutcome.alreadyRunning);
    }
    stateNotifier.value = SyncRunState.syncing;

    try {
      if (!await _connectivityService.isOnline()) {
        return const SyncRunSummary(outcome: SyncOutcome.offline);
      }

      final downloaded = await downloadUpdates();
      final upload = await syncPendingData();
      await _queueRepository.setLastSyncedAt(DateTime.now());
      await _queueRepository.clearSyncedItems();
      return SyncRunSummary(
        outcome: SyncOutcome.completed,
        uploaded: upload.uploaded,
        failed: upload.failed,
        downloaded: downloaded,
      );
    } finally {
      stateNotifier.value = SyncRunState.idle;
    }
  }

  /// Traite la file d'attente locale : envoie chaque entrée `pending`, dans
  /// l'ordre de dépendance (voir `SyncQueueRepository.getPendingItems`), et
  /// répercute le résultat sur la donnée locale concernée.
  ///
  /// Ne s'arrête pas au premier échec : un lot média en échec ne doit pas
  /// empêcher la synchronisation des positions GPS suivantes.
  Future<({int uploaded, int failed})> syncPendingData() async {
    final items = await _queueRepository.getPendingItems();
    var uploaded = 0;
    var failed = 0;

    for (final entry in items) {
      await _queueRepository.markAsSyncing(entry.id!);
      try {
        final result = await _apiProvider.send(entry).timeout(_sendTimeout);
        if (result.success) {
          await _applyResult(entry, result);
          await _queueRepository.markAsSynced(entry.id!);
          uploaded++;
        } else {
          await _queueRepository.markAsFailed(entry.id!, error: result.error);
          failed++;
        }
      } on TimeoutException {
        await _queueRepository.markAsFailed(entry.id!, error: 'Délai de synchronisation dépassé.');
        failed++;
      } catch (e) {
        await _queueRepository.markAsFailed(entry.id!, error: e.toString());
        failed++;
      }
    }

    return (uploaded: uploaded, failed: failed);
  }

  /// Télécharge les référentiels (secteurs, groupements, CLD, villages) et
  /// les missions/affectations depuis Laravel (`GET /bootstrap`, qui agrège
  /// tout en un seul appel) et les persiste localement via
  /// [DownstreamSyncService]. Ces données vont uniquement de Laravel vers
  /// Flutter (voir section 4) : jamais l'inverse.
  ///
  /// Non-bloquant, comme le reste du moteur : un échec (hors ligne malgré la
  /// vérification amont, session expirée, ...) ne doit jamais empêcher la
  /// phase d'envoi de [syncPendingData] qui suit.
  Future<int> downloadUpdates() async {
    try {
      final data = await _bootstrapApiService.getBootstrap();
      await _downstreamSyncService.applyBootstrap(data);
      return data.clds.length + data.villages.length + data.missions.length;
    } catch (_) {
      return 0;
    }
  }

  /// Met à jour la ligne locale correspondant à [entry] : `server_id` (pour
  /// une création) et `sync_status = synced`. Générique à toutes les tables
  /// grâce aux colonnes communes `local_id`/`server_id`/`sync_status` (voir
  /// `SyncColumns`) : une entité déjà supprimée localement (opération
  /// `delete` déjà appliquée immédiatement par son service, voir
  /// `MediaService.deleteBatch`) n'a simplement plus de ligne à mettre à
  /// jour — la requête ne touche alors aucune ligne, sans erreur.
  Future<void> _applyResult(SyncQueueEntry entry, SyncApiResult result) async {
    final db = await DatabaseHelper.instance.database;
    final values = <String, Object?>{
      'sync_status': SyncStatus.synced.value,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (result.serverId != null) {
      values['server_id'] = result.serverId;
    }
    await db.update(
      entry.entityTable,
      values,
      where: 'local_id = ?',
      whereArgs: [entry.entityLocalId],
    );
  }
}
