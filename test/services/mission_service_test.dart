import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/mission.dart';
import 'package:cedef_area/models/mission_user.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/database/database_tables.dart';
import 'package:cedef_area/repositories/gps_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/sync_queue_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/services/gps_service.dart';
import 'package:cedef_area/services/mission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent le cycle de vie d'une mission ([MissionService]) :
/// démarrage, pause, reprise, fin, et les transitions interdites (voir
/// `MissionRepository` pour l'accès aux données pures, et
/// `test/services/gps_service_test.dart` pour le suivi GPS lui-même).
///
/// `MissionService` orchestre aussi `GpsService` : on lui injecte ici une
/// instance isolée avec des positions simulées (jamais le `GpsService.instance`
/// partagé, ni de vrai `Geolocator`), pour que ces tests restent rapides,
/// indépendants les uns des autres et d'un GPS physique.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MissionRepository missionRepository;
  late MissionService missionService;
  late GpsService gpsService;
  late UserRepository userRepository;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_mission_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    missionRepository = MissionRepository();
    userRepository = UserRepository();
    gpsService = GpsService(
      gpsRepository: GpsRepository(),
      missionRepository: missionRepository,
      permissionChecker: () async => true,
      positionProvider: () async => Position(
        latitude: -4.3276,
        longitude: 15.3136,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    missionService = MissionService(missionRepository: missionRepository, gpsService: gpsService);
  });

  tearDown(() async {
    // Le suivi GPS démarré par certains tests utilise un `Timer.periodic` :
    // on l'arrête explicitement pour ne pas le laisser actif au-delà du test.
    await gpsService.stopTracking();
    // `startTracking`/`resumeTracking` déclenchent aussi un premier relevé de
    // façon asynchrone (`unawaited`) : on laisse ce travail en arrière-plan
    // se terminer avant que le `setUp` suivant ne supprime la base.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });

  Future<int> insertUser() async {
    final now = DateTime.now();
    return userRepository.insert(
      User(
        localId: IdGenerator.generate(),
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        passwordHash: 'x',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> insertMission({MissionStatus statut = MissionStatus.pending, int? userId}) async {
    final now = DateTime.now();
    final missionId = await missionRepository.insert(
      Mission(
        localId: IdGenerator.generate(),
        titre: 'Sensibilisation communautaire',
        statut: statut,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (userId != null) {
      await missionRepository.assignUser(
        MissionUser(
          localId: IdGenerator.generate(),
          missionId: missionId,
          userId: userId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return missionId;
  }

  test('démarre une mission en attente et active le suivi GPS', () async {
    final userId = await insertUser();
    final missionId = await insertMission();

    final mission = await missionService.startMission(missionId, userId: userId);

    expect(mission.statut, MissionStatus.inProgress);
    expect(mission.startedAt, isNotNull);
    expect(gpsService.isTracking, isTrue);
  });

  test('met en pause une mission en cours et arrête le suivi GPS', () async {
    final userId = await insertUser();
    final missionId = await insertMission(statut: MissionStatus.pending, userId: userId);
    await missionService.startMission(missionId, userId: userId);

    final mission = await missionService.pauseMission(missionId);

    expect(mission.statut, MissionStatus.paused);
    expect(mission.pausedAt, isNotNull);
    expect(gpsService.isTracking, isFalse);
  });

  test('reprend une mission en pause et relance le suivi GPS', () async {
    final userId = await insertUser();
    final missionId = await insertMission(statut: MissionStatus.pending, userId: userId);
    await missionService.startMission(missionId, userId: userId);
    await missionService.pauseMission(missionId);

    final mission = await missionService.resumeMission(missionId, userId: userId);

    expect(mission.statut, MissionStatus.inProgress);
    expect(mission.resumedAt, isNotNull);
    expect(gpsService.isTracking, isTrue);
  });

  test('termine une mission en cours avec une observation et arrête le GPS', () async {
    final userId = await insertUser();
    final missionId = await insertMission(statut: MissionStatus.pending, userId: userId);
    await missionService.startMission(missionId, userId: userId);

    final mission = await missionService.completeMission(missionId, observation: 'Aucun incident.');

    expect(mission.statut, MissionStatus.completed);
    expect(mission.endedAt, isNotNull);
    expect(mission.endObservation, 'Aucun incident.');
    expect(gpsService.isTracking, isFalse);
  });

  test('termine aussi une mission en pause', () async {
    final missionId = await insertMission(statut: MissionStatus.paused);

    final mission = await missionService.completeMission(missionId);

    expect(mission.statut, MissionStatus.completed);
  });

  test('récupère la mission active de l\'utilisateur', () async {
    final userId = await insertUser();
    await insertMission(statut: MissionStatus.pending, userId: userId);
    final activeId = await insertMission(statut: MissionStatus.inProgress, userId: userId);

    final active = await missionService.getActiveMission(userId);

    expect(active, isNotNull);
    expect(active!.id, activeId);
  });

  test('aucune mission active tant qu\'aucune n\'est démarrée', () async {
    final userId = await insertUser();
    await insertMission(statut: MissionStatus.pending, userId: userId);

    final active = await missionService.getActiveMission(userId);

    expect(active, isNull);
  });

  test('impossible de démarrer une mission déjà terminée', () async {
    final userId = await insertUser();
    final missionId = await insertMission(statut: MissionStatus.completed);

    expect(
      () => missionService.startMission(missionId, userId: userId),
      throwsA(isA<ValidationException>()),
    );
  });

  test('impossible de démarrer une mission annulée', () async {
    final userId = await insertUser();
    final missionId = await insertMission(statut: MissionStatus.cancelled);

    expect(
      () => missionService.startMission(missionId, userId: userId),
      throwsA(isA<ValidationException>()),
    );
  });

  test('impossible de mettre en pause une mission qui n\'est pas en cours', () async {
    final missionId = await insertMission();

    expect(() => missionService.pauseMission(missionId), throwsA(isA<ValidationException>()));
  });

  test('impossible de terminer une mission jamais démarrée', () async {
    final missionId = await insertMission();

    expect(() => missionService.completeMission(missionId), throwsA(isA<ValidationException>()));
  });

  test('les changements de statut sont conservés hors ligne (persistés en base)', () async {
    final userId = await insertUser();
    final missionId = await insertMission(statut: MissionStatus.pending, userId: userId);

    await missionService.startMission(missionId, userId: userId);
    await missionService.pauseMission(missionId);

    // Simule la fermeture puis la réouverture de l'application : un nouveau
    // repository relit directement la base SQLite sur disque, sans passer
    // par un état en mémoire.
    final reloaded = await MissionRepository().findById(missionId);

    expect(reloaded, isNotNull);
    expect(reloaded!.statut, MissionStatus.paused);
    expect(reloaded.startedAt, isNotNull);
    expect(reloaded.pausedAt, isNotNull);
    expect(reloaded.syncStatus, SyncStatus.pending);
  });

  test('relance le suivi GPS d\'une mission déjà en cours après une relance de l\'app', () async {
    final userId = await insertUser();
    await insertMission(statut: MissionStatus.inProgress, userId: userId);

    // `gpsService` est fraîchement créé (comme après un redémarrage du
    // processus) : aucun suivi n'est actif avant l'appel.
    expect(gpsService.isTracking, isFalse);

    await missionService.resumeTrackingForActiveMission(userId);

    expect(gpsService.isTracking, isTrue);
  });

  test('ne relance rien s\'il n\'y a aucune mission active', () async {
    final userId = await insertUser();
    await insertMission(statut: MissionStatus.pending, userId: userId);

    await missionService.resumeTrackingForActiveMission(userId);

    expect(gpsService.isTracking, isFalse);
  });

  group('file de synchronisation', () {
    final syncQueueRepository = SyncQueueRepository();

    test('démarrer/mettre en pause/reprendre/terminer ajoutent chacun un événement distinct', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.pending, userId: userId);

      await missionService.startMission(missionId, userId: userId);
      await missionService.pauseMission(missionId);
      await missionService.resumeMission(missionId, userId: userId);
      await missionService.completeMission(missionId, observation: 'RAS');

      final pending = await syncQueueRepository.getPendingItems();
      final missionEvents = pending.where((e) => e.entityTable == DatabaseTables.missions).toList();

      expect(missionEvents.map((e) => e.operation), [
        SyncOperation.start,
        SyncOperation.pause,
        SyncOperation.resume,
        SyncOperation.complete,
      ]);
      expect(missionEvents.last.payload?['observation'], 'RAS');
    });
  });
}
