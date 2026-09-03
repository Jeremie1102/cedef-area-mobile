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

  Future<ApiLoginResult> login({
    required String login,
    required String password,
    String deviceName = 'android_flutter',
  }) async {
    final json = await _client.post(
      '/auth/login',
      data: {
        'login': login,
        'password': password,
        'device_name': deviceName,
      },
    ) as Map<String, dynamic>;

    final token = (json['token'] ?? json['access_token'] ?? '') as String;
    final userMap = (json['user'] ?? json['data'] ?? json) as Map<String, dynamic>;

    return ApiLoginResult(
      token: token,
      user: ApiUser.fromJson(userMap),
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
