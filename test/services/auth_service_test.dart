import 'package:cedef_area/core/constants/app_constants.dart';
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/repositories/user_repository.dart';
import 'package:cedef_area/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_secure_session_store.dart';

/// Ces tests exercent [AuthService] au-dessus d'une vraie base SQLite (via
/// `sqflite_common_ffi`, qui exécute SQLite nativement dans la VM Dart sans
/// passer par un canal de plateforme) et d'un [FakeSecureSessionStore] en
/// mémoire, afin de ne dépendre d'aucun plugin natif pendant les tests.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthService authService;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_auth_service.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);

    authService = AuthService(
      userRepository: UserRepository(),
      sessionStore: FakeSecureSessionStore(),
    );
  });

  group('register', () {
    test('crée un utilisateur et ouvre une session', () async {
      final user = await authService.register(
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        password: 'motdepasse1',
        telephone: '0810000000',
      );

      expect(user.id, isNotNull);
      expect(await authService.isAuthenticated(), isTrue);
      expect((await authService.currentUser())?.telephone, '0810000000');
    });

    test('refuse deux comptes avec le même numéro de téléphone', () async {
      await authService.register(
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        password: 'motdepasse1',
        telephone: '0810000000',
      );

      expect(
        () => authService.register(
          nom: 'Autre',
          postNom: 'Nom',
          prenom: 'Personne',
          fonction: UserFonction.mrv,
          password: 'motdepasse2',
          telephone: '0810000000',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('refuse deux comptes avec les mêmes nom, post-nom et prénom', () async {
      await authService.register(
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        password: 'motdepasse1',
      );

      expect(
        () => authService.register(
          nom: 'kabila',
          postNom: 'mwamba',
          prenom: 'jean',
          fonction: UserFonction.sig,
          password: 'motdepasse2',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('ne stocke jamais le mot de passe en clair', () async {
      final user = await authService.register(
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        password: 'motdepasse1',
      );

      expect(user.passwordHash, isNot(contains('motdepasse1')));
      expect(user.passwordHash, contains(':'));
    });
  });

  group('login', () {
    setUp(() async {
      await authService.register(
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        password: 'motdepasse1',
        telephone: '0810000000',
      );
      await authService.logout();
    });

    test('réussit avec les bons identifiants', () async {
      final user = await authService.login(telephone: '0810000000', password: 'motdepasse1');

      expect(user.telephone, '0810000000');
      expect(await authService.isAuthenticated(), isTrue);
    });

    test('échoue avec un mauvais mot de passe', () async {
      expect(
        () => authService.login(telephone: '0810000000', password: 'mauvais1'),
        throwsA(isA<AuthException>()),
      );
    });

    test('échoue avec un numéro inconnu', () async {
      expect(
        () => authService.login(telephone: '0899999999', password: 'motdepasse1'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('logout', () {
    test('supprime la session locale sans supprimer le compte', () async {
      final registered = await authService.register(
        nom: 'Kabila',
        postNom: 'Mwamba',
        prenom: 'Jean',
        fonction: UserFonction.animateur,
        password: 'motdepasse1',
        telephone: '0810000000',
      );

      await authService.logout();

      expect(await authService.isAuthenticated(), isFalse);

      final userStillExists = await authService.login(
        telephone: '0810000000',
        password: 'motdepasse1',
      );
      expect(userStillExists.id, registered.id);
    });
  });
}
