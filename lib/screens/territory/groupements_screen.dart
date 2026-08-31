import 'package:flutter/material.dart';

import '../../models/secteur.dart';
import '../../models/groupement.dart';
import '../../repositories/groupement_repository.dart';
import '../../widgets/empty_state.dart';
import 'clds_screen.dart';

/// Liste des groupements d'un secteur donné.
class GroupementsScreen extends StatefulWidget {
  final Secteur secteur;

  const GroupementsScreen({super.key, required this.secteur});

  @override
  State<GroupementsScreen> createState() => _GroupementsScreenState();
}

class _GroupementsScreenState extends State<GroupementsScreen> {
  final _groupementRepository = GroupementRepository();
  late Future<List<Groupement>> _groupementsFuture;

  @override
  void initState() {
    super.initState();
    _groupementsFuture = _groupementRepository.getBySecteur(widget.secteur.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.secteur.nom)),
      body: FutureBuilder<List<Groupement>>(
        future: _groupementsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupements = snapshot.data!;
          if (groupements.isEmpty) {
            return const EmptyState(
              icon: Icons.map_outlined,
              message: 'Aucun groupement enregistré pour ce secteur.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupements.length,
            itemBuilder: (context, index) {
              final groupement = groupements[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(groupement.nom),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CldsScreen(groupement: groupement)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
