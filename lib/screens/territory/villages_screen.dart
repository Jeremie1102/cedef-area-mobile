import 'package:flutter/material.dart';

import '../../models/cld.dart';
import '../../models/groupement.dart';
import '../../models/secteur.dart';
import '../../models/village.dart';
import '../../repositories/groupement_repository.dart';
import '../../repositories/secteur_repository.dart';
import '../../repositories/village_repository.dart';
import '../../widgets/empty_state.dart';

/// Détail d'un CLD : son groupement/secteur de rattachement, et la liste de
/// ses villages (dernier niveau de la hiérarchie territoriale, consultation
/// uniquement).
class VillagesScreen extends StatefulWidget {
  final Cld cld;

  const VillagesScreen({super.key, required this.cld});

  @override
  State<VillagesScreen> createState() => _VillagesScreenState();
}

class _VillagesScreenState extends State<VillagesScreen> {
  final _villageRepository = VillageRepository();
  final _groupementRepository = GroupementRepository();
  final _secteurRepository = SecteurRepository();

  late Future<List<Village>> _villagesFuture;
  late Future<_Location?> _locationFuture;

  @override
  void initState() {
    super.initState();
    _villagesFuture = _villageRepository.getByCld(widget.cld.id!);
    _locationFuture = _loadLocation();
  }

  Future<_Location?> _loadLocation() async {
    final groupement = await _groupementRepository.getById(widget.cld.groupementId);
    if (groupement == null) return null;
    final secteur = await _secteurRepository.getById(groupement.secteurId);
    if (secteur == null) return null;
    return _Location(groupement: groupement, secteur: secteur);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cld.nom)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<_Location?>(
            future: _locationFuture,
            builder: (context, snapshot) {
              final location = snapshot.data;
              if (location == null) return const SizedBox.shrink();
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: const Text('Groupement'),
                      subtitle: Text(location.groupement.nom),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Secteur'),
                      subtitle: Text(location.secteur.nom),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Villages', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<Village>>(
            future: _villagesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final villages = snapshot.data!;
              if (villages.isEmpty) {
                return const EmptyState(
                  icon: Icons.holiday_village_outlined,
                  message: 'Aucun village enregistré pour ce CLD.',
                );
              }

              return Column(
                children: villages
                    .map(
                      (village) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.holiday_village_outlined),
                          title: Text(village.nom),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Location {
  final Groupement groupement;
  final Secteur secteur;

  const _Location({required this.groupement, required this.secteur});
}
