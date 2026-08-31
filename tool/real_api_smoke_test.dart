// ignore_for_file: avoid_print
//
// Script de vérification manuelle (section 26) : rejoue la séquence
// login -> token -> /auth/me -> /me/clds -> /me/missions -> /bootstrap ->
// logout -> accès refusé après logout, contre un vrai serveur Laravel en
// cours d'exécution, en utilisant le code de production réel (AuthApiService,
// CldApiService, MissionApiService, BootstrapApiService, DioApiClient).
//
// N'est PAS un test automatisé de la suite `flutter test` (il dépend d'un
// serveur réel démarré au préalable) : à lancer explicitement avec
//   flutter test tool/real_api_smoke_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
// (`flutter test`, et non `dart run`, car ce fichier importe transitivement
// `package:flutter` via l'app ; `dart run` seul ne fournit pas `dart:ui`.)
//
// Le stockage sécurisé réel (flutter_secure_storage) nécessite un binding
// plateforme indisponible dans ce contexte : on injecte donc un
// TokenStorage en mémoire explicite dans un DioApiClient partagé, ce qui ne
// change rien au chemin réseau réel exercé ici (Dio + Sanctum + Laravel +
// MySQL) — seul le "coffre" du token est remplacé par une Map en mémoire.
import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/network/api_client.dart';
import 'package:cedef_area/core/storage/secure_session_store.dart';
import 'package:cedef_area/core/storage/token_storage.dart';
import 'package:cedef_area/services/auth_api_service.dart';
import 'package:cedef_area/services/bootstrap_api_service.dart';
import 'package:cedef_area/services/cld_api_service.dart';
import 'package:cedef_area/services/mission_api_service.dart';

class _InMemorySessionStore implements SecureSessionStore {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
}

Future<void> main() async {
  const email = 'dhayes@example.com';
  const password = 'password';

  final tokenStorage = TokenStorage(store: _InMemorySessionStore());
  final ApiClient client = DioApiClient(tokenStorage: tokenStorage);

  final auth = AuthApiService(client: client);
  final clds = CldApiService(client: client);
  final missions = MissionApiService(client: client);
  final bootstrap = BootstrapApiService(client: client);

  var step = 0;
  void ok(String label) => print('[OK]   ${(++step).toString().padLeft(2)}. $label');
  void fail(String label, Object e) {
    print('[FAIL] ${(++step).toString().padLeft(2)}. $label -> $e');
  }

  // 1-2. Login + réception du token
  String issuedToken;
  try {
    final result = await auth.login(email: email, password: password);
    issuedToken = result.token;
    ok('Login ($email) -> token reçu (${result.token.substring(0, 6)}...), user=${result.user.fullName}');

    // 3. Stockage du token (celui déjà écrit automatiquement par
    // AuthApiService via DioApiClient n'existe pas : c'est ApiAuthProvider
    // qui appelle saveToken() après login — on le fait ici explicitement
    // pour reproduire son comportement).
    await tokenStorage.saveToken(result.token);
    final stored = await tokenStorage.getToken();
    if (stored == result.token) {
      ok('Token stocké et relu depuis TokenStorage');
    } else {
      fail('Stockage du token', 'valeur relue différente');
    }
  } catch (e) {
    fail('Login', e);
    return;
  }

  try {
    final me = await auth.getCurrentUser();
    ok('GET /auth/me -> ${me.fullName} (${me.email})');
  } catch (e) {
    fail('GET /auth/me', e);
  }

  try {
    final myClds = await clds.getMyClds();
    ok('GET /me/clds -> ${myClds.length} CLD (${myClds.map((c) => c.nom).join(', ')})');
  } catch (e) {
    fail('GET /me/clds', e);
  }

  try {
    final myMissions = await missions.getMyMissions();
    ok('GET /me/missions -> ${myMissions.length} mission(s)');
  } catch (e) {
    fail('GET /me/missions', e);
  }

  try {
    final data = await bootstrap.getBootstrap();
    ok(
      'GET /bootstrap -> user=${data.user.email}, clds=${data.clds.length}, '
      'villages=${data.villages.length}, missions=${data.missions.length}',
    );
  } catch (e) {
    fail('GET /bootstrap', e);
  }

  // 8. Logout
  try {
    await auth.logout();
    await tokenStorage.deleteToken();
    ok('POST /auth/logout -> token révoqué côté serveur, supprimé localement');
  } catch (e) {
    fail('POST /auth/logout', e);
  }

  // 9. Tentative d'accès après logout : on réécrit volontairement le token
  // déjà révoqué (celui obtenu à l'étape 1, pas un token inventé) pour
  // vérifier que le serveur le rejette bien en 401.
  await tokenStorage.saveToken(issuedToken);
  try {
    await auth.getCurrentUser();
    fail('GET /auth/me après logout', 'aurait dû être refusé (401) mais a réussi');
  } on UnauthorizedException {
    ok('GET /auth/me après logout -> 401 comme attendu (token révoqué)');
  } catch (e) {
    fail('GET /auth/me après logout', 'exception inattendue: $e');
  }

  print('\nTerminé.');
}
