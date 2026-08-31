import 'package:flutter/material.dart';

import '../../models/cld.dart';
import '../../models/groupement.dart';
import '../../repositories/cld_repository.dart';
import '../../widgets/empty_state.dart';
import 'villages_screen.dart';

/// Liste des CLD d'un groupement donné.
class CldsScreen extends StatefulWidget {
  final Groupement groupement;

  const CldsScreen({super.key, required this.groupement});

  @override
  State<CldsScreen> createState() => _CldsScreenState();
}

class _CldsScreenState extends State<CldsScreen> {
  final _cldRepository = CldRepository();
  late Future<List<Cld>> _cldsFuture;

  @override
  void initState() {
    super.initState();
    _cldsFuture = _cldRepository.getByGroupement(widget.groupement.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupement.nom)),
      body: FutureBuilder<List<Cld>>(
        future: _cldsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final clds = snapshot.data!;
          if (clds.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              message: 'Aucun CLD enregistré pour ce groupement.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: clds.length,
            itemBuilder: (context, index) {
              final cld = clds[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(cld.nom),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VillagesScreen(cld: cld)),
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
