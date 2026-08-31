import 'package:flutter/material.dart';

import '../../database/seed/demo_data_seeder.dart';
import '../../models/cld.dart';
import '../../models/groupement.dart';
import '../../models/secteur.dart';
import '../../models/village.dart';
import '../../repositories/cld_repository.dart';
import '../../repositories/groupement_repository.dart';
import '../../repositories/secteur_repository.dart';
import '../../repositories/village_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import 'clds_screen.dart';
import 'groupements_screen.dart';
import 'villages_screen.dart';

/// Point d'entrée du module Territoire : liste des secteurs avec leurs
/// statistiques (nombre de groupements/villages/CLD), et recherche globale
/// (secteur, groupement, CLD ou village) fonctionnant entièrement hors ligne.
///
/// Hiérarchie : Secteur > Groupement > CLD > Village. Consultation
/// uniquement : ces données proviennent de Laravel (ou, pour les tests, du
/// jeu de données de démonstration), jamais d'une création locale.
class TerritoryScreen extends StatefulWidget {
  const TerritoryScreen({super.key});

  @override
  State<TerritoryScreen> createState() => _TerritoryScreenState();
}

class _TerritoryScreenState extends State<TerritoryScreen> {
  final _secteurRepository = SecteurRepository();
  final _groupementRepository = GroupementRepository();
  final _cldRepository = CldRepository();
  final _villageRepository = VillageRepository();

  late Future<List<SecteurStats>> _statsFuture;
  String _query = '';
  bool _searching = false;
  _SearchResults? _searchResults;

  @override
  void initState() {
    super.initState();
    _statsFuture = _secteurRepository.getAllWithStats();
  }

  void _refresh() {
    setState(() => _statsFuture = _secteurRepository.getAllWithStats());
  }

  Future<void> _seedDemoData() async {
    await DemoDataSeeder.seedIfEmpty();
    _refresh();
  }

  Future<void> _onQueryChanged(String query) async {
    setState(() {
      _query = query;
      _searching = query.trim().isNotEmpty;
    });

    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }

    final results = _SearchResults(
      secteurs: await _secteurRepository.search(query),
      groupements: await _groupementRepository.search(query),
      clds: await _cldRepository.search(query),
      villages: await _villageRepository.search(query),
    );

    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  void _openSecteur(Secteur secteur) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupementsScreen(secteur: secteur)));
  }

  void _openGroupement(Groupement groupement) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CldsScreen(groupement: groupement)));
  }

  void _openCld(Cld cld) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VillagesScreen(cld: cld)));
  }

  Future<void> _openVillageParentCld(int cldId) async {
    final cld = await _cldRepository.getById(cldId);
    if (cld == null || !mounted) return;
    _openCld(cld);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Territoire / CLD')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchField(
              hintText: 'Rechercher un secteur, groupement, CLD ou village…',
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _searching
                  ? _buildSearchResults()
                  : _buildSecteursList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message: 'Aucun résultat pour « $_query ».',
      );
    }

    return ListView(
      children: [
        ..._sectionResults(
          title: 'Secteurs',
          icon: Icons.location_on_outlined,
          items: results.secteurs,
          labelBuilder: (s) => s.nom,
          onTap: (s) => _openSecteur(s),
        ),
        ..._sectionResults(
          title: 'Groupements',
          icon: Icons.map_outlined,
          items: results.groupements,
          labelBuilder: (g) => g.nom,
          onTap: (g) => _openGroupement(g),
        ),
        ..._sectionResults(
          title: 'CLD',
          icon: Icons.groups_outlined,
          items: results.clds,
          labelBuilder: (c) => c.nom,
          onTap: (c) => _openCld(c),
        ),
        ..._sectionResults(
          title: 'Villages',
          icon: Icons.holiday_village_outlined,
          items: results.villages,
          labelBuilder: (v) => v.nom,
          onTap: (v) => _openVillageParentCld(v.cldId),
        ),
      ],
    );
  }

  List<Widget> _sectionResults<T>({
    required String title,
    required IconData icon,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T) onTap,
  }) {
    if (items.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      ...items.map(
        (item) => Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(labelBuilder(item)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(item),
          ),
        ),
      ),
    ];
  }

  Widget _buildSecteursList() {
    return FutureBuilder<List<SecteurStats>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        if (stats.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  icon: Icons.location_on_outlined,
                  message:
                      'Aucun secteur enregistré pour le moment.\nCes données proviendront normalement de Laravel.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _seedDemoData,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Charger des données de démonstration'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(item.secteur.nom),
                subtitle: Text(
                  '${item.groupementsCount} groupements • '
                  '${item.cldsCount} CLD • '
                  '${item.villagesCount} villages',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSecteur(item.secteur),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchResults {
  final List<Secteur> secteurs;
  final List<Groupement> groupements;
  final List<Cld> clds;
  final List<Village> villages;

  const _SearchResults({
    required this.secteurs,
    required this.groupements,
    required this.clds,
    required this.villages,
  });

  bool get isEmpty =>
      secteurs.isEmpty && groupements.isEmpty && clds.isEmpty && villages.isEmpty;
}
