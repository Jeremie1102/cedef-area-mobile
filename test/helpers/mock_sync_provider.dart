import 'dart:async';

import 'package:cedef_area/models/sync_queue_entry.dart';
import 'package:cedef_area/services/sync_api_provider.dart';

/// Comportement simulé par [MockSyncProvider] pour une entrée donnée — voir
/// section 26 du cahier des charges ("il doit simuler : succès, échec,
/// timeout").
enum MockSyncBehavior { success, failure, timeout }

/// Implémentation de [SyncApiProvider] utilisée uniquement par les tests, en
/// attendant que l'API Laravel existe (voir `UnimplementedSyncApiProvider`
/// pour l'implémentation par défaut de l'application).
///
/// Par défaut, chaque envoi réussit et attribue un `server_id` croissant
/// (ce qui suffit à vérifier le mécanisme de bout en bout). [behaviorFor]
/// permet de piloter précisément le comportement par entrée, pour tester les
/// cas d'échec, de timeout, et la reprise après interruption.
class MockSyncProvider implements SyncApiProvider {
  final MockSyncBehavior Function(SyncQueueEntry entry)? behaviorFor;
  final Duration timeoutDelay;

  int _nextServerId = 1;

  /// Entrées reçues par [send], dans l'ordre — pratique pour vérifier
  /// l'ordre de synchronisation dans les tests.
  final List<SyncQueueEntry> sentEntries = [];

  MockSyncProvider({this.behaviorFor, this.timeoutDelay = const Duration(seconds: 30)});

  @override
  Future<SyncApiResult> send(SyncQueueEntry entry) async {
    sentEntries.add(entry);
    final behavior = behaviorFor?.call(entry) ?? MockSyncBehavior.success;

    switch (behavior) {
      case MockSyncBehavior.success:
        return SyncApiResult.success(serverId: _nextServerId++);
      case MockSyncBehavior.failure:
        return const SyncApiResult.failure('Erreur simulée par MockSyncProvider.');
      case MockSyncBehavior.timeout:
        await Future<void>.delayed(timeoutDelay);
        return const SyncApiResult.failure('Timeout simulé par MockSyncProvider.');
    }
  }
}
