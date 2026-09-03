import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/id_generator.dart';
import '../database/database_tables.dart';
import '../models/gps_position.dart';
import '../models/mission.dart';
import '../repositories/gps_repository.dart';
import '../repositories/mission_repository.dart';
import '../repositories/sync_queue_repository.dart';

/// État affiché à l'utilisateur pour l'indicateur GPS (section « Mission en
/// cours ») : volontairement simple, sans donnée technique.
///
/// * [idle] : aucun suivi en cours (pas de mission active).
/// * [searching] : un relevé est en cours d'acquisition.
/// * [active] : le dernier relevé a réussi.
/// * [unavailable] : permission refusée, GPS désactivé, ou dernier relevé en échec.
enum GpsTrackingStatus { idle, searching, active, unavailable }

/// Résumé du parcours enregistré pour une mission (voir « Parcours » dans
/// les détails d'une mission terminée). La distance est une estimation
/// obtenue en sommant la distance à vol d'oiseau entre positions
/// consécutives : suffisant pour donner un ordre de grandeur, pas une mesure
/// topographique précise.
class MissionTrackSummary {
  final int positionCount;
  final DateTime? firstRecordedAt;
  final DateTime? lastRecordedAt;
  final double? distanceMeters;

  const MissionTrackSummary({
    required this.positionCount,
    this.firstRecordedAt,
    this.lastRecordedAt,
    this.distanceMeters,
  });
}

/// Parcours d'une mission pour l'écran « Mes parcours » : la mission
/// elle-même, le résumé de son suivi GPS ([MissionTrackSummary]) et si au
/// moins une de ses positions n'a pas encore été synchronisée.
class MissionTrack {
  final Mission mission;
  final MissionTrackSummary summary;
  final bool hasPendingSync;

  const MissionTrack({required this.mission, required this.summary, required this.hasPendingSync});
}

/// Service de géolocalisation.
///
/// Le suivi GPS est toujours lié à une mission : il n'existe aucun mode de
/// localisation permanente de l'utilisateur (voir section 20 du cahier des
/// charges). `startTracking` démarre un relevé périodique (toutes les
/// [AppConfig.gpsIntervalSeconds] secondes, voir [AppConfig] pour les
/// paramètres) tant que l'application reste active ; `pauseTracking` et
/// `stopTracking` l'arrêtent. Il n'y a volontairement aucun service
/// d'arrière-plan Android/iOS ici : au-delà de ce que `Geolocator` fournit
/// nativement, une solution de suivi en arrière-plan demanderait des
/// packages et une configuration spécifiques par plateforme que ce projet
/// ne contient pas encore — mieux vaut un suivi fiable pendant que
/// l'application est ouverte qu'un suivi en arrière-plan instable. Voir
/// `MissionService.resumeTrackingForActiveMission` pour la reprise après une
/// fermeture de l'application.
class GpsService {
  final GpsRepository _gpsRepository;
  final MissionRepository _missionRepository;
  final SyncQueueRepository _syncQueueRepository;

  /// Points d'injection utilisés par les tests pour remplacer les appels
  /// `Geolocator` réels (qui nécessitent un appareil/plugin natif, absent en
  /// environnement de test) par des positions simulées — voir
  /// `test/services/gps_service_test.dart`. `null` en usage normal : les
  /// méthodes utilisent alors directement `Geolocator`.
  final Future<bool> Function()? _permissionChecker;
  final Future<Position> Function()? _positionProvider;

  GpsService({
    GpsRepository? gpsRepository,
    MissionRepository? missionRepository,
    SyncQueueRepository? syncQueueRepository,
    Future<bool> Function()? permissionChecker,
    Future<Position> Function()? positionProvider,
  }) : _gpsRepository = gpsRepository ?? GpsRepository(),
       _missionRepository = missionRepository ?? MissionRepository(),
       _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(),
       // ignore: prefer_initializing_formals
       _permissionChecker = permissionChecker,
       // ignore: prefer_initializing_formals
       _positionProvider = positionProvider;

  /// Instance partagée utilisée par `MissionService` et par les écrans pour
  /// observer l'état du suivi en cours (voir [statusNotifier] et
  /// [lastPositionNotifier]) : un seul suivi peut être actif à la fois.
  static final GpsService instance = GpsService();

  Timer? _timer;
  int? _trackingMissionId;
  int? _trackingUserId;
  GpsPosition? _lastStoredPosition;

  final ValueNotifier<GpsTrackingStatus> statusNotifier = ValueNotifier(GpsTrackingStatus.idle);
  final ValueNotifier<GpsPosition?> lastPositionNotifier = ValueNotifier(null);

  bool get isTracking => _timer != null;

  Future<bool> ensurePermission() async {
    if (_permissionChecker != null) return _permissionChecker();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }
    return true;
  }

  Future<Position> getCurrentPosition() async {
    if (_permissionChecker != null || _positionProvider != null) {
      final hasPermission = await ensurePermission();
      if (!hasPermission) {
        throw const GpsException('La localisation n\'est pas autorisée ou activée.');
      }
      return _positionProvider!();
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const GpsException('Le service de localisation (GPS) du téléphone est désactivé.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const GpsException('La permission de localisation a été refusée.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GpsException(
        'La permission de localisation est refusée définitivement. Activez-la dans les paramètres de l\'appareil.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Enregistre une position ponctuelle pour une mission en cours (relevé
  /// manuel, sans filtre de précision ni de distance : c'est un geste
  /// explicite). Rejette toute mission qui n'est pas `in_progress` — une
  /// mission en pause, terminée ou pas encore démarrée ne doit jamais
  /// recevoir de nouvelle position.
  Future<GpsPosition> recordPosition({required int missionId, required int userId}) async {
    await _requireMissionInProgress(missionId);

    final position = await getCurrentPosition();
    final now = DateTime.now();
    final gpsPosition = GpsPosition(
      localId: IdGenerator.generate(),
      missionId: missionId,
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      recordedAt: now,
      createdAt: now,
    );

    final id = await _gpsRepository.insert(gpsPosition);
    final saved = gpsPosition.copyWith(id: id);
    await _enqueueCreate(saved);
    _lastStoredPosition = saved;
    lastPositionNotifier.value = saved;
    return saved;
  }

  // --- Suivi périodique --------------------------------------------------

  /// Démarre (ou relance, si déjà en cours pour une autre mission) le suivi
  /// GPS périodique d'une mission. Effectue un premier relevé immédiatement
  /// puis un relevé toutes les [AppConfig.gpsIntervalSeconds] secondes.
  Future<void> startTracking({required int missionId, required int userId}) async {
    if (_trackingMissionId == missionId && isTracking) return;

    await stopTracking();
    _trackingMissionId = missionId;
    _trackingUserId = userId;
    _lastStoredPosition = await _gpsRepository.findLastForMission(missionId);
    _armTimer();
  }

  /// Arrête temporairement le suivi (mission mise en pause) sans oublier
  /// quelle mission était suivie, pour permettre [resumeTracking].
  void pauseTracking() {
    _timer?.cancel();
    _timer = null;
    statusNotifier.value = GpsTrackingStatus.idle;
  }

  /// Relance le suivi précédemment mis en pause, dans la même session
  /// applicative. Retourne `false` si aucune mission n'était en mémoire
  /// (par exemple si l'application a été fermée puis rouverte pendant la
  /// pause) : dans ce cas, appeler [startTracking] avec la mission et
  /// l'utilisateur explicitement.
  Future<bool> resumeTracking() async {
    if (_trackingMissionId == null || _trackingUserId == null) return false;
    _armTimer();
    return true;
  }

  /// Arrête définitivement le suivi (mission terminée) et oublie la mission
  /// suivie.
  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    _trackingMissionId = null;
    _trackingUserId = null;
    _lastStoredPosition = null;
    statusNotifier.value = GpsTrackingStatus.idle;
    lastPositionNotifier.value = null;
  }

  void _armTimer() {
    statusNotifier.value = GpsTrackingStatus.searching;
    unawaited(_captureOnce());
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.gpsIntervalSeconds),
      (_) => _captureOnce(),
    );
  }

  /// Un relevé périodique : jamais d'exception propagée (le minuteur ne
  /// doit jamais s'arrêter à cause d'une erreur ponctuelle), un échec se
  /// traduit uniquement par [GpsTrackingStatus.unavailable].
  Future<void> _captureOnce() async {
    final missionId = _trackingMissionId;
    final userId = _trackingUserId;
    if (missionId == null || userId == null) return;

    statusNotifier.value = GpsTrackingStatus.searching;

    Position position;
    try {
      await _requireMissionInProgress(missionId);
      position = await getCurrentPosition().timeout(const Duration(seconds: 20));
    } catch (_) {
      statusNotifier.value = GpsTrackingStatus.unavailable;
      return;
    }

    statusNotifier.value = GpsTrackingStatus.active;

    final now = DateTime.now();
    final candidate = GpsPosition(
      localId: IdGenerator.generate(),
      missionId: missionId,
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      recordedAt: now,
      createdAt: now,
    );

    // Toujours refléter le dernier relevé à l'écran, même s'il n'est pas
    // conservé en base (imprécis ou déplacement négligeable) : l'agent voit
    // ainsi que le GPS fonctionne, pas seulement quand une ligne est ajoutée.
    lastPositionNotifier.value = candidate;

    if (candidate.accuracy != null && candidate.accuracy! > AppConfig.gpsAccuracyThresholdMeters) {
      return;
    }

    if (_lastStoredPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastStoredPosition!.latitude,
        _lastStoredPosition!.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      if (distance < AppConfig.gpsDistanceFilterMeters) return;
    }

    final id = await _gpsRepository.insert(candidate);
    final saved = candidate.copyWith(id: id);
    _lastStoredPosition = saved;
    await _enqueueCreate(saved);
  }

  /// Ajoute la position à la file de synchronisation (voir section 3 : les
  /// positions GPS font partie des données envoyées vers Laravel).
  Future<void> _enqueueCreate(GpsPosition position) {
    return _syncQueueRepository.addToQueue(
      entityTable: DatabaseTables.gpsPositions,
      entityLocalId: position.localId,
      operation: SyncOperation.create,
    );
  }

  Future<void> _requireMissionInProgress(int missionId) async {
    final mission = await _missionRepository.findById(missionId);
    if (mission == null || mission.statut != MissionStatus.inProgress) {
      throw const GpsException(
        'Impossible d\'enregistrer une position : la mission n\'est pas en cours.',
      );
    }
  }

  // --- Parcours d'une mission ---------------------------------------------

  /// Résumé du parcours d'une mission (nombre de positions, première/dernière,
  /// distance estimée), pour la section « Parcours » d'une mission terminée.
  Future<MissionTrackSummary> getMissionTrackSummary(int missionId) async {
    final positions = await _gpsRepository.findByMission(missionId);
    if (positions.isEmpty) {
      return const MissionTrackSummary(positionCount: 0);
    }

    var distance = 0.0;
    for (var i = 1; i < positions.length; i++) {
      distance += Geolocator.distanceBetween(
        positions[i - 1].latitude,
        positions[i - 1].longitude,
        positions[i].latitude,
        positions[i].longitude,
      );
    }

    return MissionTrackSummary(
      positionCount: positions.length,
      firstRecordedAt: positions.first.recordedAt,
      lastRecordedAt: positions.last.recordedAt,
      distanceMeters: distance,
    );
  }

  /// Parcours enregistrés par l'utilisateur, toutes missions confondues, du
  /// plus récent au plus ancien — pour l'écran « Mes parcours » (section 28).
  /// Ignore une éventuelle position orpheline (mission supprimée localement).
  Future<List<MissionTrack>> getMyTracks(int userId) async {
    final rows = await _gpsRepository.findTrackSummaryRowsByUser(userId);
    final tracks = <MissionTrack>[];
    for (final row in rows) {
      final mission = await _missionRepository.findById(row['mission_id'] as int);
      if (mission == null) continue;
      final summary = await getMissionTrackSummary(mission.id!);
      final pendingCount = (row['pending_count'] as int?) ?? 0;
      tracks.add(MissionTrack(mission: mission, summary: summary, hasPendingSync: pendingCount > 0));
    }
    return tracks;
  }
}
