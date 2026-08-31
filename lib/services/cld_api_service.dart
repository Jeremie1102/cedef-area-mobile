import '../core/network/api_client.dart';
import '../models/api/api_cld.dart';
import '../models/api/paginated_list.dart';

/// CLD affectés à l'agent connecté (`GET /api/v1/me/clds`).
///
/// Le serveur détermine seul l'utilisateur via le token Sanctum : ce service
/// ne prend et ne peut prendre aucun identifiant utilisateur en paramètre.
class CldApiService {
  final ApiClient _client;

  CldApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  Future<List<ApiCld>> getMyClds() async {
    final json = await _client.get('/me/clds');
    return parsePaginatedData(json, ApiCld.fromJson);
  }
}
