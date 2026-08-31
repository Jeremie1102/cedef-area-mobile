import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/api/api_bootstrap_data.dart';
import 'package:cedef_area/models/api/api_cld.dart';
import 'package:cedef_area/models/api/api_groupement.dart';
import 'package:cedef_area/models/api/api_mission.dart';
import 'package:cedef_area/models/api/api_sector.dart';
import 'package:cedef_area/models/api/api_user.dart';
import 'package:cedef_area/models/api/api_village.dart';
import 'package:cedef_area/repositories/cld_repository.dart';
import 'package:cedef_area/repositories/groupement_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/secteur_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/repositories/village_repository.dart';
import 'package:cedef_area/services/downstream_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent [DownstreamSyncService] : persistance en SQLite d'une
/// réponse `/bootstrap` déjà récupérée (aucun réseau ici), hiérarchie
/// territoriale, tables pivot, réconciliation par `server_id`, idempotence,
/// et non-écrasement d'une donnée locale pas encore synchronisée (voir
/// `sync_service_test.dart` pour le moteur d'envoi).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final service = DownstreamSyncService();
  final secteurRepository = SecteurRepository();
  final groupementRepository = GroupementRepository();
  final cldRepository = CldRepository();
  final villageRepository = VillageRepository();
  final missionRepository = MissionRepository();
  final userRepository = UserRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_downstream_sync_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  const sector = ApiSector(id: 1, nom: 'Ngeba');
  const groupement = ApiGroupement(id: 10, nom: 'Groupement A', sector: sector);
  const cld = ApiCld(id: 100, nom: 'CLD Ngeba 001', groupement: groupement);
  const village = ApiVillage(id: 1000, nom: 'Kimpemba', cldId: 100);
  const user = ApiUser(
    id: 1,
    nom: 'Kabila',
    postnom: 'Mwamba',
    prenom: 'Jean',
    email: 'jean@example.com',
    fonction: 'animateur',
    actif: true,
  );
  const mission = ApiMission(
    id: 500,
    titre: 'Sensibilisation communautaire',
    statut: 'pending',
    dateDebutPrevue: '2026-01-01',
    dateFinPrevue: '2026-01-02',
    sector: sector,
    clds: [cld],
    villages: [village],
  );

  ApiBootstrapData buildBootstrap({ApiMission? withMission}) {
    return ApiBootstrapData(
      user: user,
      clds: const [cld],
      villages: const [village],
      missions: withMission != null ? [withMission] : const [],
    );
  }

  test('construit toute la hiérarchie territoriale avec les bons FK locaux', () async {
    final localUser = await service.applyBootstrap(buildBootstrap());

    final localSecteur = await secteurRepository.getByServerId(1);
    final localGroupement = await groupementRepository.getByServerId(10);
    final localCld = await cldRepository.getByServerId(100);
    final localVillage = await villageRepository.getByServerId(1000);

    expect(localSecteur, isNotNull);
    expect(localSecteur!.nom, 'Ngeba');
    expect(localGroupement, isNotNull);
    expect(localGroupement!.secteurId, localSecteur.id);
    expect(localCld, isNotNull);
    expect(localCld!.groupementId, localGroupement.id);
    expect(localVillage, isNotNull);
    expect(localVillage!.cldId, localCld.id);

    final myClds = await cldRepository.getByUser(localUser.id!);
    expect(myClds.map((c) => c.serverId), contains(100));
  });

  test('réconcilie l\'utilisateur par server_id sans jamais le dupliquer', () async {
    final first = await service.applyBootstrap(buildBootstrap());
    final second = await service.applyBootstrap(buildBootstrap());

    expect(second.id, first.id);
    expect(await userRepository.findAll(), hasLength(1));
  });

  test('associe une mission à ses CLD et à l\'utilisateur courant', () async {
    final localUser = await service.applyBootstrap(buildBootstrap(withMission: mission));

    final localMission = await missionRepository.getByServerId(500);
    expect(localMission, isNotNull);
    expect(localMission!.titre, 'Sensibilisation communautaire');
    expect(localMission.statut, MissionStatus.pending);

    final assignments = await missionRepository.findAssignments(localMission.id!);
    expect(assignments.map((a) => a.userId), contains(localUser.id));

    final missionClds = await missionRepository.findMissionClds(localMission.id!);
    final localCld = await cldRepository.getByServerId(100);
    expect(missionClds.map((mc) => mc.cldId), contains(localCld!.id));
  });

  test('rejouer applyBootstrap deux fois de suite est idempotent', () async {
    await service.applyBootstrap(buildBootstrap(withMission: mission));
    await service.applyBootstrap(buildBootstrap(withMission: mission));

    expect(await secteurRepository.getAll(), hasLength(1));
    expect(await groupementRepository.getAll(), hasLength(1));
    expect(await cldRepository.getAll(), hasLength(1));
    expect(await villageRepository.getAll(), hasLength(1));
    expect(await missionRepository.findAll(), hasLength(1));

    final localMission = await missionRepository.getByServerId(500);
    expect(await missionRepository.findAssignments(localMission!.id!), hasLength(1));
    expect(await missionRepository.findMissionClds(localMission.id!), hasLength(1));
  });

  test(
    'une mission locale pas encore synchronisée n\'est jamais écrasée par un nouveau téléchargement',
    () async {
      await service.applyBootstrap(buildBootstrap(withMission: mission));
      final downloaded = await missionRepository.getByServerId(500);

      // Simule une progression hors ligne : l'agent démarre la mission,
      // l'envoi au serveur n'a pas encore eu lieu.
      final startedLocally = downloaded!.copyWith(
        statut: MissionStatus.inProgress,
        startedAt: DateTime(2026, 1, 1, 8),
        syncStatus: SyncStatus.pending,
      );
      await missionRepository.update(startedLocally);

      // Nouveau téléchargement : le serveur renvoie toujours "pending" (il
      // n'a pas encore reçu l'événement de démarrage).
      await service.applyBootstrap(buildBootstrap(withMission: mission));

      final afterSecondDownload = await missionRepository.getByServerId(500);
      expect(afterSecondDownload!.statut, MissionStatus.inProgress);
      expect(afterSecondDownload.syncStatus, SyncStatus.pending);
      expect(afterSecondDownload.startedAt, isNotNull);

      // Les tables pivot, elles, ne posent pas de problème de conflit et
      // restent à jour.
      final missionClds = await missionRepository.findMissionClds(afterSecondDownload.id!);
      expect(missionClds, isNotEmpty);
    },
  );
}
