import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/api_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/cld_repository.dart';
import '../../routes/app_routes.dart';
import '../../widgets/main_bottom_nav.dart';
import '../territory/villages_screen.dart';

/// Affiche les informations de l'utilisateur connecté, ainsi que les CLD
/// dont il a la charge.
///
/// La section « Mes CLD » est une **consultation uniquement** : ces
/// affectations sont décidées par l'Assistant Technique depuis
/// l'administration Laravel (à venir) et synchronisées vers l'appareil.
/// L'animateur ne peut ni s'attribuer, ni retirer, ni créer de CLD depuis
/// l'application mobile.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _cldRepository = CldRepository();
  late Future<List<CldWithLocation>> _cldsFuture;

  @override
  void initState() {
    super.initState();
    _cldsFuture = _loadClds();
  }

  Future<List<CldWithLocation>> _loadClds() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return [];
    return _cldRepository.getByUserWithLocation(userId);
  }

  Future<void> _logout(BuildContext context) async {
    final apiAuthProvider = context.read<ApiAuthProvider>();
    final authProvider = context.read<AuthProvider>();
    await apiAuthProvider.logout();
    await authProvider.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final photoPath = user?.photoProfil;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundImage: (photoPath != null && File(photoPath).existsSync())
                  ? FileImage(File(photoPath))
                  : null,
              child: (photoPath == null || !File(photoPath).existsSync())
                  ? const Icon(Icons.person_outline, size: 44)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.fullName ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Nom'),
                  subtitle: Text(user?.nom ?? '-'),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Post-nom'),
                  subtitle: Text(user?.postNom ?? '-'),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Prénom'),
                  subtitle: Text(user?.prenom ?? '-'),
                ),
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: const Text('Fonction'),
                  subtitle: Text(_fonctionLabel(user?.fonction)),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Téléphone'),
                  subtitle: Text(user?.telephone ?? 'Non renseigné'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Mes CLD', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<CldWithLocation>>(
            future: _cldsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final clds = snapshot.data!;
              if (clds.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aucun CLD ne vous a encore été affecté.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: clds
                      .map(
                        (item) => ListTile(
                          leading: const Icon(Icons.groups_outlined),
                          title: Text(item.cld.nom),
                          subtitle: Text('${item.groupementName} — ${item.secteurName}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => VillagesScreen(cld: item.cld)),
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier mon profil'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.syncStatus),
            icon: const Icon(Icons.sync_outlined),
            label: const Text('État de synchronisation'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 3),
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
}
