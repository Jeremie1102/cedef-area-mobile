import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'id_generator.dart';

/// Copie un fichier sélectionné par l'utilisateur (photo, document) dans un
/// sous-dossier du stockage privé de l'application et retourne son chemin
/// local définitif.
class FileStorageUtils {
  FileStorageUtils._();

  static Future<String> saveToAppFolder(XFile file, String folderName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(path.join(appDir.path, folderName));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = path.extension(file.path);
    final fileName = '${IdGenerator.generate()}$extension';
    final destination = path.join(targetDir.path, fileName);

    await File(file.path).copy(destination);
    return destination;
  }

  /// Supprime récursivement un sous-dossier du stockage privé de
  /// l'application (et tout son contenu), sans erreur s'il n'existe pas déjà
  /// plus. Utilisée pour nettoyer le dossier d'un lot de médias, que ce soit
  /// après une suppression volontaire ou après l'échec d'une création (voir
  /// `MediaService`) : plus fiable que de retrouver fichier par fichier.
  static Future<void> deleteAppFolder(String folderName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(path.join(appDir.path, folderName));
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
  }
}
