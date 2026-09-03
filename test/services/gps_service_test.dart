import 'package:cedef_area/config/app_config.dart';
import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/gps_position.dart';
import 'package:cedef_area/models/mission.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/database/database_tables.dart';
import 'package:cedef_area/repositories/gps_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/sync_queue_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/services/gps_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent [GpsService] : démarrage/pause/reprise/arrêt du suivi
/// périodique, filtres de précision et de distance, et l'interdiction
/// d'enregistrer une position pour une mission qui n'est pas `in_progress`.
///
/// Aucun test ne dépend d'un GPS physique ou d'un plugin natif : les positions
/// et les permissions sont simulées via les points d'injection
/// `positionProvider`/`permissionChecker` de [GpsService] (voir sa
/// documentation). Le minuteur périodique de `startTracking` déclenche son
/// premier relevé de façon asynchrone (`unawaited`, pour ne jamais bloquer
/// l'écran le temps d'un relevé GPS) : les tests qui en dépendent laissent
/// donc s'écouler un court délai avant de vérifier la base.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late GpsRepository gpsRepository;
  late MissionRepository missionRepository;
  late UserRepository userRepository;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_gps_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    gpsRepository = GpsRepository();
    missionRepository = MissionRepository();
    userRepository = UserRepository();
  });

  tearDown(() async {
    // `startTracking`/`resumeTracking` déclenchent leur premier relevé de
    // façon asynchrone (`unawaited`, voir `GpsService._armTimer`) pour ne
    // jamais bloquer l'appelant le temps d'un relevé GPS : on laisse ce
    // travail en arrière-plan se terminer avant que le `setUp` suivant ne
    // supprime la base, sans quoi l'insertion échoue sur une base déjà
    // fermée une fois le test suivant démarré.
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

  Future<int> insertMission({MissionStatus statut = MissionStatus.inProgress}) async {
    final now = DateTime.now();
    return missionRepository.insert(
      Mission(
        localId: IdGenerator.generate(),
        titre: 'Sensibilisation communautaire',
        statut: statut,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Position fakePosition({double accuracy = 10, double latitude = -4.3276, double longitude = 15.3136}) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  GpsService buildService({
    bool permissionGranted = true,
    Position Function()? position,
  }) {
    return GpsService(
      gpsRepository: gpsRepository,
      missionRepository: missionRepository,
      permissionChecker: () async => permissionGranted,
      positionProvider: () async => (position ?? fakePosition)(),
    );
  }

  group('recordPosition (relevé manuel)', () {
    test('enregistre une position pour une mission en cours', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();

      final saved = await service.recordPosition(missionId: missionId, userId: userId);

      expect(saved.id, isNotNull);
      expect(saved.missionId, missionId);
      final stored = await gpsRepository.findByMission(missionId);
      expect(stored, hasLength(1));
    });

    test('ajoute la position à la file de synchronisation', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();

      final saved = await service.recordPosition(missionId: missionId, userId: userId);

      final pending = await SyncQueueRepository().getPendingItems();
      final gpsEntries = pending.where((e) => e.entityTable == DatabaseTables.gpsPositions);
      expect(gpsEntries, hasLength(1));
      expect(gpsEntries.first.entityLocalId, saved.localId);
      expect(gpsEntries.first.operation, SyncOperation.create);
    });

    test('refuse d\'enregistrer une position pour une mission en attente', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.pending);
      final service = buildService();

      expect(
        () => service.recordPosition(missionId: missionId, userId: userId),
        throwsA(isA<GpsException>()),
      );
    });

    test('refuse d\'enregistrer une position pour une mission en pause', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.paused);
      final service = buildService();

      expect(
        () => service.recordPosition(missionId: missionId, userId: userId),
        throwsA(isA<GpsException>()),
      );
    });

    test('refuse d\'enregistrer une position pour une mission terminée', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.completed);
      final service = buildService();

      expect(
        () => service.recordPosition(missionId: missionId, userId: userId),
        throwsA(isA<GpsException>()),
      );
    });

    test('enregistre une position avec l\'ensemble des métadonnées terrain réelles', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService(
        position: () => Position(
          latitude: -4.3276,
          longitude: 15.3136,
          timestamp: DateTime.now(),
          accuracy: 8.5,
          altitude: 350.0,
          altitudeAccuracy: 1.0,
          heading: 180.0,
          headingAccuracy: 5.0,
          speed: 1.2,
          speedAccuracy: 0.2,
        ),
      );

      final saved = await service.recordPosition(missionId: missionId, userId: userId);

      expect(saved.latitude, -4.3276);
      expect(saved.longitude, 15.3136);
      expect(saved.accuracy, 8.5);
      expect(saved.altitude, 350.0);
      expect(saved.heading, 180.0);
      expect(saved.speed, 1.2);
      expect(saved.syncStatus, SyncStatus.pending);
      expect(saved.localId, isNotEmpty);
    });

    test('refuse d\'enregistrer une position sans autorisation de localisation', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService(permissionGranted: false);

      expect(
        () => service.recordPosition(missionId: missionId, userId: userId),
        throwsA(isA<GpsException>()),
      );
    });
  });

  group('suivi périodique (startTracking / pauseTracking / resumeTracking / stopTracking)', () {
    test('startTracking active le suivi et enregistre un premier relevé', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();

      await service.startTracking(missionId: missionId, userId: userId);
      expect(service.isTracking, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final stored = await gpsRepository.findByMission(missionId);
      expect(stored, hasLength(1));
      expect(service.statusNotifier.value, GpsTrackingStatus.active);
    });

    test('pauseTracking arrête le minuteur sans oublier la mission suivie', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();
      await service.startTracking(missionId: missionId, userId: userId);

      service.pauseTracking();

      expect(service.isTracking, isFalse);
      expect(service.statusNotifier.value, GpsTrackingStatus.idle);
    });

    test('resumeTracking relance le suivi après une pause', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();
      await service.startTracking(missionId: missionId, userId: userId);
      service.pauseTracking();

      final resumed = await service.resumeTracking();

      expect(resumed, isTrue);
      expect(service.isTracking, isTrue);
    });

    test('resumeTracking échoue s\'il n\'y a aucune mission en mémoire', () async {
      final service = buildService();

      final resumed = await service.resumeTracking();

      expect(resumed, isFalse);
      expect(service.isTracking, isFalse);
    });

    test('stopTracking arrête le suivi et efface la dernière position affichée', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();
      await service.startTracking(missionId: missionId, userId: userId);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await service.stopTracking();

      expect(service.isTracking, isFalse);
      expect(service.statusNotifier.value, GpsTrackingStatus.idle);
      expect(service.lastPositionNotifier.value, isNull);
    });

    test('plus aucune position n\'est enregistrée une fois la mission terminée', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService();
      await service.startTracking(missionId: missionId, userId: userId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final countBefore = (await gpsRepository.findByMission(missionId)).length;

      // Simule la fin de la mission sans passer par stopTracking (le
      // minuteur continue de tourner un court instant) : le prochain relevé
      // doit être rejeté par le garde-fou de `_captureOnce`.
      final mission = await missionRepository.findById(missionId);
      await missionRepository.update(mission!.copyWith(statut: MissionStatus.completed));

      final direct = service.recordPosition(missionId: missionId, userId: userId);
      await expectLater(direct, throwsA(isA<GpsException>()));

      final countAfter = (await gpsRepository.findByMission(missionId)).length;
      expect(countAfter, countBefore);
    });
  });

  group('filtres de précision et de distance', () {
    test('un relevé trop imprécis n\'est pas conservé mais reste affiché', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final service = buildService(
        position: () => fakePosition(accuracy: AppConfig.gpsAccuracyThresholdMeters + 100),
      );

      await service.startTracking(missionId: missionId, userId: userId);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stored = await gpsRepository.findByMission(missionId);
      expect(stored, isEmpty);
      expect(service.lastPositionNotifier.value, isNotNull);
    });

    test('un déplacement négligeable depuis la dernière position n\'est pas conservé', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.inProgress);
      final now = DateTime.now();
      await gpsRepository.insert(
        GpsPosition(
          localId: IdGenerator.generate(),
          missionId: missionId,
          userId: userId,
          latitude: -4.3276,
          longitude: 15.3136,
          accuracy: 10,
          recordedAt: now,
          createdAt: now,
        ),
      );
      final service = buildService(position: () => fakePosition(latitude: -4.32761, longitude: 15.31361));

      await service.startTracking(missionId: missionId, userId: userId);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stored = await gpsRepository.findByMission(missionId);
      expect(stored, hasLength(1)); // toujours la position pré-existante, aucune ajoutée
    });
  });

  group('parcours d\'une mission (getMissionTrackSummary)', () {
    test('calcule le nombre de positions, les bornes et une distance estimée', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.completed);
      final start = DateTime(2026, 8, 20, 8, 0);
      final end = DateTime(2026, 8, 20, 8, 30);

      await gpsRepository.insert(
        GpsPosition(
          localId: IdGenerator.generate(),
          missionId: missionId,
          userId: userId,
          latitude: -4.3276,
          longitude: 15.3136,
          recordedAt: start,
          createdAt: start,
        ),
      );
      await gpsRepository.insert(
        GpsPosition(
          localId: IdGenerator.generate(),
          missionId: missionId,
          userId: userId,
          latitude: -4.3376, // ~1.1 km plus au sud
          longitude: 15.3136,
          recordedAt: end,
          createdAt: end,
        ),
      );

      final service = buildService();
      final summary = await service.getMissionTrackSummary(missionId);

      expect(summary.positionCount, 2);
      expect(summary.firstRecordedAt, start);
      expect(summary.lastRecordedAt, end);
      expect(summary.distanceMeters, isNotNull);
      expect(summary.distanceMeters!, greaterThan(1000));
      expect(summary.distanceMeters!, lessThan(1200));
    });

    test('aucun résumé si la mission n\'a aucune position', () async {
      final missionId = await insertMission(statut: MissionStatus.completed);
      final service = buildService();

      final summary = await service.getMissionTrackSummary(missionId);

      expect(summary.positionCount, 0);
      expect(summary.firstRecordedAt, isNull);
      expect(summary.distanceMeters, isNull);
    });
  });

  group('getMyTracks (écran « Mes parcours »)', () {
    test('un parcours par mission ayant des positions, du plus récent au plus ancien', () async {
      final userId = await insertUser();
      final missionA = await insertMission(statut: MissionStatus.completed);
      final missionB = await insertMission(statut: MissionStatus.completed);
      final now = DateTime.now();
      final service = buildService();

      await gpsRepository.insert(
        GpsPosition(
          localId: IdGenerator.generate(),
          missionId: missionA,
          userId: userId,
          latitude: -4.3276,
          longitude: 15.3136,
          recordedAt: now.subtract(const Duration(days: 1)),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      );
      await gpsRepository.insert(
        GpsPosition(
          localId: IdGenerator.generate(),
          missionId: missionB,
          userId: userId,
          latitude: -4.33,
          longitude: 15.32,
          recordedAt: now,
          createdAt: now,
        ),
      );

      final tracks = await service.getMyTracks(userId);

      expect(tracks, hasLength(2));
      expect(tracks.first.mission.id, missionB);
      expect(tracks.last.mission.id, missionA);
    });

    test('signale un parcours comme en attente tant qu\'une position n\'est pas synchronisée', () async {
      final userId = await insertUser();
      final missionId = await insertMission(statut: MissionStatus.completed);
      final now = DateTime.now();
      final service = buildService();

      await gpsRepository.insert(
        GpsPosition(
          localId: IdGenerator.generate(),
          missionId: missionId,
          userId: userId,
          latitude: -4.3276,
          longitude: 15.3136,
          recordedAt: now,
          syncStatus: SyncStatus.pending,
          createdAt: now,
        ),
      );

      final tracks = await service.getMyTracks(userId);

      expect(tracks, hasLength(1));
      expect(tracks.first.hasPendingSync, isTrue);
    });

    test('aucun parcours si l\'utilisateur n\'a aucune position enregistrée', () async {
      final userId = await insertUser();
      final service = buildService();

      final tracks = await service.getMyTracks(userId);

      expect(tracks, isEmpty);
    });
  });
}
