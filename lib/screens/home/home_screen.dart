import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../providers/api_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../repositories/media_repository.dart';
import '../../routes/app_routes.dart';
import '../../services/mission_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/main_bottom_nav.dart';

/// Tableau de bord affiché après connexion : identité de l'agent, accès
/// rapide aux modules principaux et statut de connexion.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _mediaRepository = MediaRepository();
  final _missionService = MissionService();
  late Future<int> _pendingMediaCountFuture;

  @override
  void initState() {
    super.initState();
    _pendingMediaCountFuture = _mediaRepository.countPendingSyncBatches();
    _resumeActiveMissionTracking();
    // Tentative de synchronisation au démarrage (section 11) : ignorée
    // silencieusement si hors ligne ou si une synchronisation est déjà en
    // cours (voir `SyncService.syncAll`), donc jamais bloquante pour l'écran.
    unawaited(SyncService.instance.syncAll());
  }

  /// Si une mission est déjà `in_progress` pour l'utilisateur (démarrée puis
  /// l'application fermée sans la terminer), relance son suivi GPS — voir
  /// `MissionService.resumeTrackingForActiveMission`.
  Future<void> _resumeActiveMissionTracking() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await _missionService.resumeTrackingForActiveMission(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final apiAuth = context.watch<ApiAuthProvider>();
    final apiUser = apiAuth.currentUser;
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    // Le profil serveur (à jour dès que le réseau est disponible) prime sur
    // le profil local ; ce dernier reste un repli pour un compte créé
    // hors-ligne et jamais encore synchronisé (voir rapport d'étape).
    final prenom = apiUser?.prenom ?? user?.prenom ?? '';
    final fonction = apiUser != null ? _parseFonction(apiUser.fonction) : user?.fonction;

    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bonjour $prenom 👋',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Fonction : ${_fonctionLabel(fonction)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(icon: Icons.groups_outlined, label: 'CLD', value: apiAuth.clds.length),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.assignment_outlined,
                    label: 'Missions',
                    value: apiAuth.missions.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _ModuleTile(
              icon: Icons.assignment_outlined,
              label: 'Mes missions',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.missions),
            ),
            _ModuleTile(
              icon: Icons.photo_library_outlined,
              label: 'Mes médias',
              trailing: FutureBuilder<int>(
                future: _pendingMediaCountFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Badge(label: Text('$count'));
                },
              ),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.media),
            ),
            _ModuleTile(
              icon: Icons.route_outlined,
              label: 'Mes parcours',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.activity),
            ),
            _ModuleTile(
              icon: Icons.map_outlined,
              label: 'Territoire / CLD',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.territory),
            ),
            _ModuleTile(
              icon: Icons.person_outline,
              label: 'Mon profil',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 12, color: isOnline ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(isOnline ? 'Connecté' : 'Hors ligne'),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 0),
    );
  }

  String _fonctionLabel(UserFonction? fonction) {
    switch (fonction) {
      case UserFonction.animateur:
        return 'Animateur';
      case UserFonction.mrv:
        return 'Agent MRV';
      case UserFonction.sauvegarde:
        return 'Agent de sauvegarde';
      case UserFonction.sig:
        return 'Agent SIG';
      case null:
        return '-';
    }
  }

  /// Convertit la valeur brute de `ApiUser.fonction` (ex. `"animateur"`) en
  /// [UserFonction], sans repli implicite : `null` si la valeur est absente
  /// ou inconnue, plutôt que de deviner une fonction par défaut.
  UserFonction? _parseFonction(String? raw) {
    if (raw == null) return null;
    for (final f in UserFonction.values) {
      if (f.name == raw) return f;
    }
    return null;
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ModuleTile({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontSize: 16)),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
