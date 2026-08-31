import 'package:cedef_area/core/errors/app_exceptions.dart';
import 'package:cedef_area/core/network/api_client.dart';

/// Implémentation en mémoire de [ApiClient] pour les tests, afin de ne pas
/// dépendre d'un vrai serveur (voir `FakeSecureSessionStore` pour le même
/// principe appliqué au stockage sécurisé).
///
/// Chaque appel consulte [responses] (clé = "METHOD path") pour trouver la
/// valeur à retourner, ou [errors] pour simuler un échec.
class FakeApiClient implements ApiClient {
  final Map<String, dynamic> responses;
  final Map<String, ApiException> errors;
  final List<String> calledPaths = [];

  /// Dernier appel à [postMultipart], pour que les tests puissent inspecter
  /// les champs/fichiers réellement envoyés (voir `media_sync_service_test.dart`).
  Map<String, dynamic>? lastMultipartFields;
  List<ApiUploadFile>? lastMultipartFiles;

  /// Corps JSON du dernier appel à [post], pour que les tests puissent
  /// inspecter la charge utile réellement envoyée (voir `gps_api_service_test.dart`).
  Map<String, dynamic>? lastPostData;

  FakeApiClient({Map<String, dynamic>? responses, Map<String, ApiException>? errors})
    : responses = responses ?? {},
      errors = errors ?? {};

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _resolve('GET $path');
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? data}) {
    lastPostData = data;
    return _resolve('POST $path');
  }

  @override
  Future<dynamic> postMultipart(
    String path, {
    Map<String, dynamic>? fields,
    List<ApiUploadFile>? files,
  }) {
    lastMultipartFields = fields;
    lastMultipartFiles = files;
    return _resolve('POST $path');
  }

  Future<dynamic> _resolve(String key) async {
    calledPaths.add(key);
    if (errors.containsKey(key)) throw errors[key]!;
    if (!responses.containsKey(key)) {
      throw StateError('FakeApiClient: aucune réponse configurée pour "$key"');
    }
    return responses[key];
  }
}
