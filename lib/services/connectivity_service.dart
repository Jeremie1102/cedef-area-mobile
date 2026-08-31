import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_config.dart';

/// Détecte la disponibilité d'une connexion **Internet**, pas seulement
/// d'une interface réseau active.
///
/// Être connecté à un Wi-Fi ne garantit pas un accès Internet (portail
/// captif, routeur sans accès montant, ...) : [isOnline] vérifie donc, en
/// plus de la présence d'une interface réseau ([hasNetworkInterface]), qu'un
/// hôte externe est réellement joignable. Utilisé par [SyncService] pour
/// savoir quand tenter d'envoyer les données en attente vers l'API Laravel.
class ConnectivityService {
  final Connectivity _connectivity;

  /// Points d'injection utilisés par les tests pour remplacer les appels
  /// réels (canal de plateforme `connectivity_plus`, résolution DNS) par un
  /// comportement simulé — voir `test/services/connectivity_service_test.dart`.
  /// `null` en usage normal : les méthodes utilisent alors directement
  /// `Connectivity`/`InternetAddress.lookup`.
  final Future<bool> Function()? _networkInterfaceChecker;
  final Future<bool> Function()? _reachabilityChecker;

  ConnectivityService({
    Connectivity? connectivity,
    Future<bool> Function()? networkInterfaceChecker,
    Future<bool> Function()? reachabilityChecker,
  }) : _connectivity = connectivity ?? Connectivity(),
       // ignore: prefer_initializing_formals
       _networkInterfaceChecker = networkInterfaceChecker,
       // ignore: prefer_initializing_formals
       _reachabilityChecker = reachabilityChecker;

  /// Vrai si une interface réseau est active (Wi-Fi, données mobiles, ...),
  /// sans préjuger d'un accès Internet réel. Rarement utile directement :
  /// préférer [isOnline].
  Future<bool> hasNetworkInterface() async {
    if (_networkInterfaceChecker != null) return _networkInterfaceChecker();
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  /// Vrai si une interface réseau est active **et** qu'un hôte externe est
  /// réellement joignable.
  Future<bool> isOnline() async {
    if (!await hasNetworkInterface()) return false;
    return _checkReachability();
  }

  /// Émet `true`/`false` à chaque changement de connexion, après vérification
  /// de la joignabilité réelle (pas seulement du changement d'interface).
  Stream<bool> get onStatusChange {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      if (!_hasConnection(results)) return false;
      return _checkReachability();
    });
  }

  Future<bool> _checkReachability() async {
    if (_reachabilityChecker != null) return _reachabilityChecker();
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(AppConfig.connectivityCheckTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
