import 'package:cedef_area/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.required', () {
    test('rejette une valeur nulle ou vide', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
    });

    test('accepte une valeur renseignée', () {
      expect(Validators.required('Kabila'), isNull);
    });
  });

  group('Validators.password', () {
    test('rejette un mot de passe vide', () {
      expect(Validators.password(''), isNotNull);
    });

    test('rejette un mot de passe trop court', () {
      expect(Validators.password('ab1'), isNotNull);
    });

    test('rejette un mot de passe sans chiffre', () {
      expect(Validators.password('motdepasse'), isNotNull);
    });

    test('rejette un mot de passe sans lettre', () {
      expect(Validators.password('123456'), isNotNull);
    });

    test('accepte un mot de passe suffisamment sécurisé', () {
      expect(Validators.password('motdepasse1'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('rejette une confirmation différente', () {
      expect(Validators.confirmPassword('abc123', 'abc124'), isNotNull);
    });

    test('accepte une confirmation identique', () {
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
    });
  });
}
