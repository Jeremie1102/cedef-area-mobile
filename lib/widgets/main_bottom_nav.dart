import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Barre de navigation commune aux écrans principaux (Accueil, Missions,
/// Médias, Profil). Ne contient aucune logique métier : elle se contente
/// de naviguer entre les routes nommées de l'application.
class MainBottomNav extends StatelessWidget {
  final int currentIndex;

  const MainBottomNav({super.key, required this.currentIndex});

  static const _routes = [
    AppRoutes.home,
    AppRoutes.missions,
    AppRoutes.media,
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == currentIndex) return;
        Navigator.of(context).pushReplacementNamed(_routes[index]);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Missions'),
        BottomNavigationBarItem(icon: Icon(Icons.photo_library_outlined), label: 'Médias'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    );
  }
}
