import '../core/network/api_client.dart';
import '../models/api/api_user.dart';

/// Résultat d'une connexion réussie : token à conserver + profil de l'agent.
class ApiLoginResult {
  final String token;
  final ApiUser user;

  const ApiLoginResult({required this.token, required this.user});
}

/// Authentification serveur (Laravel Sanctum), distincte de [AuthService]
/// (authentification locale hors-ligne, inchangée par cette étape).
///
/// Ne contient aucune logique d'interface : les écrans passent par
/// [ApiAuthProvider], qui utilise ce service.
class AuthApiService {
  final ApiClient _client;

  AuthApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  Future<ApiLoginResult> login({required String email, required String password}) async {
    final json = await _client.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    ) as Map<String, dynamic>;

    return ApiLoginResult(
      token: json['token'] as String,
      user: ApiUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    await _client.post('/auth/logout');
  }

  Future<ApiUser> getCurrentUser() async {
    final json = await _client.get('/auth/me') as Map<String, dynamic>;
    return ApiUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}
