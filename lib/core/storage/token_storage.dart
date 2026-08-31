import 'secure_session_store.dart';

/// Stockage sécurisé du token Sanctum courant.
///
/// S'appuie sur [SecureSessionStore] (déjà utilisé pour la session locale)
/// plutôt que de parler directement à `flutter_secure_storage`, pour rester
/// testable avec `FakeSecureSessionStore` sans dépendre des canaux natifs.
class TokenStorage {
  static const String _tokenKey = 'sanctum_auth_token';

  final SecureSessionStore _store;

  TokenStorage({SecureSessionStore? store}) : _store = store ?? FlutterSecureSessionStore();

  Future<void> saveToken(String token) => _store.write(_tokenKey, token);

  Future<String?> getToken() => _store.read(_tokenKey);

  Future<void> deleteToken() => _store.delete(_tokenKey);

  Future<bool> hasToken() async => (await getToken()) != null;
}
