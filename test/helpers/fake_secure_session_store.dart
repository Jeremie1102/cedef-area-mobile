import 'package:cedef_area/core/storage/secure_session_store.dart';

/// Implémentation en mémoire de [SecureSessionStore] pour les tests, afin de
/// ne pas dépendre des canaux de plateforme natifs de `flutter_secure_storage`.
class FakeSecureSessionStore implements SecureSessionStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
