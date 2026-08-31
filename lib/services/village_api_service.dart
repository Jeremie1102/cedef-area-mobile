import '../core/network/api_client.dart';
import '../models/api/api_village.dart';
import '../models/api/paginated_list.dart';

/// Villages d'un CLD (`GET /api/v1/me/clds/{cld}/villages`).
///
/// L'autorisation reste entièrement du ressort de Laravel (l'agent doit être
/// affecté au CLD demandé) : ce service se contente de relayer la réponse ou
/// l'erreur 403/404 du serveur, sans jamais tenter de la contourner
/// localement.
class VillageApiService {
  final ApiClient _client;

  VillageApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  Future<List<ApiVillage>> getVillagesForCld(int cldId) async {
    final json = await _client.get('/me/clds/$cldId/villages');
    return parsePaginatedData(json, ApiVillage.fromJson);
  }
}
