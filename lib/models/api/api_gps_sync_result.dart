/// Réponse Laravel à `POST /api/v1/gps-positions` : pour chaque position
/// envoyée, son sort — acceptée (nouvelle), déjà synchronisée (idempotence),
/// ou rejetée (avec une raison) — voir `GpsSyncService`.
class ApiGpsSyncResult {
  final Map<String, int> acceptedServerIdsByLocalId;
  final Map<String, int> alreadySyncedServerIdsByLocalId;
  final Map<String, String> rejectedReasonsByLocalId;

  const ApiGpsSyncResult({
    required this.acceptedServerIdsByLocalId,
    required this.alreadySyncedServerIdsByLocalId,
    required this.rejectedReasonsByLocalId,
  });

  factory ApiGpsSyncResult.fromJson(Map<String, dynamic> json) {
    Map<String, int> serverIdsByLocalId(String key) {
      final list = (json[key] as List<dynamic>?) ?? const [];
      return {
        for (final entry in list)
          (entry as Map<String, dynamic>)['local_id'] as String: entry['id'] as int,
      };
    }

    final rejectedList = (json['rejected'] as List<dynamic>?) ?? const [];

    return ApiGpsSyncResult(
      acceptedServerIdsByLocalId: serverIdsByLocalId('accepted'),
      alreadySyncedServerIdsByLocalId: serverIdsByLocalId('already_synced'),
      rejectedReasonsByLocalId: {
        for (final entry in rejectedList)
          (entry as Map<String, dynamic>)['local_id'] as String:
              entry['reason'] as String? ?? 'Position rejetée par le serveur.',
      },
    );
  }
}
