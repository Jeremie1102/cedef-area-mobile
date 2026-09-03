import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/id_generator.dart';
import '../database/database_tables.dart';
import '../models/observation.dart';
import '../repositories/mission_repository.dart';
import '../repositories/observation_repository.dart';
import '../repositories/sync_queue_repository.dart';

/// Service métier gérant les observations et constats terrain (Phase F).
///
/// Assure l'enregistrement 100% hors-ligne, la validation des données,
/// la liaison avec la mission parente et la mise en file d'attente
/// pour la synchronisation montante avec Laravel.
class ObservationService {
  final ObservationRepository _observationRepository;
  final MissionRepository _missionRepository;
  final SyncQueueRepository _syncQueueRepository;

  ObservationService({
    ObservationRepository? observationRepository,
    MissionRepository? missionRepository,
    SyncQueueRepository? syncQueueRepository,
  }) : _observationRepository = observationRepository ?? ObservationRepository(),
       _missionRepository = missionRepository ?? MissionRepository(),
       _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  static final ObservationService instance = ObservationService();

  /// Crée un nouveau constat terrain pour une mission donnée.
  ///
  /// * Vérifie que le titre n'est pas vide.
  /// * Récupère les métadonnées de la mission (notamment `mission_local_id` et `mission_server_id`).
  /// * Enregistre l'observation dans SQLite avec le statut `pending`.
  /// * Ajoute l'opération de création dans `sync_queue`.
  Future<Observation> createObservation({
    required int missionId,
    required int userId,
    required ObservationCategory category,
    required ObservationSeverity severity,
    required String title,
    required String description,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    DateTime? recordedAt,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ValidationException('Le titre du constat est obligatoire.');
    }

    final mission = await _missionRepository.findById(missionId);
    if (mission == null) {
      throw const NotFoundException('Mission introuvable pour ce constat.');
    }

    final now = DateTime.now();
    final localId = IdGenerator.generate();
    final effectiveRecordedAt = recordedAt ?? now;

    final observation = Observation(
      localId: localId,
      missionId: missionId,
      missionLocalId: mission.localId,
      missionServerId: mission.serverId,
      userId: userId,
      category: category,
      severity: severity,
      title: trimmedTitle,
      description: description.trim(),
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      recordedAt: effectiveRecordedAt,
      syncStatus: SyncStatus.pending,
      syncAttempts: 0,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _observationRepository.create(observation);
    final saved = observation.copyWith(id: id);

    await _syncQueueRepository.addToQueue(
      entityTable: DatabaseTables.observations,
      entityLocalId: saved.localId,
      operation: SyncOperation.create,
      payload: saved.toMap(),
    );

    return saved;
  }

  /// Retourne la liste des observations d'une mission (triées par date décroissante).
  Future<List<Observation>> getObservationsForMission(int missionId) {
    return _observationRepository.getByMissionId(missionId);
  }

  /// Récupère une observation par son identifiant SQLite interne.
  Future<Observation?> getObservationById(int id) {
    return _observationRepository.getById(id);
  }

  /// Récupère une observation par son UUID `local_id`.
  Future<Observation?> getObservationByLocalId(String localId) {
    return _observationRepository.getByLocalId(localId);
  }

  /// Compte le nombre de constats enregistrés pour une mission.
  Future<int> countObservations(int missionId) {
    return _observationRepository.countByMission(missionId);
  }

  /// Met à jour un constat existant et enregistre l'opération dans la file de synchronisation.
  Future<Observation> updateObservation({
    required int id,
    ObservationCategory? category,
    ObservationSeverity? severity,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
  }) async {
    final existing = await _observationRepository.getById(id);
    if (existing == null) {
      throw const NotFoundException('Constat introuvable.');
    }

    final updatedTitle = title != null ? title.trim() : existing.title;
    if (updatedTitle.isEmpty) {
      throw const ValidationException('Le titre du constat ne peut pas être vide.');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      category: category ?? existing.category,
      severity: severity ?? existing.severity,
      title: updatedTitle,
      description: description != null ? description.trim() : existing.description,
      latitude: latitude ?? existing.latitude,
      longitude: longitude ?? existing.longitude,
      altitude: altitude ?? existing.altitude,
      accuracy: accuracy ?? existing.accuracy,
      syncStatus: SyncStatus.pending,
      updatedAt: now,
    );

    await _observationRepository.update(updated);

    await _syncQueueRepository.addToQueue(
      entityTable: DatabaseTables.observations,
      entityLocalId: updated.localId,
      operation: SyncOperation.update,
      payload: updated.toMap(),
    );

    return updated;
  }

  /// Supprime un constat et notifie la file de synchronisation.
  Future<void> deleteObservation(int id) async {
    final existing = await _observationRepository.getById(id);
    if (existing == null) return;

    await _observationRepository.delete(id);

    await _syncQueueRepository.addToQueue(
      entityTable: DatabaseTables.observations,
      entityLocalId: existing.localId,
      operation: SyncOperation.delete,
    );
  }
}
