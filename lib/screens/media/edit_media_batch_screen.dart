import 'dart:io';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../models/media_batch.dart';
import '../../models/media_item.dart';
import '../../models/village.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/village_repository.dart';
import '../../services/media_service.dart';
import 'photo_viewer_screen.dart';

/// Modification d'un lot déjà enregistré : activité, description, village,
/// ajout et retrait de photos. N'est jamais accessible pour un lot déjà
/// synchronisé (voir `MediaBatchDetailScreen`) — le CLD, la mission et le
/// territoire d'un lot ne se corrigent pas ici, seulement le village.
class EditMediaBatchScreen extends StatefulWidget {
  final MediaBatch batch;

  const EditMediaBatchScreen({super.key, required this.batch});

  @override
  State<EditMediaBatchScreen> createState() => _EditMediaBatchScreenState();
}

class _EditMediaBatchScreenState extends State<EditMediaBatchScreen> {
  final _mediaRepository = MediaRepository();
  final _mediaService = MediaService();
  final _villageRepository = VillageRepository();

  late final TextEditingController _descriptionController;
  late final TextEditingController _customActivityController;

  String? _activity;
  Village? _selectedVillage;
  List<Village> _villages = [];
  List<MediaItem> _items = [];

  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final batch = widget.batch;
    final knownActivity = ActivityCategories.all.contains(batch.activity);
    _activity = knownActivity ? batch.activity : (batch.activity != null ? 'Autre' : null);
    _descriptionController = TextEditingController(text: batch.description ?? '');
    _customActivityController = TextEditingController(text: knownActivity ? '' : (batch.activity ?? ''));
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _customActivityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _mediaRepository.getItemsByBatch(widget.batch.id!);
    final villages = widget.batch.cldId != null
        ? await _villageRepository.getByCld(widget.batch.cldId!)
        : <Village>[];
    if (!mounted) return;
    setState(() {
      _items = items;
      _villages = villages;
      _selectedVillage = villages
          .where((v) => v.id == widget.batch.villageId)
          .cast<Village?>()
          .firstOrNull;
      _loading = false;
    });
  }

  void _previewItemAt(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          paths: _items.map((i) => i.localPath).toList(),
          initialIndex: index,
        ),
      ),
    );
  }

  Future<void> _addPhotos() async {
    if (_items.length >= AppConfig.mediaBatchMaxPhotos) {
      _showMessage('Ce lot contient déjà le maximum de ${AppConfig.mediaBatchMaxPhotos} photos.');
      return;
    }
    final remaining = AppConfig.mediaBatchMaxPhotos - _items.length;
    final picked = await _mediaService.pickPhotosFromGallery(limit: remaining);
    if (picked.isEmpty) return;
    try {
      await _mediaService.addPhotosToBatch(
        batchId: widget.batch.id!,
        batchLocalId: widget.batch.localId,
        photos: picked,
        startSortOrder: _items.length,
      );
    } catch (e) {
      _showMessage(e is AppException ? e.message : 'Impossible d\'ajouter ces photos.');
      return;
    }
    final items = await _mediaRepository.getItemsByBatch(widget.batch.id!);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _removeItem(MediaItem item) async {
    if (_items.length <= 1) {
      _showMessage('Un lot doit contenir au moins une photo.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cette photo'),
        content: const Text(
          'Cette photo sera retirée du lot. La photo originale de la galerie n\'est pas supprimée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Retirer')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _mediaService.removeItem(item);
    if (!mounted) return;
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
  }

  Future<void> _save() async {
    if (_activity == null) {
      _showMessage('Renseignez l\'activité.');
      return;
    }
    if (_activity == 'Autre' && _customActivityController.text.trim().isEmpty) {
      _showMessage('Précisez l\'activité dans le champ prévu.');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showMessage('La description du lot est obligatoire.');
      return;
    }

    final activityValue = _activity == 'Autre' ? _customActivityController.text.trim() : _activity;

    setState(() => _isSaving = true);
    try {
      await _mediaService.updateBatch(
        widget.batch.copyWith(
          activity: activityValue,
          description: _descriptionController.text.trim(),
          villageId: _selectedVillage?.id,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(
        e is AppException ? e.message : 'Impossible d\'enregistrer les modifications.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le lot')),
      body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_items.length} photo${_items.length > 1 ? 's' : ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: _addPhotos,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final file = File(item.localPath);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GestureDetector(
                                  onTap: () => _previewItemAt(index),
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : Container(
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.image_not_supported_outlined),
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeItem(item),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: _activity,
                        decoration: const InputDecoration(
                          labelText: 'Activité',
                          border: OutlineInputBorder(),
                        ),
                        items: ActivityCategories.all
                            .map((activity) => DropdownMenuItem(value: activity, child: Text(activity)))
                            .toList(),
                        onChanged: (value) => setState(() => _activity = value),
                      ),
                      if (_activity == 'Autre') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _customActivityController,
                          decoration: const InputDecoration(
                            labelText: 'Précisez l\'activité',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Village>(
                        initialValue: _selectedVillage,
                        decoration: const InputDecoration(
                          labelText: 'Village',
                          border: OutlineInputBorder(),
                        ),
                        items: _villages
                            .map((village) => DropdownMenuItem(value: village, child: Text(village.nom)))
                            .toList(),
                        onChanged: _villages.isEmpty
                            ? null
                            : (value) => setState(() => _selectedVillage = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: AppConfig.mediaBatchDescriptionMaxLength,
                        decoration: const InputDecoration(
                          labelText: 'Description du lot *',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enregistrer les modifications'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
