import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/media_batch.dart';
import '../repositories/cld_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/mission_repository.dart';
import '../repositories/village_repository.dart';
import 'connectivity_service.dart';
import 'media_api_service.dart';

/// Pourquoi une synchronisation de médias ne s'est pas exécutée (ou son
/// résultat), sur le même principe que `SyncOutcome` (voir `SyncService`).
///
/// [sessionExpired] est spécifique aux médias (section 23 du cahier des
/// charges) : un 401 doit arrêter l'envoi des lots suivants plutôt que de les
/// marquer `failed` un par un — ce n'est pas une erreur du lot, mais de la
/// session.
enum MediaSyncOutcome { completed, alreadyRunning, offline, sessionExpired }

class MediaSyncSummary {
  final MediaSyncOutcome outcome;
  final int synced;
  final int failed;

  const MediaSyncSummary({required this.outcome, this.synced = 0, this.failed = 0});
}

/// Synchronisation des lots de médias vers Laravel (étape 8).
///
/// Chemin dédié, séparé du moteur générique `SyncService`/`SyncQueueRepository` :
/// un lot se transmet en une seule requête multipart (métadonnées + toutes ses
/// photos, voir `MediaApiService`), ce que le moteur générique — une entrée de
/// file d'attente à la fois, JSON uniquement — ne modélise pas bien. Les lots
/// sont donc traités directement depuis `media_batches.sync_status`
/// (`MediaRepository.getPendingOrFailedSyncBatches`), jamais via `sync_queue` (voir
/// `MediaService`, qui n'y enregistre plus rien pour les médias).
///
/// Traite les lots un par un (section 21 : jamais tout en même temps, pour
/// limiter mémoire/réseau/risque de timeout).
class MediaSyncService {
  final MediaRepository _mediaRepository;
  final MissionRepository _missionRepository;
  final CldRepository _cldRepository;
  final VillageRepository _villageRepository;
  final ConnectivityService _connectivityService;
  final MediaApiService _apiService;

  MediaSyncService({
    MediaRepository? mediaRepository,
    MissionRepository? missionRepository,
    CldRepository? cldRepository,
    VillageRepository? villageRepository,
    ConnectivityService? connectivityService,
    MediaApiService? apiService,
  }) : _mediaRepository = mediaRepository ?? MediaRepository(),
       _missionRepository = missionRepository ?? MissionRepository(),
       _cldRepository = cldRepository ?? CldRepository(),
       _villageRepository = villageRepository ?? VillageRepository(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _apiService = apiService ?? MediaApiService();

  /// Instance partagée utilisée par les écrans (bouton "Synchroniser" de
  /// `MediaScreen`) — même principe que `SyncService.instance`.
  static final MediaSyncService instance = MediaSyncService();

  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  bool get isSyncing => isSyncingNotifier.value;

  /// Envoie tous les lots `pending` de l'utilisateur, un par un. Ne lance
  /// jamais deux synchronisations en parallèle (voir `SyncService.syncAll`
  /// pour le même principe et la même raison du drapeau posé de façon
  /// synchrone avant tout `await`).
  Future<MediaSyncSummary> syncPendingBatches() async {
    if (isSyncing) {
      return const MediaSyncSummary(outcome: MediaSyncOutcome.alreadyRunning);
    }
    isSyncingNotifier.value = true;

    try {
      await _mediaRepository.resetStaleSyncingStates();

      if (!await _connectivityService.isOnline()) {
        return const MediaSyncSummary(outcome: MediaSyncOutcome.offline);
      }

      final batches = await _mediaRepository.getPendingOrFailedSyncBatches();
      var synced = 0;
      var failed = 0;

      for (final batch in batches) {
        try {
          await _syncOne(batch);
          synced++;
        } on UnauthorizedException {
          // Section 23 : une session expirée arrête l'envoi des lots
          // restants (laissés `pending`, inchangés) plutôt que de les faire
          // échouer un par un — l'utilisateur doit se reconnecter, pas
          // réessayer chaque lot individuellement.
          return MediaSyncSummary(
            outcome: MediaSyncOutcome.sessionExpired,
            synced: synced,
            failed: failed,
          );
        } catch (_) {
          failed++;
        }
      }

      return MediaSyncSummary(outcome: MediaSyncOutcome.completed, synced: synced, failed: failed);
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Synchronise un seul lot : résout les identifiants serveur de sa mission
  /// (et de son CLD/village éventuels), envoie le lot et ses photos, puis
  /// répercute le résultat localement (`server_id`, `sync_status = synced`
  /// pour le lot et chacune de ses photos).
  ///
  /// Laisse toujours la donnée locale intacte en cas d'échec (section 22 :
  /// jamais de perte du lot tant que le serveur ne l'a pas confirmé) — marque
  /// seulement `sync_status = failed`, sans jamais toucher aux fichiers.
  Future<void> _syncOne(MediaBatch batch) async {
    try {
      final missionId = batch.missionId;
      if (missionId == null) {
        throw const SyncException('Ce lot n\'est associé à aucune mission.');
      }
      final mission = await _missionRepository.findById(missionId);
      final missionServerId = mission?.serverId;
      if (missionServerId == null) {
        throw const SyncException(
          'La mission de ce lot n\'est pas encore synchronisée avec le serveur.',
        );
      }

      int? cldServerId;
      if (batch.cldId != null) {
        final cld = await _cldRepository.getById(batch.cldId!);
        cldServerId = cld?.serverId;
        if (cldServerId == null) {
          throw const SyncException('Le CLD de ce lot n\'est pas encore synchronisé avec le serveur.');
        }
      }

      int? villageServerId;
      if (batch.villageId != null) {
        final village = await _villageRepository.getById(batch.villageId!);
        villageServerId = village?.serverId;
        if (villageServerId == null) {
          throw const SyncException(
            'Le village de ce lot n\'est pas encore synchronisé avec le serveur.',
          );
        }
      }

      final items = await _mediaRepository.getItemsByBatch(batch.id!);
      if (items.isEmpty) {
        throw const SyncException('Ce lot ne contient aucune photo.');
      }

      final result = await _apiService.uploadBatch(
        batch: batch,
        items: items,
        missionServerId: missionServerId,
        cldServerId: cldServerId,
        villageServerId: villageServerId,
      );

      await _mediaRepository.markBatchSyncedWithItems(
        batch: batch,
        serverBatchId: result.id,
        items: items,
        itemServerIdsByLocalId: result.itemServerIdsByLocalId,
      );
    } on UnauthorizedException {
      // Ni synced ni failed : la session (pas le lot) est en cause, voir
      // syncPendingBatches. Le lot reste `pending` tel quel.
      rethrow;
    } catch (e) {
      await _mediaRepository.updateBatch(
        batch.copyWith(syncStatus: SyncStatus.failed, updatedAt: DateTime.now()),
      );
      rethrow;
    }
  }
}
