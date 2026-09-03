import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../database/database_tables.dart';
import '../models/gps_position.dart';
import '../repositories/gps_repository.dart';
import '../repositories/mission_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'connectivity_service.dart';
import 'gps_api_service.dart';

/// Pourquoi une synchronisation GPS ne s'est pas exécutée (ou son résultat) —
/// même principe que `MediaSyncOutcome`. [sessionExpired] : un 401 arrête
/// l'envoi des lots restants (section 17) sans marquer leurs positions en
/// échec — elles reviennent `pending`, ce n'est pas leur faute.
enum GpsSyncOutcome { completed, alreadyRunning, offline, sessionExpired }

class GpsSyncSummary {
  final GpsSyncOutcome outcome;
  final int synced;
  final int alreadySynced;
  final int rejected;
  final int failed;

  const GpsSyncSummary({
    required this.outcome,
    this.synced = 0,
    this.alreadySynced = 0,
    this.rejected = 0,
    this.failed = 0,
  });
}

/// Synchronisation des positions GPS vers Laravel (étape 9).
///
/// Chemin dédié, séparé du moteur générique `SyncService`/`sync_queue` — même
/// principe que `MediaSyncService` (voir sa documentation) : la collecte
/// continue d'ajouter chaque position à `sync_queue` (`GpsService`,
/// inchangé — un test existant en dépend), mais ce service travaille
/// directement sur `gps_positions.sync_status`, en lots, ce que le moteur
/// générique — une entrée à la fois — ne permet pas. Une fois un lot envoyé
/// avec succès, l'entrée `sync_queue` correspondante est marquée `synced`
/// (voir `SyncQueueRepository.markSyncedByEntity`) pour que le journal de
/// `SyncStatusScreen` ne la retraite jamais inutilement.
///
/// Traite les positions par lots de [AppConfig.gpsSyncBatchSize] (section 13),
/// jamais tout l'historique en une seule requête.
class GpsSyncService {
  final GpsRepository _gpsRepository;
  final MissionRepository _missionRepository;
  final SyncQueueRepository _syncQueueRepository;
  final ConnectivityService _connectivityService;
  final GpsApiService _apiService;

  GpsSyncService({
    GpsRepository? gpsRepository,
    MissionRepository? missionRepository,
    SyncQueueRepository? syncQueueRepository,
    ConnectivityService? connectivityService,
    GpsApiService? apiService,
  }) : _gpsRepository = gpsRepository ?? GpsRepository(),
       _missionRepository = missionRepository ?? MissionRepository(),
       _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _apiService = apiService ?? GpsApiService();

  /// Instance partagée utilisée par les écrans — même principe que
  /// `MediaSyncService.instance`.
  static final GpsSyncService instance = GpsSyncService();

  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  bool get isSyncing => isSyncingNotifier.value;

  Future<GpsSyncSummary> syncPendingPositions() async {
    if (isSyncing) {
      return const GpsSyncSummary(outcome: GpsSyncOutcome.alreadyRunning);
    }
    isSyncingNotifier.value = true;

    try {
      await _gpsRepository.resetStaleSyncingStates();

      if (!await _connectivityService.isOnline()) {
        return const GpsSyncSummary(outcome: GpsSyncOutcome.offline);
      }

      final positions = await _gpsRepository.findPendingOrFailedSync();
      var synced = 0;
      var alreadySynced = 0;
      var rejected = 0;
      var failed = 0;
      final missionServerIdCache = <int, int?>{};

      for (final chunk in _chunk(positions, AppConfig.gpsSyncBatchSize)) {
        final sendable = <GpsPosition>[];
        final missionServerIds = <int, int>{};
        final unresolvedIds = <int>[];

        for (final position in chunk) {
          final missionId = position.missionId;
          if (!missionServerIdCache.containsKey(missionId)) {
            final mission = await _missionRepository.findById(missionId);
            missionServerIdCache[missionId] = mission?.serverId;
          }
          final missionServerId = missionServerIdCache[missionId];
          if (missionServerId == null) {
            // La mission de cette position n'est pas encore synchronisée :
            // impossible de l'envoyer maintenant, retentée automatiquement au
            // prochain passage une fois la mission elle-même synchronisée.
            unresolvedIds.add(position.id!);
          } else {
            missionServerIds[missionId] = missionServerId;
            sendable.add(position);
          }
        }

        if (unresolvedIds.isNotEmpty) {
          await _gpsRepository.updateSyncStatus(unresolvedIds, SyncStatus.failed);
          failed += unresolvedIds.length;
        }
        if (sendable.isEmpty) continue;

        final sendableIds = sendable.map((p) => p.id!).toList();
        await _gpsRepository.updateSyncStatus(sendableIds, SyncStatus.syncing);

        try {
          final result = await _apiService.syncPositions(sendable, missionServerIds);

          for (final position in sendable) {
            final acceptedServerId = result.acceptedServerIdsByLocalId[position.localId];
            final alreadyServerId = result.alreadySyncedServerIdsByLocalId[position.localId];

            if (acceptedServerId != null || alreadyServerId != null) {
              await _gpsRepository.markSynced(
                id: position.id!,
                serverId: (acceptedServerId ?? alreadyServerId)!,
              );
              await _syncQueueRepository.markSyncedByEntity(
                entityTable: DatabaseTables.gpsPositions,
                entityLocalId: position.localId,
              );
              if (acceptedServerId != null) {
                synced++;
              } else {
                alreadySynced++;
              }
            } else {
              // Rejetée par le serveur (mission non autorisée, coordonnées
              // hors intervalle, ...) ou absente de la réponse : le statut
              // `failed` existant est réutilisé (section 14), une position
              // durablement rejetée réessaiera simplement sans jamais
              // réussir tant que la cause n'est pas corrigée côté serveur.
              await _gpsRepository.updateSyncStatus([position.id!], SyncStatus.failed);
              if (result.rejectedReasonsByLocalId.containsKey(position.localId)) {
                rejected++;
              } else {
                failed++;
              }
            }
          }
        } on UnauthorizedException {
          // Revient à `pending` (pas `failed`) : c'est la session qui est en
          // cause, pas ces positions (section 17) — jamais perdues.
          await _gpsRepository.updateSyncStatus(sendableIds, SyncStatus.pending);
          return GpsSyncSummary(
            outcome: GpsSyncOutcome.sessionExpired,
            synced: synced,
            alreadySynced: alreadySynced,
            rejected: rejected,
            failed: failed,
          );
        } catch (_) {
          // Réseau, timeout, 5xx, ... : le lot entier reste disponible pour
          // une nouvelle tentative (section 16), jamais supprimé.
          await _gpsRepository.updateSyncStatus(sendableIds, SyncStatus.failed);
          failed += sendableIds.length;
        }
      }

      return GpsSyncSummary(
        outcome: GpsSyncOutcome.completed,
        synced: synced,
        alreadySynced: alreadySynced,
        rejected: rejected,
        failed: failed,
      );
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  Iterable<List<GpsPosition>> _chunk(List<GpsPosition> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      yield items.sublist(i, i + size > items.length ? items.length : i + size);
    }
  }
}
