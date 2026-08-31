import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/storage/token_storage.dart';
import 'package:cedef_area/database/database_helper.dart';
import 'package:cedef_area/providers/api_auth_provider.dart';
import 'package:cedef_area/services/auth_api_service.dart';
import 'package:cedef_area/services/bootstrap_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_api_client.dart';
import '../helpers/fake_secure_session_store.dart';

const _loginResponse = {
  'message': 'Connexion réussie.',
  'token': '1|abcdef',
  'token_type': 'Bearer',
  'user': {
    'id': 1,
    'nom': 'Ondricka',
    'postnom': 'Wisozk',
    'prenom': 'Emmalee',
    'email': 'dhayes@example.com',
    'fonction': 'animateur',
    'photo_profil': null,
    'actif': true,
  },
};

const _bootstrapResponse = {
  'user': {
    'id': 1,
    'nom': 'Ondricka',
    'postnom': 'Wisozk',
    'prenom': 'Emmalee',
    'email': 'dhayes@example.com',
    'fonction': 'animateur',
    'photo_profil': null,
    'actif': true,
  },
  'clds': [],
  'villages': [],
  'missions': [],
};

ApiAuthProvider _buildProvider({
  Map<String, dynamic>? authResponses,
  Map<String, ApiException>? authErrors,
  Map<String, dynamic>? bootstrapResponses,
  TokenStorage? tokenStorage,
}) {
  final authClient = FakeApiClient(responses: authResponses, errors: authErrors);
  final bootstrapClient = FakeApiClient(responses: bootstrapResponses ?? {'GET /bootstrap': _bootstrapResponse});

  return ApiAuthProvider(
    authApiService: AuthApiService(client: authClient),
    bootstrapApiService: BootstrapApiService(client: bootstrapClient),
    tokenStorage: tokenStorage ?? TokenStorage(store: FakeSecureSessionStore()),
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.databaseFileName = 'test_api_auth_provider.db';
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      DatabaseHelper.databaseFileName,
    );
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('login réussi stocke le token, charge le bootstrap et réconcilie l\'utilisateur local', () async {
    final provider = _buildProvider(authResponses: {'POST /auth/login': _loginResponse});

    final success = await provider.login(email: 'dhayes@example.com', password: 'password');

    expect(success, isTrue);
    expect(provider.isAuthenticated, isTrue);
    expect(provider.currentUser?.email, 'dhayes@example.com');
    expect(provider.localUser, isNotNull);
    expect(provider.localUser!.nom, 'Ondricka');
    expect(provider.localUser!.serverId, 1);
  });

  test('deux connexions successives réconcilient la même ligne locale (pas de doublon)', () async {
    final provider = _buildProvider(authResponses: {'POST /auth/login': _loginResponse});

    await provider.login(email: 'dhayes@example.com', password: 'password');
    final firstLocalId = provider.localUser!.id;

    await provider.login(email: 'dhayes@example.com', password: 'password');
    final secondLocalId = provider.localUser!.id;

    expect(secondLocalId, firstLocalId);
  });

  test('login avec identifiants invalides (401) échoue proprement', () async {
    final provider = _buildProvider(
      authErrors: {'POST /auth/login': const UnauthorizedException('Identifiants invalides.')},
    );

    final success = await provider.login(email: 'inconnu@example.com', password: 'wrong');

    expect(success, isFalse);
    expect(provider.isAuthenticated, isFalse);
    expect(provider.errorMessage, 'Identifiants invalides.');
  });

  test('login sur un compte désactivé (403) échoue avec le message serveur', () async {
    final provider = _buildProvider(
      authErrors: {'POST /auth/login': const ForbiddenException('Ce compte est désactivé.')},
    );

    final success = await provider.login(email: 'inactif@example.com', password: 'password');

    expect(success, isFalse);
    expect(provider.errorMessage, 'Ce compte est désactivé.');
  });

  test('login avec un formulaire invalide (422) échoue avec le message de validation', () async {
    final provider = _buildProvider(
      authErrors: {
        'POST /auth/login': const ApiValidationException('Champs invalides.', {
          'email': ['Le champ email est obligatoire.'],
        }),
      },
    );

    final success = await provider.login(email: '', password: '');

    expect(success, isFalse);
    expect(provider.errorMessage, 'Champs invalides.');
  });

  test('restoreSession : token invalide/expiré (401) déconnecte et supprime le token', () async {
    final tokenStorage = TokenStorage(store: FakeSecureSessionStore());
    await tokenStorage.saveToken('token-expire');
    final provider = _buildProvider(
      authErrors: {'GET /auth/me': const UnauthorizedException()},
      tokenStorage: tokenStorage,
    );

    await provider.restoreSession();

    expect(provider.isAuthenticated, isFalse);
    expect(await tokenStorage.hasToken(), isFalse);
  });

  test('restoreSession : erreur réseau conserve la session (pas de déconnexion)', () async {
    final tokenStorage = TokenStorage(store: FakeSecureSessionStore());
    await tokenStorage.saveToken('token-valide');
    final provider = _buildProvider(
      authErrors: {'GET /auth/me': const NetworkException()},
      tokenStorage: tokenStorage,
    );

    await provider.restoreSession();

    expect(provider.isAuthenticated, isTrue);
    expect(await tokenStorage.hasToken(), isTrue);
  });

  test('logout supprime le token et réinitialise l\'état', () async {
    final tokenStorage = TokenStorage(store: FakeSecureSessionStore());
    await tokenStorage.saveToken('token-valide');
    final provider = _buildProvider(
      authResponses: {'POST /auth/logout': {'message': 'Déconnexion réussie.'}},
      tokenStorage: tokenStorage,
    );

    await provider.logout();

    expect(provider.isAuthenticated, isFalse);
    expect(provider.currentUser, isNull);
    expect(await tokenStorage.hasToken(), isFalse);
  });
}
