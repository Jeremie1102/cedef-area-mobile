import 'package:uuid/uuid.dart';

/// Génère les identifiants locaux (`local_id`) utilisés pour identifier
/// une donnée de façon unique avant qu'elle ne soit synchronisée et
/// reçoive un `server_id`.
class IdGenerator {
  IdGenerator._();

  static const Uuid _uuid = Uuid();

  static String generate() => _uuid.v4();
}
