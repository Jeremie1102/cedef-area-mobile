import 'dart:io';

import 'package:cedef_area/core/utils/file_storage_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../helpers/fake_path_provider_platform.dart';

/// Ces tests exercent [FileStorageUtils] : copie d'un fichier sélectionné
/// dans le stockage privé de l'application, et suppression d'un sous-dossier.
/// Aucune vraie photo personnelle n'est utilisée (voir section 39 du cahier
/// des charges) : de petits fichiers factices sont générés dans un dossier
/// temporaire du système, qui tient lieu de « dossier documents » de
/// l'application via [FakePathProviderPlatform].
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cedef_file_storage_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<XFile> createFakeImage(String name, {List<int>? bytes}) async {
    final sourceDir = await Directory.systemTemp.createTemp('cedef_source_');
    final file = File(p.join(sourceDir.path, name));
    await file.writeAsBytes(bytes ?? List.generate(32, (i) => i));
    return XFile(file.path);
  }

  test('crée le dossier cible et copie le fichier dedans', () async {
    final photo = await createFakeImage('photo1.jpg');

    final destination = await FileStorageUtils.saveToAppFolder(photo, 'cedef_media');

    expect(await File(destination).exists(), isTrue);
    expect(p.isWithin(p.join(tempDir.path, 'cedef_media'), destination), isTrue);
    expect(await File(destination).readAsBytes(), await File(photo.path).readAsBytes());
  });

  test('copie plusieurs fichiers dans des sous-dossiers distincts sans se mélanger', () async {
    final photoA = await createFakeImage('a.jpg', bytes: [1, 2, 3]);
    final photoB = await createFakeImage('b.jpg', bytes: [4, 5, 6]);

    final destA = await FileStorageUtils.saveToAppFolder(photoA, 'cedef_media/batches/batch-a');
    final destB = await FileStorageUtils.saveToAppFolder(photoB, 'cedef_media/batches/batch-b');

    expect(destA, isNot(equals(destB)));
    expect(await File(destA).readAsBytes(), [1, 2, 3]);
    expect(await File(destB).readAsBytes(), [4, 5, 6]);
    expect(p.dirname(destA), isNot(equals(p.dirname(destB))));
  });

  test('chaque copie reçoit un nom de fichier unique, même pour la même source', () async {
    final photo = await createFakeImage('same.jpg');

    final dest1 = await FileStorageUtils.saveToAppFolder(photo, 'cedef_media');
    final dest2 = await FileStorageUtils.saveToAppFolder(photo, 'cedef_media');

    expect(dest1, isNot(equals(dest2)));
    expect(await File(dest1).exists(), isTrue);
    expect(await File(dest2).exists(), isTrue);
  });

  test('deleteAppFolder supprime le dossier et tout son contenu', () async {
    final photo = await createFakeImage('to_delete.jpg');
    final destination = await FileStorageUtils.saveToAppFolder(photo, 'cedef_media/batches/batch-x');

    await FileStorageUtils.deleteAppFolder('cedef_media/batches/batch-x');

    expect(await File(destination).exists(), isFalse);
    expect(await Directory(p.join(tempDir.path, 'cedef_media', 'batches', 'batch-x')).exists(), isFalse);
  });

  test('deleteAppFolder ne lève aucune erreur si le dossier n\'existe pas', () async {
    await expectLater(
      FileStorageUtils.deleteAppFolder('cedef_media/batches/inexistant'),
      completes,
    );
  });
}
