import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/utils/id_generator.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/models/cld.dart';
import 'package:cedef_area/models/groupement.dart';
import 'package:cedef_area/models/secteur.dart';
import 'package:cedef_area/models/user.dart';
import 'package:cedef_area/models/village.dart';
import 'package:cedef_area/repositories/cld_repository.dart';
import 'package:cedef_area/repositories/groupement_repository.dart';
import 'package:cedef_area/repositories/secteur_repository.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/repositories/village_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests exercent la hiérarchie territoriale (Secteur > Groupement > CLD
/// > Village) et son association aux utilisateurs, au-dessus d'une vraie
/// base SQLite exécutée via `sqflite_common_ffi` (voir `auth_service_test.dart`
/// pour le principe).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final secteurRepository = SecteurRepository();
  final groupementRepository = GroupementRepository();
  final cldRepository = CldRepository();
  final villageRepository = VillageRepository();
  final userRepository = UserRepository();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_territory_repository.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  /// Insère la hiérarchie Ngeba > Groupement A > CLD Ngeba 001 > Kimpemba
  /// et retourne les identifiants locaux créés.
  Future<(int secteurId, int groupementId, int cldId, int villageId)> insertHierarchy() async {
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
    final villageId = await villageRepository.insert(
      Village(
        localId: IdGenerator.generate(),
        cldId: cldId,
        nom: 'Kimpemba',
        createdAt: now,
        updatedAt: now,
      ),
    );

    return (secteurId, groupementId, cldId, villageId);
  }

  test('crée un secteur et le retrouve', () async {
    final now = DateTime.now();
    await secteurRepository.insert(
      Secteur(localId: IdGenerator.generate(), nom: 'Ngeba', createdAt: now, updatedAt: now),
    );

    final all = await secteurRepository.getAll();
    expect(all, hasLength(1));
    expect(all.first.nom, 'Ngeba');
  });

  test('récupère tous les secteurs', () async {
    final now = DateTime.now();
    await secteurRepository.insert(
      Secteur(localId: IdGenerator.generate(), nom: 'Ngeba', createdAt: now, updatedAt: now),
    );
    await secteurRepository.insert(
      Secteur(localId: IdGenerator.generate(), nom: 'Ngufu', createdAt: now, updatedAt: now),
    );

    final all = await secteurRepository.getAll();
    expect(all.map((s) => s.nom), containsAll(['Ngeba', 'Ngufu']));
  });

  test('crée un groupement rattaché à un secteur', () async {
    final now = DateTime.now();
    final secteurId = await secteurRepository.insert(
      Secteur(localId: IdGenerator.generate(), nom: 'Ngeba', createdAt: now, updatedAt: now),
    );

    await groupementRepository.insert(
      Groupement(
        localId: IdGenerator.generate(),
        secteurId: secteurId,
        nom: 'Groupement A',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final groupements = await groupementRepository.getBySecteur(secteurId);
    expect(groupements, hasLength(1));
    expect(groupements.first.nom, 'Groupement A');
  });

  test('récupère les CLD d\'un groupement', () async {
    final (_, groupementId, _, _) = await insertHierarchy();

    final clds = await cldRepository.getByGroupement(groupementId);
    expect(clds, hasLength(1));
    expect(clds.first.nom, 'CLD Ngeba 001');
  });

  test('récupère des CLD par identifiants avec leur groupement/secteur', () async {
    final (_, _, cldId, _) = await insertHierarchy();

    final results = await cldRepository.getByIdsWithLocation([cldId]);

    expect(results, hasLength(1));
    expect(results.first.cld.nom, 'CLD Ngeba 001');
    expect(results.first.groupementName, 'Groupement A');
    expect(results.first.secteurName, 'Ngeba');
  });

  test('getByIdsWithLocation renvoie une liste vide pour une liste d\'identifiants vide', () async {
    final results = await cldRepository.getByIdsWithLocation([]);
    expect(results, isEmpty);
  });

  test('récupère les villages d\'un CLD', () async {
    final (_, _, cldId, _) = await insertHierarchy();

    final villages = await villageRepository.getByCld(cldId);
    expect(villages, hasLength(1));
    expect(villages.first.nom, 'Kimpemba');
  });

  test('recherche un village par nom', () async {
    await insertHierarchy();

    final results = await villageRepository.search('kimp');
    expect(results, hasLength(1));
    expect(results.first.nom, 'Kimpemba');

    final noMatch = await villageRepository.search('inexistant');
    expect(noMatch, isEmpty);
  });

  test('associe un CLD à un utilisateur puis le retrouve', () async {
    final (_, _, cldId, _) = await insertHierarchy();
    final now = DateTime.now();
    final userId = await userRepository.insert(
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

    await cldRepository.assignToUser(userId: userId, cldId: cldId);

    final userClds = await cldRepository.getByUser(userId);
    expect(userClds, hasLength(1));
    expect(userClds.first.nom, 'CLD Ngeba 001');
  });

  test('retire un CLD d\'un utilisateur', () async {
    final (_, _, cldId, _) = await insertHierarchy();
    final now = DateTime.now();
    final userId = await userRepository.insert(
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

    await cldRepository.assignToUser(userId: userId, cldId: cldId);
    await cldRepository.unassignFromUser(userId: userId, cldId: cldId);

    expect(await cldRepository.getByUser(userId), isEmpty);
  });
}
