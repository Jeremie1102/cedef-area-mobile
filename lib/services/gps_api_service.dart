import '../core/network/api_client.dart';
import '../models/api/api_gps_sync_result.dart';
import '../models/gps_position.dart';

/// Envoi d'un lot de positions GPS à `POST /api/v1/gps-positions` — une
/// seule requête JSON pour plusieurs positions (voir section 6/29 du cahier
/// des charges : jamais une requête par position). Jamais de `user_id`
/// envoyé : le serveur identifie l'agent via le token.
class GpsApiService {
  final ApiClient _client;

  GpsApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  /// [missionServerIds] associe l'id **local** de chaque mission référencée
  /// par [positions] à son id **serveur** (résolu par l'appelant, voir
  /// `GpsSyncService`) : un même lot peut couvrir plusieurs missions.
  Future<ApiGpsSyncResult> syncPositions(
    List<GpsPosition> positions,
    Map<int, int> missionServerIds,
  ) async {
    final payload = {
      'positions': positions
          .map(
            (position) => {
              'local_id': position.localId,
              'mission_id': missionServerIds[position.missionId],
              'latitude': position.latitude,
              'longitude': position.longitude,
              if (position.altitude != null) 'altitude': position.altitude,
              if (position.accuracy != null) 'accuracy': position.accuracy,
              if (position.speed != null) 'speed': position.speed,
              if (position.heading != null) 'heading': position.heading,
              // UTC pour la synchronisation (section 22), sans jamais
              // remplacer l'heure de capture réelle par l'heure d'envoi.
              'captured_at': position.recordedAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
    };

    final json = await _client.post('/gps-positions', data: payload);
    return ApiGpsSyncResult.fromJson(json as Map<String, dynamic>);
  }
}
