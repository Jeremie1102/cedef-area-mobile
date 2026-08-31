import 'package:cedef_area/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ces tests vérifient que [ConnectivityService] distingue bien la présence
/// d'une interface réseau de l'accès réel à Internet (voir section 10 du
/// cahier des charges) : être connecté à un Wi-Fi sans accès montant ne doit
/// jamais être confondu avec "en ligne".
void main() {
  test('hors ligne si aucune interface réseau n\'est active', () async {
    final service = ConnectivityService(
      networkInterfaceChecker: () async => false,
      reachabilityChecker: () async => true,
    );

    expect(await service.isOnline(), isFalse);
  });

  test('hors ligne si une interface est active mais Internet n\'est pas joignable '
      '(Wi-Fi sans accès montant, portail captif, ...)', () async {
    final service = ConnectivityService(
      networkInterfaceChecker: () async => true,
      reachabilityChecker: () async => false,
    );

    expect(await service.isOnline(), isFalse);
  });

  test('en ligne uniquement si l\'interface réseau et la joignabilité sont toutes les deux vraies', () async {
    final service = ConnectivityService(
      networkInterfaceChecker: () async => true,
      reachabilityChecker: () async => true,
    );

    expect(await service.isOnline(), isTrue);
  });

  test('hasNetworkInterface ne vérifie que l\'interface, pas la joignabilité', () async {
    final service = ConnectivityService(
      networkInterfaceChecker: () async => true,
      reachabilityChecker: () async => false,
    );

    expect(await service.hasNetworkInterface(), isTrue);
    expect(await service.isOnline(), isFalse);
  });
}
