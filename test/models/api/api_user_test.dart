import 'package:cedef_area/models/api/api_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiUser.fromJson', () {
    test('parses a full UserResource payload', () {
      final json = {
        'id': 1,
        'nom': 'Ondricka',
        'postnom': 'Wisozk',
        'prenom': 'Emmalee',
        'email': 'dhayes@example.com',
        'fonction': 'animateur',
        'photo_profil': null,
        'actif': true,
      };

      final user = ApiUser.fromJson(json);

      expect(user.id, 1);
      expect(user.nom, 'Ondricka');
      expect(user.postnom, 'Wisozk');
      expect(user.prenom, 'Emmalee');
      expect(user.email, 'dhayes@example.com');
      expect(user.fonction, 'animateur');
      expect(user.photoProfil, isNull);
      expect(user.actif, isTrue);
      expect(user.fullName, 'Ondricka Wisozk Emmalee');
    });

    test('handles a null fonction (compte administratif)', () {
      final json = {
        'id': 2,
        'nom': 'Admin',
        'postnom': null,
        'prenom': null,
        'email': 'admin@example.com',
        'fonction': null,
        'photo_profil': null,
        'actif': true,
      };

      final user = ApiUser.fromJson(json);

      expect(user.fonction, isNull);
      expect(user.fullName, 'Admin');
    });
  });
}
