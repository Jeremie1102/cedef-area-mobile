// Test de démarrage : vérifie que l'application se lance et affiche
// l'écran de démarrage (SplashScreen) avant redirection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cedef_area/main.dart';

void main() {
  testWidgets('L\'application démarre et affiche le SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const CedefAreaApp());

    expect(find.text('CEDEF AREA'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
