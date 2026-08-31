import '../core/network/api_client.dart';
import '../models/api/api_mission.dart';
import '../models/api/paginated_list.dart';

/// Missions affectées à l'agent connecté (`GET /api/v1/me/missions`).
///
/// Jamais de `user_id` envoyé : le serveur identifie l'agent via le token.
class MissionApiService {
  final ApiClient _client;

  MissionApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  Future<List<ApiMission>> getMyMissions() async {
    final json = await _client.get('/me/missions');
    return parsePaginatedData(json, ApiMission.fromJson);
  }
}
