import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/services/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api_client.dart';

void main() {
  group('AuthApiService.login', () {
    test('login réussi renvoie le token et le profil', () async {
      final client = FakeApiClient(
        responses: {
          'POST /auth/login': {
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
          },
        },
      );
      final service = AuthApiService(client: client);

      final result = await service.login(login: 'dhayes@example.com', password: 'password');

      expect(result.token, '1|abcdef');
      expect(result.user.email, 'dhayes@example.com');
    });

    test('login avec matricule réussi renvoie le token et le profil', () async {
      final client = FakeApiClient(
        responses: {
          'POST /auth/login': {
            'message': 'Connexion réussie.',
            'token': '2|fedcba',
            'token_type': 'Bearer',
            'user': {
              'id': 2,
              'nom': 'Mukendi',
              'postnom': 'Kabongo',
              'prenom': 'Jean',
              'email': 'jean.mukendi@cedef.org',
              'fonction': 'superviseur',
              'photo_profil': null,
              'actif': true,
            },
          },
        },
      );
      final service = AuthApiService(client: client);

      final result = await service.login(login: 'AG-042', password: 'password');

      expect(result.token, '2|fedcba');
      expect(result.user.nom, 'Mukendi');
    });

    test('login échoué (401) propage UnauthorizedException', () async {
      final client = FakeApiClient(
        errors: {'POST /auth/login': const UnauthorizedException('Identifiants invalides.')},
      );
      final service = AuthApiService(client: client);

      expect(
        () => service.login(login: 'inconnu@example.com', password: 'wrong'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  test('getCurrentUser renvoie le profil connecté', () async {
    final client = FakeApiClient(
      responses: {
        'GET /auth/me': {
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
        },
      },
    );
    final service = AuthApiService(client: client);

    final user = await service.getCurrentUser();

    expect(user.id, 1);
    expect(user.nom, 'Ondricka');
  });

  test('logout appelle bien POST /auth/logout', () async {
    final client = FakeApiClient(responses: {'POST /auth/logout': {'message': 'Déconnexion réussie.'}});
    final service = AuthApiService(client: client);

    await service.logout();

    expect(client.calledPaths, contains('POST /auth/logout'));
  });
}
