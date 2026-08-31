/// Règles de validation de formulaire réutilisables et testables
/// indépendamment de l'interface graphique.
class Validators {
  Validators._();

  static String? required(String? value, {String message = 'Ce champ est requis.'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  /// Un mot de passe est jugé suffisamment sécurisé s'il contient au moins
  /// 6 caractères, une lettre et un chiffre.
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis.';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'Le mot de passe doit contenir au moins une lettre et un chiffre.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value != password) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }
}
