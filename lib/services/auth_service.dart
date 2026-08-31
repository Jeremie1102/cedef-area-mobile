import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/storage/secure_session_store.dart';
import '../core/utils/file_storage_utils.dart';
import '../core/utils/id_generator.dart';
import '../database/database_tables.dart';
import '../models/user.dart';
import '../repositories/sync_queue_repository.dart';
import '../repositories/user_repository.dart';

/// Gère l'authentification locale (hors-ligne) des agents de terrain.
///
/// Il ne s'agit pas d'une authentification serveur : les identifiants sont
/// vérifiés localement dans SQLite. La session courante est mémorisée de
/// façon sécurisée avec [SecureSessionStore] pour rester connecté entre deux
/// ouvertures de l'application.
class AuthService {
  static const String _sessionUserIdKey = 'session_user_id';

  final UserRepository _userRepository;
  final SecureSessionStore _sessionStore;
  final ImagePicker _imagePicker;
  final SyncQueueRepository _syncQueueRepository;

  AuthService({
    UserRepository? userRepository,
    SecureSessionStore? sessionStore,
    ImagePicker? imagePicker,
    SyncQueueRepository? syncQueueRepository,
  }) : _userRepository = userRepository ?? UserRepository(),
       _sessionStore = sessionStore ?? FlutterSecureSessionStore(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  // --- Mot de passe -------------------------------------------------------

  /// Hache le mot de passe avec un sel aléatoire (format `sel:empreinte`).
  /// Le mot de passe en clair n'est jamais enregistré dans SQLite.
  String hashPassword(String password) {
    final salt = _generateSalt();
    return '$salt:${_digest(password, salt)}';
  }

  bool verifyPassword({required String password, required String storedHash}) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salt = parts[0];
    final expectedDigest = parts[1];
    return _digest(password, salt) == expectedDigest;
  }

  String _digest(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  // --- Inscription / connexion --------------------------------------------

  Future<User> register({
    required String nom,
    required String postNom,
    required String prenom,
    required UserFonction fonction,
    required String password,
    String? telephone,
  }) async {
    try {
      if (telephone != null && telephone.isNotEmpty) {
        final existingByPhone = await _userRepository.findByTelephone(telephone);
        if (existingByPhone != null) {
          throw const AuthException('Un compte existe déjà avec ce numéro de téléphone.');
        }
      }

      final existingByName = await _userRepository.findByFullName(
        nom: nom,
        postNom: postNom,
        prenom: prenom,
      );
      if (existingByName != null) {
        throw const AuthException('Un compte existe déjà avec ces nom, post-nom et prénom.');
      }

      final now = DateTime.now();
      final user = User(
        localId: IdGenerator.generate(),
        nom: nom.trim(),
        postNom: postNom.trim(),
        prenom: prenom.trim(),
        fonction: fonction,
        passwordHash: hashPassword(password),
        telephone: (telephone == null || telephone.isEmpty) ? null : telephone.trim(),
        syncStatus: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _userRepository.insert(user);
      final created = user.copyWith(id: id);
      await _syncQueueRepository.addToQueue(
        entityTable: DatabaseTables.users,
        entityLocalId: user.localId,
        operation: SyncOperation.create,
      );
      await startSession(created);
      return created;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const DatabaseException('Impossible de créer le compte. Veuillez réessayer.');
    }
  }

  Future<User> login({required String telephone, required String password}) async {
    try {
      final user = await _userRepository.findByTelephone(telephone.trim());
      // Le même message est utilisé pour un numéro inconnu ou un mot de
      // passe erroné afin de ne pas révéler si un compte existe.
      if (user == null || !verifyPassword(password: password, storedHash: user.passwordHash)) {
        throw const AuthException('Identifiants incorrects.');
      }
      if (!user.isActive) {
        throw const AuthException('Ce compte est désactivé.');
      }
      await startSession(user);
      return user;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const DatabaseException('Impossible de vous connecter. Veuillez réessayer.');
    }
  }

  Future<void> logout() => _sessionStore.delete(_sessionUserIdKey);

  Future<User?> currentUser() async {
    final idValue = await _sessionStore.read(_sessionUserIdKey);
    if (idValue == null) return null;
    return _userRepository.findById(int.parse(idValue));
  }

  Future<bool> isAuthenticated() async => (await currentUser()) != null;

  /// Mémorise [user] comme session locale active. Utilisée en interne par
  /// [login]/[register], et par [AuthProvider.setCurrentUser] pour ponter une
  /// connexion en ligne (Sanctum) vers ce mécanisme de session hors-ligne, de
  /// sorte qu'un redémarrage entièrement sans réseau retrouve le même agent.
  Future<void> startSession(User user) async {
    await _sessionStore.write(_sessionUserIdKey, user.id.toString());
  }

  // --- Profil ---------------------------------------------------------------

  Future<User> updateProfile({
    required int userId,
    required String nom,
    required String postNom,
    required String prenom,
    String? telephone,
    String? photoProfil,
  }) async {
    try {
      final existing = await _userRepository.findById(userId);
      if (existing == null) {
        throw const AuthException('Utilisateur introuvable.');
      }

      final updated = existing.copyWith(
        nom: nom.trim(),
        postNom: postNom.trim(),
        prenom: prenom.trim(),
        telephone: (telephone == null || telephone.isEmpty) ? existing.telephone : telephone.trim(),
        photoProfil: photoProfil ?? existing.photoProfil,
        syncStatus: SyncStatus.pending,
        updatedAt: DateTime.now(),
      );

      await _userRepository.update(updated);
      await _syncQueueRepository.addToQueue(
        entityTable: DatabaseTables.users,
        entityLocalId: updated.localId,
        operation: SyncOperation.update,
      );
      return updated;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const DatabaseException('Impossible de mettre à jour le profil. Veuillez réessayer.');
    }
  }

  /// Ouvre la caméra ou la galerie, copie la photo choisie dans le stockage
  /// privé de l'application et retourne son chemin local.
  Future<String?> pickProfilePhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return null;
      return FileStorageUtils.saveToAppFolder(picked, AppConfig.profilePhotoFolderName);
    } catch (_) {
      throw const AppException('Impossible d\'accéder à la photo sélectionnée.');
    }
  }
}
