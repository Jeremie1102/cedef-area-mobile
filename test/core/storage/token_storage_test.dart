import 'package:cedef_area/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_secure_session_store.dart';

void main() {
  late TokenStorage tokenStorage;

  setUp(() {
    tokenStorage = TokenStorage(store: FakeSecureSessionStore());
  });

  test('hasToken renvoie false tant qu\'aucun token n\'a été enregistré', () async {
    expect(await tokenStorage.hasToken(), isFalse);
    expect(await tokenStorage.getToken(), isNull);
  });

  test('saveToken puis getToken renvoie le token enregistré', () async {
    await tokenStorage.saveToken('abc123');

    expect(await tokenStorage.hasToken(), isTrue);
    expect(await tokenStorage.getToken(), 'abc123');
  });

  test('deleteToken supprime le token enregistré', () async {
    await tokenStorage.saveToken('abc123');
    await tokenStorage.deleteToken();

    expect(await tokenStorage.hasToken(), isFalse);
    expect(await tokenStorage.getToken(), isNull);
  });
}
