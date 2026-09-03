import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/file_storage_utils.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/media_compression_utils.dart';
import '../models/media_batch.dart';
import '../models/media_item.dart';
import '../repositories/media_repository.dart';
import 'gps_service.dart';

/// Service de gestion des lots de médias de terrain.
///
/// CEDEF AREA ne prend pas de photo : l'animateur sélectionne des photos déjà
/// présentes dans sa galerie ([pickPhotosFromGallery]) puis les regroupe en
/// un lot ([createBatch]) décrit une seule fois (activité, CLD, village,
/// description). Les fichiers originaux de la galerie ne sont jamais
/// modifiés ni supprimés : chaque photo sélectionnée est copiée dans le
/// stockage privé de l'application avant d'être enregistrée.
///
/// La synchronisation vers Laravel (voir `MediaSyncService`) lit directement
/// `media_batches.sync_status`/`media_items.sync_status` : ce service n'a
/// donc rien à ajouter à `sync_queue` (contrairement aux autres entités —
/// missions, GPS — encore sur le moteur générique `SyncService`), un lot se
/// transmettant en une seule requête multipart plutôt qu'entrée par entrée.
class MediaService {
  final MediaRepository _mediaRepository;
  final ImagePicker _imagePicker;
  final GpsService _gpsService;

  MediaService({
    MediaRepository? mediaRepository,
    ImagePicker? imagePicker,
    GpsService? gpsService,
  }) : _mediaRepository = mediaRepository ?? MediaRepository(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _gpsService = gpsService ?? GpsService();

  /// Ouvre le sélecteur de galerie en mode multi-sélection.
  /// Borne dès la sélection système le nombre de photos
  /// (voir `AppConfig.mediaBatchMaxPhotos`) : jamais plus que nécessaire en
  /// mémoire, quel que soit le nombre de photos choisi par l'agent.
  /// [limit] permet à l'appelant de réduire ce plafond (ajout à un lot déjà
  /// partiellement rempli) ; `null`/absent revient au plafond par défaut.
  Future<List<XFile>> pickPhotosFromGallery({int? limit}) {
    return _imagePicker.pickMultiImage(limit: limit ?? AppConfig.mediaBatchMaxPhotos);
  }

  /// Ouvre l'appareil photo pour capturer une photo directement sur le terrain.
  Future<XFile?> takePhotoWithCamera() {
    return _imagePicker.pickImage(source: ImageSource.camera);
  }

  /// Crée un lot de médias à partir de photos déjà sélectionnées dans la
  /// galerie : copie chaque fichier dans un dossier dédié au lot (voir
  /// `_batchFolder`) puis enregistre le lot et ses photos en base locale.
  ///
  /// La description est obligatoire (voir section 11 du cahier des charges) :
  /// elle explique ce que montrent les photos, pas seulement une étiquette.
  ///
  /// Une position GPS est capturée au niveau du lot (pas de chaque photo) si
  /// elle est disponible rapidement ; sinon le lot est simplement enregistré
  /// sans coordonnées, sans bloquer l'utilisateur.
  ///
  /// Aussi atomique que possible (voir section 20/31) : si la copie d'une
  /// photo échoue en cours de route, le dossier du lot et la ligne
  /// `media_batches` (et les `media_items` déjà insérés, supprimés en
  /// cascade) sont retirés — jamais de lot incomplet, jamais de fichier
  /// orphelin.
  Future<MediaBatch> createBatch({
    required int userId,
    required List<XFile> photos,
    int? missionId,
    int? secteurId,
    int? groupementId,
    int? cldId,
    int? villageId,
    String? activity,
    required String description,
    DateTime? capturedAt,
  }) async {
    if (photos.isEmpty) {
      throw const MediaException('Sélectionnez au moins une photo pour créer un lot.');
    }
    if (photos.length > AppConfig.mediaBatchMaxPhotos) {
      throw MediaException(
        'Un lot ne peut pas contenir plus de ${AppConfig.mediaBatchMaxPhotos} photos.',
      );
    }
    _requireValidDescription(description);

    final position = await _tryGetPosition();
    final now = DateTime.now();

    final batch = MediaBatch(
      localId: IdGenerator.generate(),
      userId: userId,
      missionId: missionId,
      secteurId: secteurId,
      groupementId: groupementId,
      cldId: cldId,
      villageId: villageId,
      activity: activity,
      description: description.trim(),
      latitude: position?.latitude,
      longitude: position?.longitude,
      gpsAccuracy: position?.accuracy,
      capturedAt: capturedAt ?? now,
      createdAt: now,
      updatedAt: now,
    );

    final batchId = await _mediaRepository.insertBatch(batch);

    try {
      for (var i = 0; i < photos.length; i++) {
        await _addItemToBatch(
          batchId: batchId,
          batchLocalId: batch.localId,
          photo: photos[i],
          sortOrder: i,
        );
      }
    } catch (e) {
      await _cleanupFailedBatch(batchId: batchId, batchLocalId: batch.localId);
      throw const MediaException('Impossible d\'enregistrer les photos du lot. Veuillez réessayer.');
    }

    return batch.copyWith(id: batchId);
  }

  /// Ajoute des photos supplémentaires à un lot déjà enregistré (voir
  /// section « Modification d'un lot »). [startSortOrder] doit être le
  /// nombre de photos déjà présentes dans le lot, pour que l'ordre reste
  /// cohérent avec celles déjà enregistrées.
  Future<void> addPhotosToBatch({
    required int batchId,
    required String batchLocalId,
    required List<XFile> photos,
    required int startSortOrder,
  }) async {
    if (startSortOrder + photos.length > AppConfig.mediaBatchMaxPhotos) {
      throw MediaException(
        'Un lot ne peut pas contenir plus de ${AppConfig.mediaBatchMaxPhotos} photos.',
      );
    }
    for (var i = 0; i < photos.length; i++) {
      await _addItemToBatch(
        batchId: batchId,
        batchLocalId: batchLocalId,
        photo: photos[i],
        sortOrder: startSortOrder + i,
      );
    }
  }

  /// Retire une photo d'un lot : supprime la copie de travail de
  /// l'application (jamais la photo originale de la galerie, que ce service
  /// ne référence même pas) puis la ligne locale correspondante.
  Future<void> removeItem(MediaItem item) async {
    await _mediaRepository.removeItem(item.id!);
    try {
      final file = File(item.localPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // La copie de travail est déjà retirée de la base : un fichier orphelin
      // n'est jamais bloquant, seulement un peu d'espace de stockage perdu.
    }
  }

  /// Enregistre les modifications apportées aux informations d'un lot
  /// (activité, description, village, ...). Interdit toute modification une
  /// fois le lot synchronisé (voir section « Modification d'un lot »).
  Future<void> updateBatch(MediaBatch batch) async {
    if (batch.syncStatus == SyncStatus.synced) {
      throw const MediaException('Ce lot est déjà synchronisé et ne peut plus être modifié.');
    }
    _requireValidDescription(batch.description);
    await _mediaRepository.updateBatch(
      batch.copyWith(description: batch.description?.trim(), updatedAt: DateTime.now()),
    );
  }

  /// Supprime définitivement un lot et ses photos (copies de travail incluses)
  /// — jamais les photos originales de la galerie. Refuse de supprimer un lot
  /// déjà synchronisé (voir section « Suppression »).
  Future<void> deleteBatch(MediaBatch batch) async {
    if (batch.syncStatus == SyncStatus.synced) {
      throw const MediaException('Ce lot est déjà synchronisé et ne peut plus être supprimé.');
    }

    final items = await _mediaRepository.getItemsByBatch(batch.id!);
    for (final item in items) {
      try {
        final file = File(item.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Idem : un fichier orphelin n'empêche jamais la suppression du lot.
      }
    }
    await _mediaRepository.deleteBatch(batch.id!);
    // Nettoyage final du dossier du lot : garantit qu'aucun fichier orphelin
    // ne subsiste même si un item avait un chemin déjà invalide ci-dessus.
    await FileStorageUtils.deleteAppFolder(_batchFolder(batch.localId));
  }

  /// Taille totale (en octets) d'une sélection de photos, pour afficher une
  /// estimation à l'utilisateur avant l'enregistrement du lot.
  Future<int> totalBytes(List<XFile> photos) async {
    var total = 0;
    for (final photo in photos) {
      try {
        total += await File(photo.path).length();
      } catch (_) {
        // Fichier temporairement inaccessible : ignoré dans l'estimation.
      }
    }
    return total;
  }

  /// Sous-dossier dédié à un lot (voir section 19 : jamais tous les fichiers
  /// dans un seul dossier), sous [AppConfig.mediaFolderName]. Basé sur
  /// `localId` (stable dès la création, jamais régénéré), pas sur l'id
  /// SQLite auto-incrémenté : le nom du dossier reste valable même si le lot
  /// n'a pas encore d'id serveur.
  String _batchFolder(String batchLocalId) => path.join(AppConfig.mediaFolderName, 'batches', batchLocalId);

  /// Description non vide (une fois débarrassée des espaces) et bornée en
  /// longueur (voir section 11) : validée ici en plus de l'UI, comme filet de
  /// sécurité au niveau service.
  void _requireValidDescription(String? description) {
    final trimmed = description?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw const MediaException('La description du lot est obligatoire.');
    }
    if (trimmed.length > AppConfig.mediaBatchDescriptionMaxLength) {
      throw MediaException(
        'La description ne doit pas dépasser ${AppConfig.mediaBatchDescriptionMaxLength} caractères.',
      );
    }
  }

  /// Retire toute trace d'un lot dont la création a échoué en cours de route
  /// (voir [createBatch]) : dossier du lot et ligne `media_batches` (les
  /// `media_items` déjà insérés sont supprimés en cascade par SQLite).
  Future<void> _cleanupFailedBatch({required int batchId, required String batchLocalId}) async {
    await _mediaRepository.deleteBatch(batchId);
    await FileStorageUtils.deleteAppFolder(_batchFolder(batchLocalId));
  }

  Future<void> _addItemToBatch({
    required int batchId,
    required String batchLocalId,
    required XFile photo,
    required int sortOrder,
  }) async {
    final localPath = await FileStorageUtils.saveToAppFolder(photo, _batchFolder(batchLocalId));
    final fileSize = await MediaCompressionUtils.compressInPlace(
      File(localPath),
      quality: AppConfig.mediaCompressionQuality,
      maxDimension: AppConfig.mediaCompressionMaxDimension,
    );
    final itemNow = DateTime.now();

    final item = MediaItem(
      localId: IdGenerator.generate(),
      batchId: batchId,
      localPath: localPath,
      fileName: path.basename(localPath),
      fileSize: fileSize,
      mimeType: _guessMimeType(localPath),
      sortOrder: sortOrder,
      createdAt: itemNow,
      updatedAt: itemNow,
    );

    await _mediaRepository.insertItem(item);
  }

  String _guessMimeType(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.heic':
        return 'image/heic';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<Position?> _tryGetPosition() async {
    try {
      return await _gpsService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Le GPS est une information optionnelle du lot : son indisponibilité
      // (permission refusée, position introuvable, délai dépassé) ne doit
      // jamais empêcher l'enregistrement du lot.
      return null;
    }
  }

  Future<int> countPendingSync() => _mediaRepository.countPendingSyncBatches();
}
