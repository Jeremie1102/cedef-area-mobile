import '../core/network/api_client.dart';
import '../core/utils/date_utils.dart';
import '../models/api/api_media_batch.dart';
import '../models/media_batch.dart';
import '../models/media_item.dart';

/// Envoi d'un lot de médias à `POST /api/v1/media-batches` : une seule
/// requête multipart contenant les métadonnées du lot et toutes ses photos
/// (voir section 12/13 du cahier des charges — pas de ZIP, pas d'envoi photo
/// par photo). Jamais de `user_id` envoyé : le serveur identifie l'agent via
/// le token (voir `DioApiClient`).
class MediaApiService {
  final ApiClient _client;

  MediaApiService({ApiClient? client}) : _client = client ?? DioApiClient();

  /// [items] doit être trié dans l'ordre à conserver côté serveur (voir
  /// `MediaRepository.getItemsByBatch`, déjà trié par `sort_order`) : l'ordre
  /// d'apparition dans la requête devient `media_items.order`.
  Future<ApiMediaBatch> uploadBatch({
    required MediaBatch batch,
    required List<MediaItem> items,
    required int missionServerId,
    int? cldServerId,
    int? villageServerId,
  }) async {
    final fields = <String, dynamic>{
      'local_id': batch.localId,
      'mission_id': missionServerId.toString(),
      if (cldServerId != null) 'cld_id': cldServerId.toString(),
      if (villageServerId != null) 'village_id': villageServerId.toString(),
      if (batch.activity != null) 'activite': batch.activity,
      'description': batch.description ?? '',
      'date_activite': AppDateUtils.toIso(batch.capturedAt).substring(0, 10),
      if (batch.latitude != null) 'latitude': batch.latitude.toString(),
      if (batch.longitude != null) 'longitude': batch.longitude.toString(),
      if (batch.gpsAccuracy != null) 'precision': batch.gpsAccuracy.toString(),
      'photos_local_ids': items.map((item) => item.localId).toList(),
    };

    final files = items
        .map(
          (item) => ApiUploadFile(
            field: 'photos',
            path: item.localPath,
            filename: item.fileName,
            contentType: item.mimeType,
          ),
        )
        .toList();

    final json = await _client.postMultipart(
      '/media-batches',
      fields: fields,
      files: files,
    );
    return ApiMediaBatch.fromJson(json as Map<String, dynamic>);
  }
}
