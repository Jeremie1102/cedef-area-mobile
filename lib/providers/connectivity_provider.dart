import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

/// Expose l'état de connexion Internet à toute l'application.
///
/// Déclenche également une synchronisation automatique dès que la connexion
/// redevient disponible (voir section 11 : "Automatique — lorsque la
/// connexion revient"). [SyncService.syncAll] ignore déjà tout appel
/// concurrent, donc un déclenchement automatique et un appui manuel sur
/// « Synchroniser maintenant » ne peuvent jamais se chevaucher.
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  final SyncService _syncService;
  StreamSubscription<bool>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityProvider({ConnectivityService? connectivityService, SyncService? syncService})
    : _connectivityService = connectivityService ?? ConnectivityService(),
      _syncService = syncService ?? SyncService.instance {
    _init();
  }

  Future<void> _init() async {
    _isOnline = await _connectivityService.isOnline();
    notifyListeners();

    _subscription = _connectivityService.onStatusChange.listen((online) {
      final wasOffline = !_isOnline;
      _isOnline = online;
      notifyListeners();

      if (wasOffline && online) {
        unawaited(_syncService.syncAll());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
