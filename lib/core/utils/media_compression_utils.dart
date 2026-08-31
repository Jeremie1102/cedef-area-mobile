import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

/// Compresse une copie de travail d'une photo (jamais l'originale de la
/// galerie, qui n'est jamais passée à ces fonctions).
///
/// Utilisée par `MediaService` juste après avoir copié une photo choisie
/// dans la galerie vers le stockage de l'application : la copie est
/// remplacée par une version compressée si l'opération réussit, sinon la
/// copie non compressée est conservée telle quelle (la compression ne doit
/// jamais empêcher l'enregistrement d'un lot).
class MediaCompressionUtils {
  MediaCompressionUtils._();

  /// Compresse [file] en place et retourne sa nouvelle taille en octets, ou
  /// la taille d'origine si la compression n'est pas applicable (format non
  /// supporté, échec du plugin, fichier déjà plus petit que le résultat).
  static Future<int> compressInPlace(
    File file, {
    int quality = 85,
    int maxDimension = 1920,
  }) async {
    final originalSize = await file.length();

    if (!_isCompressible(file.path)) return originalSize;

    final targetPath = '${file.path}.tmp${path.extension(file.path)}';
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        keepExif: false,
      );
      if (result == null) return originalSize;

      final compressedFile = File(result.path);
      final compressedSize = await compressedFile.length();
      if (compressedSize <= 0 || compressedSize >= originalSize) {
        await compressedFile.delete().catchError((_) => compressedFile);
        return originalSize;
      }

      await compressedFile.copy(file.path);
      await compressedFile.delete().catchError((_) => compressedFile);
      return compressedSize;
    } catch (_) {
      // La compression est une optimisation, pas une exigence : un échec
      // (format non supporté, plugin indisponible sur la plateforme, etc.)
      // laisse simplement la copie de travail non compressée en place.
      return originalSize;
    }
  }

  static bool _isCompressible(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.heic':
      case '.webp':
        return true;
      default:
        return false;
    }
  }
}
