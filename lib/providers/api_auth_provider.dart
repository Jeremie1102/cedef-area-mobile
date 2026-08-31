import 'package:flutter/foundation.dart';

import '../core/errors/app_exceptions.dart';
import '../core/storage/token_storage.dart';
import '../models/api/api_cld.dart';
import '../models/api/api_mission.dart';
import '../models/api/api_user.dart';
import '../models/api/api_village.dart';
import '../models/user.dart';
import '../services/auth_api_service.dart';
import '../services/bootstrap_api_service.dart';
import '../services/downstream_sync_service.dart';

/// Expose l'état de la session serveur (Sanctum) à toute l'application.
///
/// Distinct de [AuthProvider] (session locale hors-ligne, inchangée) : ce
/// provider gère l'authentification en ligne introduite à cette étape — le
/// login passe désormais par l'API Laravel plutôt que par une vérification
/// SQLite locale. Voir le rapport de l'étape pour la justification de cette
/// séparation.
class ApiAuthProvider extends ChangeNotifier {
  final AuthApiService _authApiService;
  final BootstrapApiService _bootstrapApiService;
  final DownstreamSyncService _downstreamSyncService;
  final TokenStorage _tokenStorage;

  ApiAuthProvider({
    AuthApiService? authApiService,
    BootstrapApiService? bootstrapApiService,
    DownstreamSyncService? downstreamSyncService,
    TokenStorage? tokenStorage,
  }) : _authApiService = authApiService ?? AuthApiService(),
       _bootstrapApiService = bootstrapApiService ?? BootstrapApiService(),
       _downstreamSyncService = downstreamSyncService ?? DownstreamSyncService(),
       _tokenStorage = tokenStorage ?? TokenStorage();

  ApiUser? _currentUser;
  List<ApiCld> _clds = [];
  List<ApiVillage> _villages = [];
  List<ApiMission> _missions = [];
  User? _localUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  ApiUser? get currentUser => _currentUser;
  List<ApiCld> get clds => _clds;
  List<ApiVillage> get villages => _villages;
  List<ApiMission> get missions => _missions;

  /// Ligne locale `users` (SQLite) réconciliée par `server_id` avec
  /// [currentUser], persistée par [DownstreamSyncService] à chaque
  /// téléchargement réussi. `null` tant qu'aucun téléchargement n'a encore
  /// réussi dans ce cycle de vie du provider (ex. : restauration hors ligne).
  /// Utilisée pour pontuer cette session en ligne vers `AuthProvider` (voir
  /// `AuthProvider.setCurrentUser`), que les écrans existants consultent déjà.
  User? get localUser => _localUser;

  /// `true` dès qu'un token est présent, indépendamment de la disponibilité
  /// du réseau : une panne Internet ne doit jamais, à elle seule, être
  /// interprétée comme une déconnexion (section 20/22 du cahier des charges).
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// À appeler au démarrage (SplashScreen) pour restaurer une session
  /// existante à partir du token stocké de façon sécurisée.
  Future<void> restoreSession() async {
    final hasToken = await _tokenStorage.hasToken();
    if (!hasToken) {
      _isAuthenticated = false;
      notifyListeners();
      return;
    }

    _isAuthenticated = true;
    try {
      _currentUser = await _authApiService.getCurrentUser();
      await _loadBootstrapData();
    } on UnauthorizedException {
      // Token expiré/révoqué côté serveur : seul cas où l'on force la
      // déconnexion locale.
      await _tokenStorage.deleteToken();
      _isAuthenticated = false;
      _currentUser = null;
    } on NetworkException {
      // Hors ligne : on conserve la session, simplement sans profil à jour.
    } catch (_) {
      // Toute autre erreur serveur : on reste connecté plutôt que de
      // bloquer l'accès à l'application pour un incident temporaire.
    } finally {
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authApiService.login(email: email, password: password);
      await _tokenStorage.saveToken(result.token);
      _currentUser = result.user;
      _isAuthenticated = true;
      await _loadBootstrapData();
      return true;
    } catch (e) {
      _errorMessage = _friendlyMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _authApiService.logout();
    } catch (_) {
      // Le token est de toute façon supprimé localement ci-dessous : rester
      // bloqué connecté parce que le serveur est injoignable serait pire
      // qu'une révocation serveur orpheline.
    }
    await _tokenStorage.deleteToken();
    _isAuthenticated = false;
    _currentUser = null;
    _clds = [];
    _villages = [];
    _missions = [];
    _localUser = null;
    notifyListeners();
  }

  Future<void> _loadBootstrapData() async {
    try {
      final data = await _bootstrapApiService.getBootstrap();
      _currentUser = data.user;
      _clds = data.clds;
      _villages = data.villages;
      _missions = data.missions;
      // Persiste la même réponse dans SQLite (aucun appel réseau
      // supplémentaire) : voir `DownstreamSyncService`.
      _localUser = await _downstreamSyncService.applyBootstrap(data);
    } catch (_) {
      // Non bloquant : le tableau de bord affichera simplement des
      // compteurs vides plutôt que d'empêcher la connexion.
    }
  }

  /// Les erreurs techniques ne doivent jamais atteindre l'utilisateur : on ne
  /// remonte que le message des exceptions connues.
  String _friendlyMessage(Object error) {
    if (error is AppException) return error.message;
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
