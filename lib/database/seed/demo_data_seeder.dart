import '../../core/constants/app_constants.dart';
import '../../core/utils/id_generator.dart';
import '../../models/cld.dart';
import '../../models/groupement.dart';
import '../../models/mission.dart';
import '../../models/mission_cld.dart';
import '../../models/mission_user.dart';
import '../../models/secteur.dart';
import '../../models/village.dart';
import '../../repositories/cld_repository.dart';
import '../../repositories/groupement_repository.dart';
import '../../repositories/mission_repository.dart';
import '../../repositories/secteur_repository.dart';
import '../../repositories/village_repository.dart';

/// Insère une petite hiérarchie territoriale de démonstration
/// (Secteur > Groupement > CLD > Village), afin de pouvoir tester
/// l'application sans attendre la synchronisation avec Laravel.
///
/// Ces données simulent ce que l'API Laravel enverra plus tard : elles ne
/// sont PAS créées par l'animateur (l'application mobile ne propose aucun
/// écran de création de secteur/groupement/CLD/village), mais insérées
/// directement en base pour représenter un import déjà effectué. Elles sont
/// clairement identifiées via leur `description` et ne sont insérées que si
/// la table `secteurs` est vide, pour ne jamais se mélanger avec de vraies
/// données synchronisées. Supprimer cet appel (ou ce fichier) désactive
/// entièrement le mécanisme.
class DemoDataSeeder {
  DemoDataSeeder._();

  static const String _demoLabel = 'Donnée de démonstration (simulée depuis Laravel)';

  static Future<void> seedIfEmpty() async {
    final secteurRepository = SecteurRepository();
    final groupementRepository = GroupementRepository();
    final cldRepository = CldRepository();
    final villageRepository = VillageRepository();

    final existing = await secteurRepository.getAll();
    if (existing.isNotEmpty) return;

    final ngeba = await _insertSecteur(secteurRepository, nom: 'Ngeba', code: 'NGEBA');

    final groupementA = await _insertGroupement(
      groupementRepository,
      secteurId: ngeba,
      nom: 'Groupement A',
    );
    final cld001 = await _insertCld(cldRepository, groupementId: groupementA, nom: 'CLD Ngeba 001');
    await _insertVillage(villageRepository, cldId: cld001, nom: 'Kimpemba');
    await _insertVillage(villageRepository, cldId: cld001, nom: 'Mbanza');
    await _insertVillage(villageRepository, cldId: cld001, nom: 'Nkondo');

    final groupementB = await _insertGroupement(
      groupementRepository,
      secteurId: ngeba,
      nom: 'Groupement B',
    );
    final cld005 = await _insertCld(cldRepository, groupementId: groupementB, nom: 'CLD Ngeba 005');
    await _insertVillage(villageRepository, cldId: cld005, nom: 'Village A');
    await _insertVillage(villageRepository, cldId: cld005, nom: 'Village B');

    final ngufu = await _insertSecteur(secteurRepository, nom: 'Ngufu', code: 'NGUFU');
    final groupementC = await _insertGroupement(
      groupementRepository,
      secteurId: ngufu,
      nom: 'Groupement C',
    );
    final cld003 = await _insertCld(cldRepository, groupementId: groupementC, nom: 'CLD Ngufu 003');
    await _insertVillage(villageRepository, cldId: cld003, nom: 'Kimvula');
  }

  static Future<int> _insertSecteur(
    SecteurRepository repository, {
    required String nom,
    required String code,
  }) async {
    final now = DateTime.now();
    return repository.insert(
      Secteur(
        localId: IdGenerator.generate(),
        nom: nom,
        code: code,
        description: _demoLabel,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  static Future<int> _insertGroupement(
    GroupementRepository repository, {
    required int secteurId,
    required String nom,
  }) async {
    final now = DateTime.now();
    return repository.insert(
      Groupement(
        localId: IdGenerator.generate(),
        secteurId: secteurId,
        nom: nom,
        description: _demoLabel,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  static Future<int> _insertCld(
    CldRepository repository, {
    required int groupementId,
    required String nom,
  }) async {
    final now = DateTime.now();
    return repository.insert(
      Cld(
        localId: IdGenerator.generate(),
        groupementId: groupementId,
        nom: nom,
        description: _demoLabel,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  static Future<int> _insertVillage(
    VillageRepository repository, {
    required int cldId,
    required String nom,
  }) async {
    final now = DateTime.now();
    return repository.insert(
      Village(
        localId: IdGenerator.generate(),
        cldId: cldId,
        nom: nom,
        description: _demoLabel,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // --- Missions -----------------------------------------------------------
  //
  // Simule quelques missions déjà attribuées par l'Assistant Technique
  // (créées et affectées depuis Laravel, à venir) afin de pouvoir tester le
  // module Missions sans backend. Comme pour la hiérarchie territoriale,
  // n'insère rien si des missions existent déjà, et s'appuie sur le jeu de
  // données de démonstration territoriales (le crée si nécessaire).
  static Future<void> seedMissionsIfEmpty(int userId) async {
    final missionRepository = MissionRepository();
    if ((await missionRepository.findAll()).isNotEmpty) return;

    await seedIfEmpty();

    final secteurRepository = SecteurRepository();
    final cldRepository = CldRepository();
    final secteurs = await secteurRepository.getAll();
    final clds = await cldRepository.getAll();

    int? secteurIdByName(String nom) =>
        secteurs.where((s) => s.nom == nom).map((s) => s.id).firstOrNull;
    int? cldIdByName(String nom) => clds.where((c) => c.nom == nom).map((c) => c.id).firstOrNull;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await _insertMission(
      missionRepository,
      userId: userId,
      titre: 'Sensibilisation communautaire',
      instructions:
          'Organiser les séances de sensibilisation dans les villages concernés et documenter '
          'les activités réalisées.',
      dateDebut: today,
      dateFin: today.add(const Duration(days: 2)),
      secteurId: secteurIdByName('Ngeba'),
      cldId: cldIdByName('CLD Ngeba 001'),
      statut: MissionStatus.pending,
    );

    await _insertMission(
      missionRepository,
      userId: userId,
      titre: 'Identification de terrain',
      instructions:
          'Identifier les nouvelles étendues à cartographier et relever les coordonnées GPS '
          'des points clés.',
      dateDebut: today.subtract(const Duration(days: 1)),
      dateFin: today,
      secteurId: secteurIdByName('Ngeba'),
      cldId: cldIdByName('CLD Ngeba 005'),
      statut: MissionStatus.inProgress,
      startedAt: now.subtract(const Duration(hours: 3)),
    );

    await _insertMission(
      missionRepository,
      userId: userId,
      titre: 'Suivi des travaux de pépinière',
      instructions: 'Vérifier l\'état d\'avancement de la pépinière et consigner les besoins en '
          'matériel.',
      dateDebut: today.add(const Duration(days: 3)),
      dateFin: today.add(const Duration(days: 4)),
      secteurId: secteurIdByName('Ngufu'),
      cldId: cldIdByName('CLD Ngufu 003'),
      statut: MissionStatus.pending,
    );

    await _insertMission(
      missionRepository,
      userId: userId,
      titre: 'Identification des étendues',
      instructions: 'Repérer les nouvelles étendues plantées et vérifier leur conformité.',
      dateDebut: today.subtract(const Duration(days: 6)),
      dateFin: today.subtract(const Duration(days: 6)),
      statut: MissionStatus.completed,
      startedAt: today.subtract(const Duration(days: 6)).add(const Duration(hours: 8)),
      endedAt: today.subtract(const Duration(days: 6)).add(const Duration(hours: 16)),
      endObservation: 'Mission réalisée sans incident.',
    );
  }

  static Future<void> _insertMission(
    MissionRepository repository, {
    required int userId,
    required String titre,
    required String instructions,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? secteurId,
    int? cldId,
    MissionStatus statut = MissionStatus.pending,
    DateTime? startedAt,
    DateTime? endedAt,
    String? endObservation,
  }) async {
    final now = DateTime.now();
    final missionId = await repository.insert(
      Mission(
        localId: IdGenerator.generate(),
        titre: titre,
        description: _demoLabel,
        instructions: instructions,
        dateDebut: dateDebut,
        dateFin: dateFin,
        secteurId: secteurId,
        statut: statut,
        startedAt: startedAt,
        endedAt: endedAt,
        endObservation: endObservation,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.assignUser(
      MissionUser(localId: IdGenerator.generate(), missionId: missionId, userId: userId, createdAt: now, updatedAt: now),
    );

    if (cldId != null) {
      await repository.assignCld(
        MissionCld(
          localId: IdGenerator.generate(),
          missionId: missionId,
          cldId: cldId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
