/// Extrait la liste `data` d'une réponse paginée Laravel standard
/// (`{"data": [...], "links": {...}, "meta": {...}}`), utilisée par tous les
/// endpoints `/api/v1/me/*`.
List<T> parsePaginatedData<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
  final data = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? const [];
  return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
}
