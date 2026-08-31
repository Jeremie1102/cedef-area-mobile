import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Expose l'état d'authentification courant à toute l'application.
///
/// Les écrans ne manipulent jamais [AuthService] directement : ils passent
/// par ce provider, qui centralise l'état (utilisateur connecté, chargement,
/// erreur) et notifie l'interface lors des changements.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// À appeler au démarrage (SplashScreen) pour restaurer une session existante.
  Future<void> restoreSession() async {
    _currentUser = await _authService.currentUser();
    notifyListeners();
  }

  /// Adopte [user] comme utilisateur courant et persiste la session locale
  /// correspondante (voir `AuthService.startSession`), de sorte qu'un
  /// redémarrage entièrement hors ligne restaure le même agent via
  /// [restoreSession]. Utilisée pour pontuer une connexion en ligne
  /// (`ApiAuthProvider`) vers ce provider, que tous les écrans existants
  /// consultent déjà — voir `ApiAuthProvider.localUser`.
  Future<void> setCurrentUser(User user) async {
    await _authService.startSession(user);
    _currentUser = user;
    notifyListeners();
  }

  Future<bool> login({required String telephone, required String password}) async {
    return _runAction(() => _authService.login(telephone: telephone, password: password));
  }

  Future<bool> register({
    required String nom,
    required String postNom,
    required String prenom,
    required UserFonction fonction,
    required String password,
    String? telephone,
  }) async {
    return _runAction(
      () => _authService.register(
        nom: nom,
        postNom: postNom,
        prenom: prenom,
        fonction: fonction,
        password: password,
        telephone: telephone,
      ),
    );
  }

  Future<bool> updateProfile({
    required String nom,
    required String postNom,
    required String prenom,
    String? telephone,
    String? photoProfil,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null) return false;

    return _runAction(
      () => _authService.updateProfile(
        userId: userId,
        nom: nom,
        postNom: postNom,
        prenom: prenom,
        telephone: telephone,
        photoProfil: photoProfil,
      ),
    );
  }

  Future<String?> pickProfilePhoto(ImageSource source) async {
    try {
      return await _authService.pickProfilePhoto(source);
    } catch (e) {
      _errorMessage = _friendlyMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> _runAction(Future<User> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await action();
      return true;
    } catch (e) {
      _errorMessage = _friendlyMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Les erreurs techniques ne doivent jamais atteindre l'utilisateur : on ne
  /// remonte que le message des exceptions métier connues.
  String _friendlyMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
