import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/cld.dart';
import 'package:cedef_area/models/groupement.dart';
import 'package:cedef_area/models/mission.dart';
import 'package:cedef_area/models/mission_cld.dart';
import 'package:cedef_area/models/mission_user.dart';
import 'package:cedef_area/models/secteur.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/models/village.dart';
import 'package:cedef_area/repositories/cld_repository.dart';
import 'package:cedef_area/repositories/groupement_repository.dart';
import 'package:cedef_area/repositories/mission_repository.dart';
import 'package:cedef_area/repositories/secteur_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/repositories/village_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent [MissionRepository] (missions, agents affectés et CLD
/// concernés) au-dessus d'une vraie base SQLite via `sqflite_common_ffi`
/// (voir `auth_service_test.dart` pour le principe).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final missionRepository = MissionRepository();
  final userRepository = UserRepository();
  final secteurRepository = SecteurRepository();
  final groupementRepository = GroupementRepository();
  final cldRepository = CldRepository();
  final villageRepository = VillageRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_mission_repository.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  Future<int> insertUser(String nom) async {
    final now = DateTime.now();
    return userRepository.insert(
      User(
        localId: IdGenerator.generate(),
        nom: nom,
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        passwordHash: 'x',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Insère Ngeba > Groupement A > CLD Ngeba 001 > (Kimpemba, Mbanza) et
  /// retourne les identifiants créés.
  Future<(int secteurId, int cldId, List<int> villageIds)> insertTerritory() async {
    final now = DateTime.now();
    final secteurId = await secteurRepository.insert(
      Secteur(localId: IdGenerator.generate(), nom: 'Ngeba', createdAt: now, updatedAt: now),
    );
    final groupementId = await groupementRepository.insert(
      Groupement(
        localId: IdGenerator.generate(),
        secteurId: secteurId,
        nom: 'Groupement A',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final cldId = await cldRepository.insert(
      Cld(
        localId: IdGenerator.generate(),
        groupementId: groupementId,
        nom: 'CLD Ngeba 001',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final villageA = await villageRepository.insert(
      Village(localId: IdGenerator.generate(), cldId: cldId, nom: 'Kimpemba', createdAt: now, updatedAt: now),
    );
    final villageB = await villageRepository.insert(
      Village(localId: IdGenerator.generate(), cldId: cldId, nom: 'Mbanza', createdAt: now, updatedAt: now),
    );
    return (secteurId, cldId, [villageA, villageB]);
  }

  Future<int> insertMission({
    required String titre,
    int? secteurId,
    MissionStatus statut = MissionStatus.pending,
  }) async {
    final now = DateTime.now();
    return missionRepository.insert(
      Mission(
        localId: IdGenerator.generate(),
        titre: titre,
        secteurId: secteurId,
        statut: statut,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> assignUser(int missionId, int userId) async {
    final now = DateTime.now();
    await missionRepository.assignUser(
      MissionUser(localId: IdGenerator.generate(), missionId: missionId, userId: userId, createdAt: now, updatedAt: now),
    );
  }

  Future<void> assignCld(int missionId, int cldId) async {
    final now = DateTime.now();
    await missionRepository.assignCld(
      MissionCld(localId: IdGenerator.generate(), missionId: missionId, cldId: cldId, createdAt: now, updatedAt: now),
    );
  }

  test('récupère toutes les missions', () async {
    await insertMission(titre: 'Mission A');
    await insertMission(titre: 'Mission B');

    final missions = await missionRepository.findAll();
    expect(missions, hasLength(2));
  });

  test('filtre les missions selon l\'utilisateur assigné', () async {
    final animateur = await insertUser('Kabila');
    final autreAnimateur = await insertUser('Tshisekedi');

    final missionId = await insertMission(titre: 'Sensibilisation communautaire');
    await assignUser(missionId, animateur);

    final ownMissions = await missionRepository.findByUser(animateur);
    final otherMissions = await missionRepository.findByUser(autreAnimateur);

    expect(ownMissions, hasLength(1));
    expect(ownMissions.first.titre, 'Sensibilisation communautaire');
    expect(otherMissions, isEmpty);
  });

  test('récupère une mission par id', () async {
    final missionId = await insertMission(titre: 'Suivi des travaux');

    final mission = await missionRepository.findById(missionId);

    expect(mission, isNotNull);
    expect(mission!.titre, 'Suivi des travaux');
    expect(mission.statut, MissionStatus.pending);
  });

  test('les CLD et villages concernés se déduisent de mission_clds', () async {
    final (secteurId, cldId, villageIds) = await insertTerritory();
    final missionId = await insertMission(titre: 'Sensibilisation communautaire', secteurId: secteurId);
    await assignCld(missionId, cldId);

    final clds = await missionRepository.getCldsForMission(missionId);
    final villages = await missionRepository.getVillagesForMission(missionId);

    expect(clds, hasLength(1));
    expect(clds.first.nom, 'CLD Ngeba 001');
    expect(villages.map((v) => v.id), containsAll(villageIds));
  });

  test('les résumés de missions exposent le secteur et les CLD concernés', () async {
    final animateur = await insertUser('Kabila');
    final (secteurId, cldId, _) = await insertTerritory();
    final missionId = await insertMission(titre: 'Sensibilisation communautaire', secteurId: secteurId);
    await assignUser(missionId, animateur);
    await assignCld(missionId, cldId);

    final summaries = await missionRepository.getSummariesByUser(animateur);

    expect(summaries, hasLength(1));
    expect(summaries.first.secteurName, 'Ngeba');
    expect(summaries.first.cldNames, ['CLD Ngeba 001']);
  });

  test('la mission active est celle en cours ou en pause pour l\'utilisateur', () async {
    final animateur = await insertUser('Kabila');
    final pendingId = await insertMission(titre: 'À faire', statut: MissionStatus.pending);
    final activeId = await insertMission(titre: 'En cours', statut: MissionStatus.inProgress);
    await assignUser(pendingId, animateur);
    await assignUser(activeId, animateur);

    final active = await missionRepository.getActiveMissionForUser(animateur);

    expect(active, isNotNull);
    expect(active!.id, activeId);
  });

  test('aucune mission active si rien n\'est en cours', () async {
    final animateur = await insertUser('Kabila');
    final missionId = await insertMission(titre: 'À faire');
    await assignUser(missionId, animateur);

    final active = await missionRepository.getActiveMissionForUser(animateur);

    expect(active, isNull);
  });
}
