import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/api_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

/// Vérifie l'état initial de l'application (session serveur existante ou
/// non, via le token Sanctum stocké de façon sécurisée ; et/ou session locale
/// hors-ligne, via le stockage sécurisé propre à [AuthProvider]) puis
/// redirige vers l'écran adapté.
///
/// La présence d'un token API suffit à considérer l'utilisateur connecté :
/// une absence de réseau au démarrage ne le renvoie pas à l'écran de
/// connexion (voir [ApiAuthProvider.restoreSession]). Une session locale
/// valide (compte créé hors-ligne, ou agent déjà réconcilié lors d'une
/// précédente connexion en ligne — voir [ApiAuthProvider.localUser]) suffit
/// tout autant : les deux sont vérifiées indépendamment.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final apiAuthProvider = context.read<ApiAuthProvider>();
    final authProvider = context.read<AuthProvider>();

    await apiAuthProvider.restoreSession();
    // Filet de sécurité hors-ligne : restaure aussi la session locale
    // indépendante d'AuthProvider (compte créé hors-ligne, ou agent déjà
    // réconcilié lors d'une précédente connexion en ligne), qu'un token
    // Sanctum soit présent ou non.
    await authProvider.restoreSession();

    final localUser = apiAuthProvider.localUser;
    if (localUser != null) {
      await authProvider.setCurrentUser(localUser);
    }

    if (!mounted) return;

    final isAuthenticated = apiAuthProvider.isAuthenticated || authProvider.isAuthenticated;
    Navigator.of(context).pushReplacementNamed(isAuthenticated ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined, size: 64),
            SizedBox(height: 16),
            Text(AppConfig.appName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
