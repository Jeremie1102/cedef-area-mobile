/// Exception de base pour toutes les erreurs métier de l'application.
class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => message;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

class AuthException extends AppException {
  const AuthException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class SyncException extends AppException {
  const SyncException(super.message);
}

class GpsException extends AppException {
  const GpsException(super.message);
}

class MediaException extends AppException {
  const MediaException(super.message);
}

/// Exception de base pour toutes les erreurs remontées par [ApiClient] lors
/// d'un appel à l'API Laravel.
///
/// Séparée de la hiérarchie locale ci-dessus car ses causes (réseau, code
/// HTTP, session serveur) n'ont rien à voir avec les erreurs SQLite/GPS/média
/// existantes : un appelant peut ainsi distinguer précisément « le serveur a
/// refusé la requête » de « impossible de joindre le serveur ».
class ApiException extends AppException {
  final int? statusCode;

  const ApiException(super.message, {this.statusCode});
}

/// Aucune connexion réseau, ou serveur injoignable (timeout, DNS, etc.).
///
/// À ne JAMAIS interpréter comme « session invalide » : voir section 20/22
/// du cahier des charges — une panne Internet ne doit pas déconnecter
/// l'utilisateur.
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Impossible de joindre le serveur. Vérifiez votre connexion.',
  ]);
}

/// HTTP 401 : token absent, invalide ou expiré.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Session expirée. Veuillez vous reconnecter.'])
    : super(statusCode: 401);
}

/// HTTP 403 : compte désactivé, ou accès à une ressource non autorisée.
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Accès refusé.']) : super(statusCode: 403);
}

/// HTTP 404 : ressource inexistante côté serveur.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Ressource introuvable.']) : super(statusCode: 404);
}

/// HTTP 422 : erreurs de validation Laravel. [errors] reprend la structure
/// `{champ: [messages]}` retournée par le serveur, utile pour surligner les
/// champs en erreur dans un formulaire.
class ApiValidationException extends ApiException {
  final Map<String, List<String>> errors;

  const ApiValidationException(super.message, this.errors) : super(statusCode: 422);
}

/// HTTP 413 : fichier(s) trop volumineux pour le serveur (voir la limite par
/// photo de `StoreMediaBatchRequest` côté Laravel, ou une limite serveur en
/// amont — proxy, `post_max_size`).
class PayloadTooLargeException extends ApiException {
  const PayloadTooLargeException([
    super.message = 'Un ou plusieurs fichiers sont trop volumineux.',
  ]) : super(statusCode: 413);
}

/// HTTP 429 : trop de tentatives (voir throttle:login côté Laravel).
class RateLimitedException extends ApiException {
  const RateLimitedException([
    super.message = 'Trop de tentatives. Veuillez patienter avant de réessayer.',
  ]) : super(statusCode: 429);
}

/// HTTP 5xx : erreur inattendue côté serveur.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Le serveur a rencontré une erreur. Réessayez plus tard.',
  ]) : super(statusCode: 500);
}
