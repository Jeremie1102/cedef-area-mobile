import '../core/network/api_client.dart';
import '../models/api/api_bootstrap_data.dart';

/// Amorçage du premier chargement (`GET /api/v1/bootstrap`) : profil, CLD
/// affectés, villages de ces CLD et missions affectées en un seul appel,
/// plutôt que d'enchaîner /auth/me + /me/clds + /me/missions séparément.
class BootstrapApiService {
  final ApiClient _client;

  BootstrapApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  Future<ApiBootstrapData> getBootstrap() async {
    final json = await _client.get('/bootstrap') as Map<String, dynamic>;
    return ApiBootstrapData.fromJson(json);
  }
}
