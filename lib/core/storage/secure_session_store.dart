import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction du stockage sécurisé utilisé pour mémoriser la session locale.
///
/// Séparer cette interface de `flutter_secure_storage` permet de remplacer
/// facilement l'implémentation dans les tests (voir `FakeSecureSessionStore`)
/// sans dépendre des canaux de plateforme natifs.
abstract class SecureSessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureSessionStore implements SecureSessionStore {
  final FlutterSecureStorage _storage;

  FlutterSecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
