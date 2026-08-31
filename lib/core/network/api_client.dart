import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../config/app_config.dart';
import '../errors/app_exceptions.dart';
import '../storage/token_storage.dart';

/// Un fichier local à envoyer dans une requête multipart (voir
/// [ApiClient.postMultipart]).
///
/// Type volontairement indépendant de Dio (comme le reste de cette
/// interface) : [field] est le nom du champ multipart (par exemple `photos`,
/// répété pour plusieurs fichiers), [path] le chemin local du fichier.
class ApiUploadFile {
  final String field;
  final String path;
  final String? filename;
  final String? contentType;

  const ApiUploadFile({
    required this.field,
    required this.path,
    this.filename,
    this.contentType,
  });
}

/// Client HTTP générique vers l'API Laravel.
///
/// Interface volontairement minimale (GET/POST/POST-multipart : lecture,
/// écriture, envoi de fichiers). Séparer l'interface de son implémentation
/// Dio permet de la remplacer par un faux client dans les tests (voir
/// `FakeApiClient`), sans dépendre du réseau.
abstract class ApiClient {
  /// Retourne le corps JSON déjà décodé (`Map` ou `List` selon l'endpoint).
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters});

  Future<dynamic> post(String path, {Map<String, dynamic>? data});

  /// Envoi `multipart/form-data` : [fields] pour les champs simples (une
  /// valeur `List` y est envoyée comme des champs répétés `champ[]`, au
  /// format attendu par Laravel), [files] pour les fichiers — voir
  /// `MediaApiService`, seul consommateur actuel (envoi d'un lot de photos).
  Future<dynamic> postMultipart(
    String path, {
    Map<String, dynamic>? fields,
    List<ApiUploadFile>? files,
  });
}

/// Implémentation [ApiClient] basée sur `package:dio`.
///
/// Ajoute automatiquement l'en-tête `Authorization: Bearer <token>` lorsqu'un
/// token est présent dans [TokenStorage] : les services appelants n'ont
/// jamais à s'en soucier eux-mêmes (section 9/10 du cahier des charges).
class DioApiClient implements ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  DioApiClient({Dio? dio, TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.apiConnectTimeout,
              receiveTimeout: AppConfig.apiReceiveTimeout,
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _run(() => _dio.get(path, queryParameters: queryParameters));
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? data}) {
    return _run(() => _dio.post(path, data: data));
  }

  @override
  Future<dynamic> postMultipart(
    String path, {
    Map<String, dynamic>? fields,
    List<ApiUploadFile>? files,
  }) {
    return _run(() async {
      final formMap = <String, dynamic>{...?fields};
      for (final file in files ?? const <ApiUploadFile>[]) {
        final multipartFile = await MultipartFile.fromFile(
          file.path,
          filename: file.filename,
          contentType: file.contentType != null ? MediaType.parse(file.contentType!) : null,
        );
        // Plusieurs fichiers peuvent partager le même nom de champ (`photos`) :
        // ils sont alors regroupés dans une liste, que Dio envoie comme des
        // champs répétés `photos[]`, au format attendu par Laravel.
        final existing = formMap[file.field];
        if (existing is List) {
          existing.add(multipartFile);
        } else {
          formMap[file.field] = [multipartFile];
        }
      }
      return _dio.post(path, data: FormData.fromMap(formMap));
    });
  }

  Future<dynamic> _run(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException('Connexion au serveur non sécurisée.');
      case DioExceptionType.cancel:
        return const NetworkException('Requête annulée.');
      case DioExceptionType.badResponse:
        return _mapStatusCode(e);
      case DioExceptionType.unknown:
        return const NetworkException();
      default:
        return const NetworkException();
    }
  }

  ApiException _mapStatusCode(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    final message = (body is Map && body['message'] is String)
        ? body['message'] as String
        : null;

    switch (statusCode) {
      case 401:
        return UnauthorizedException(message ?? 'Identifiants invalides.');
      case 403:
        return ForbiddenException(message ?? 'Accès refusé.');
      case 404:
        return NotFoundException(message ?? 'Ressource introuvable.');
      case 413:
        return PayloadTooLargeException(message ?? 'Un ou plusieurs fichiers sont trop volumineux.');
      case 422:
        final rawErrors = (body is Map && body['errors'] is Map) ? body['errors'] as Map : const {};
        final errors = rawErrors.map(
          (key, value) => MapEntry(key.toString(), (value as List).map((v) => v.toString()).toList()),
        );
        return ApiValidationException(message ?? 'Champs invalides.', errors);
      case 429:
        return RateLimitedException(message ?? 'Trop de tentatives. Réessayez plus tard.');
      default:
        return ServerException(message ?? 'Le serveur a rencontré une erreur.');
    }
  }
}
