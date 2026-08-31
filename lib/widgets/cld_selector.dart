import 'package:flutter/material.dart';

import '../repositories/cld_repository.dart';
import 'search_field.dart';

/// Composant réutilisable de sélection d'un CLD (avec recherche), destiné à
/// être utilisé partout où un CLD doit être rattaché à une donnée créée par
/// l'animateur (mission, photo, activité terrain, rapport de mission) — pas
/// pour lui permettre de créer ou de s'attribuer un CLD, ce que
/// l'application ne propose jamais.
///
/// Ne propose jamais que les CLD affectés à [userId] (voir
/// `CldRepository.getByUserWithLocation`/`searchByUserWithLocation`) : un
/// agent ne doit jamais pouvoir rattacher une donnée à un CLD hors de son
/// affectation.
class CldSelector extends StatelessWidget {
  final String label;
  final CldWithLocation? selected;
  final ValueChanged<CldWithLocation> onSelected;
  final int userId;

  const CldSelector({
    super.key,
    this.label = 'Sélectionner un CLD',
    this.selected,
    required this.onSelected,
    required this.userId,
  });

  /// Ouvre le sélecteur de CLD (recherche incluse) sans avoir besoin
  /// d'afficher le champ [CldSelector] lui-même.
  static Future<CldWithLocation?> pick(BuildContext context, {required int userId}) {
    return showModalBottomSheet<CldWithLocation>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CldPickerSheet(userId: userId),
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await pick(context, userId: userId);
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(
          selected != null
              ? '${selected!.cld.nom} — ${selected!.groupementName}, ${selected!.secteurName}'
              : 'Choisir…',
          style: selected == null ? TextStyle(color: Theme.of(context).hintColor) : null,
        ),
      ),
    );
  }
}

class _CldPickerSheet extends StatefulWidget {
  final int userId;

  const _CldPickerSheet({required this.userId});

  @override
  State<_CldPickerSheet> createState() => _CldPickerSheetState();
}

class _CldPickerSheetState extends State<_CldPickerSheet> {
  final _cldRepository = CldRepository();
  List<CldWithLocation> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String query) async {
    setState(() => _loading = true);
    final results = query.isEmpty
        ? await _cldRepository.getByUserWithLocation(widget.userId)
        : await _cldRepository.searchByUserWithLocation(widget.userId, query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sélectionner un CLD', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SearchField(hintText: 'Rechercher un CLD, un groupement ou un secteur…', onChanged: _load),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? const Center(child: Text('Aucun CLD trouvé.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(item.cld.nom),
                            subtitle: Text('${item.groupementName} — ${item.secteurName}'),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
