import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../database/database_tables.dart';
import '../models/cld.dart';
import '../models/mission.dart';
import '../models/village.dart';
import '../repositories/mission_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'gps_service.dart';

/// Territoire concerné par une mission (CLD et villages, déduits des CLD),
/// pour l'écran de détails.
class MissionTerritory {
  final List<Cld> clds;
  final List<Village> villages;

  const MissionTerritory({required this.clds, required this.villages});
}

/// Opérations métier du cycle de vie d'une mission.
///
/// L'animateur ne crée ni ne modifie une mission (titre, dates, CLD, agents
/// affectés) : ces informations viennent de l'Assistant Technique via
/// Laravel. Ce service ne gère donc que ce que l'animateur peut réellement
/// faire : consulter, démarrer, mettre en pause, reprendre, terminer.
///
/// Les transitions de statut sont volontairement strictes (voir chaque
/// méthode) : une mission `completed` ou `cancelled` ne peut plus être
/// redémarrée. Ce service orchestre également le suivi GPS (voir
/// `GpsService`) : il démarre avec la mission, s'arrête avec sa pause ou sa
/// fin — l'UI n'a jamais besoin de piloter `GpsService` directement pour ces
/// transitions (voir `UI → MissionService → GpsService → GpsRepository`).
class MissionService {
  final MissionRepository _missionRepository;
  final GpsService _gpsService;
  final SyncQueueRepository _syncQueueRepository;

  MissionService({
    MissionRepository? missionRepository,
    GpsService? gpsService,
    SyncQueueRepository? syncQueueRepository,
  }) : _missionRepository = missionRepository ?? MissionRepository(),
       _gpsService = gpsService ?? GpsService.instance,
       _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<List<Mission>> getMyMissions(int userId) => _missionRepository.findByUser(userId);

  Future<Mission?> getMissionById(int missionId) => _missionRepository.findById(missionId);

  Future<MissionTerritory> getMissionTerritory(int missionId) async {
    final clds = await _missionRepository.getCldsForMission(missionId);
    final villages = await _missionRepository.getVillagesForMission(missionId);
    return MissionTerritory(clds: clds, villages: villages);
  }

  /// Mission actuellement en cours (ou en pause) pour cet utilisateur, s'il y
  /// en a une.
  Future<Mission?> getActiveMission(int userId) =>
      _missionRepository.getActiveMissionForUser(userId);

  /// Résumé du parcours GPS enregistré pour une mission (voir la section
  /// « Parcours » d'une mission terminée).
  Future<MissionTrackSummary> getMissionTrackSummary(int missionId) =>
      _gpsService.getMissionTrackSummary(missionId);

  /// Parcours GPS enregistrés par l'utilisateur, toutes missions confondues
  /// (voir l'écran « Mes parcours »).
  Future<List<MissionTrack>> getMyTracks(int userId) => _gpsService.getMyTracks(userId);

  /// À appeler au lancement de l'application (voir `HomeScreen`) : si une
  /// mission de cet utilisateur est déjà `in_progress`, relance son suivi
  /// GPS. Nécessaire car fermer l'application arrête le minuteur de
  /// `GpsService` (aucun service d'arrière-plan n'est utilisé) : sans cet
  /// appel, rouvrir l'application sur une mission déjà démarrée laisserait
  /// le suivi arrêté jusqu'à la prochaine pause/reprise manuelle.
  Future<void> resumeTrackingForActiveMission(int userId) async {
    final mission = await getActiveMission(userId);
    if (mission != null && mission.statut == MissionStatus.inProgress) {
      await _gpsService.startTracking(missionId: mission.id!, userId: userId);
    }
  }

  Future<Mission> startMission(int missionId, {required int userId}) async {
    final mission = await _requireMission(missionId);
    if (mission.statut != MissionStatus.pending) {
      throw ValidationException(_transitionError(mission.statut, 'démarrer'));
    }

    final now = DateTime.now();
    final updated = mission.copyWith(
      statut: MissionStatus.inProgress,
      startedAt: now,
      syncStatus: SyncStatus.pending,
      updatedAt: now,
    );
    await _missionRepository.update(updated);
    await _enqueueEvent(updated, SyncOperation.start, occurredAt: now);
    await _gpsService.startTracking(missionId: missionId, userId: userId);
    return updated;
  }

  Future<Mission> pauseMission(int missionId) async {
    final mission = await _requireMission(missionId);
    if (mission.statut != MissionStatus.inProgress) {
      throw ValidationException(_transitionError(mission.statut, 'mettre en pause'));
    }

    final now = DateTime.now();
    final updated = mission.copyWith(
      statut: MissionStatus.paused,
      pausedAt: now,
      syncStatus: SyncStatus.pending,
      updatedAt: now,
    );
    await _missionRepository.update(updated);
    await _enqueueEvent(updated, SyncOperation.pause, occurredAt: now);
    _gpsService.pauseTracking();
    return updated;
  }

  Future<Mission> resumeMission(int missionId, {required int userId}) async {
    final mission = await _requireMission(missionId);
    if (mission.statut != MissionStatus.paused) {
      throw ValidationException(_transitionError(mission.statut, 'reprendre'));
    }

    final now = DateTime.now();
    final updated = mission.copyWith(
      statut: MissionStatus.inProgress,
      resumedAt: now,
      syncStatus: SyncStatus.pending,
      updatedAt: now,
    );
    await _missionRepository.update(updated);
    await _enqueueEvent(updated, SyncOperation.resume, occurredAt: now);

    // `resumeTracking` ne fonctionne que si l'application n'a jamais été
    // fermée depuis la mise en pause (le minuteur précédent est encore en
    // mémoire) ; sinon on redémarre une session de suivi normale.
    final resumed = await _gpsService.resumeTracking();
    if (!resumed) {
      await _gpsService.startTracking(missionId: missionId, userId: userId);
    }
    return updated;
  }

  Future<Mission> completeMission(int missionId, {String? observation}) async {
    final mission = await _requireMission(missionId);
    if (mission.statut != MissionStatus.inProgress && mission.statut != MissionStatus.paused) {
      throw ValidationException(_transitionError(mission.statut, 'terminer'));
    }

    final now = DateTime.now();
    final updated = mission.copyWith(
      statut: MissionStatus.completed,
      endedAt: now,
      endObservation: observation,
      syncStatus: SyncStatus.pending,
      updatedAt: now,
    );
    await _missionRepository.update(updated);
    await _enqueueEvent(
      updated,
      SyncOperation.complete,
      occurredAt: now,
      observation: observation,
    );
    await _gpsService.stopTracking();
    return updated;
  }

  /// Ajoute à la file de synchronisation un événement de cycle de vie de
  /// mission (voir section 7 : chaque transition est un événement distinct,
  /// pas seulement une mise à jour de l'état courant).
  Future<void> _enqueueEvent(
    Mission mission,
    SyncOperation operation, {
    required DateTime occurredAt,
    String? observation,
  }) {
    return _syncQueueRepository.addToQueue(
      entityTable: DatabaseTables.missions,
      entityLocalId: mission.localId,
      operation: operation,
      payload: {
        'occurred_at': occurredAt.toIso8601String(),
        if (observation != null && observation.isNotEmpty) 'observation': observation,
      },
    );
  }

  Future<Mission> _requireMission(int missionId) async {
    final mission = await _missionRepository.findById(missionId);
    if (mission == null) {
      throw const ValidationException('Mission introuvable.');
    }
    return mission;
  }

  String _transitionError(MissionStatus current, String action) {
    switch (current) {
      case MissionStatus.completed:
        return 'Impossible de $action : la mission est déjà terminée.';
      case MissionStatus.cancelled:
        return 'Impossible de $action : la mission a été annulée.';
      case MissionStatus.pending:
        return 'Impossible de $action : la mission n\'a pas encore été démarrée.';
      case MissionStatus.inProgress:
        return 'Impossible de $action : la mission est déjà en cours.';
      case MissionStatus.paused:
        return 'Impossible de $action : la mission est en pause.';
    }
  }
}
