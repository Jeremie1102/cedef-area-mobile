/// Réponse Laravel à `POST /api/v1/media-batches` : le lot enregistré côté
/// serveur (identifiant, et pour chaque photo son identifiant serveur retrouvé
/// via son `local_id` — voir `MediaSyncService`).
class ApiMediaBatch {
  final int id;
  final String localId;
  final Map<String, int> itemServerIdsByLocalId;

  const ApiMediaBatch({
    required this.id,
    required this.localId,
    required this.itemServerIdsByLocalId,
  });

  factory ApiMediaBatch.fromJson(Map<String, dynamic> json) {
    final batch = json['batch'] as Map<String, dynamic>;
    final items = (batch['items'] as List<dynamic>?) ?? const [];
    return ApiMediaBatch(
      id: batch['id'] as int,
      localId: batch['local_id'] as String,
      itemServerIdsByLocalId: {
        for (final item in items)
          (item as Map<String, dynamic>)['local_id'] as String: item['id'] as int,
      },
    );
  }
}
