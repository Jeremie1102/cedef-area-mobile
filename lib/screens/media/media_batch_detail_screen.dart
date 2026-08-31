import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../models/cld.dart';
import '../../models/media_batch.dart';
import '../../models/media_item.dart';
import '../../models/village.dart';
import '../../repositories/cld_repository.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/village_repository.dart';
import '../../services/media_service.dart';
import '../../services/media_sync_service.dart';
import 'edit_media_batch_screen.dart';
import 'photo_viewer_screen.dart';

/// Détail d'un lot : ses informations de contexte et l'ensemble de ses
/// photos. Tant que le lot n'est pas synchronisé, il peut être modifié ou
/// supprimé depuis cet écran ; une fois synchronisé, il n'est plus
/// consultable qu'en lecture seule.
class MediaBatchDetailScreen extends StatefulWidget {
  final MediaBatch batch;

  const MediaBatchDetailScreen({super.key, required this.batch});

  @override
  State<MediaBatchDetailScreen> createState() => _MediaBatchDetailScreenState();
}

class _MediaBatchDetailScreenState extends State<MediaBatchDetailScreen> {
  final _mediaRepository = MediaRepository();
  final _mediaService = MediaService();
  final _cldRepository = CldRepository();
  final _villageRepository = VillageRepository();

  late MediaBatch _batch;

  late Future<List<MediaItem>> _itemsFuture;
  late Future<_BatchContext> _contextFuture;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    _itemsFuture = _mediaRepository.getItemsByBatch(_batch.id!);
    _contextFuture = _loadContext();
  }

  Future<_BatchContext> _loadContext() async {
    final cldId = _batch.cldId;
    final villageId = _batch.villageId;
    final cld = cldId != null ? await _cldRepository.getById(cldId) : null;
    final village = villageId != null ? await _villageRepository.getById(villageId) : null;
    return _BatchContext(cld: cld, village: village);
  }

  Future<void> _refresh() async {
    final refreshed = await _mediaRepository.getBatchById(_batch.id!);
    if (!mounted || refreshed == null) return;
    setState(() {
      _batch = refreshed;
      _itemsFuture = _mediaRepository.getItemsByBatch(_batch.id!);
      _contextFuture = _loadContext();
    });
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditMediaBatchScreen(batch: _batch)),
    );
    await _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce lot'),
        content: const Text(
          'Voulez-vous vraiment supprimer ce lot ? Les photos originales de la galerie ne seront pas affectées.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _mediaService.deleteBatch(_batch);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Impossible de supprimer ce lot.')));
    }
  }

  Future<void> _retrySync() async {
    final summary = await MediaSyncService.instance.syncPendingBatches();
    await _refresh();
    if (!mounted) return;

    final message = switch (summary.outcome) {
      MediaSyncOutcome.offline => 'Aucune connexion Internet disponible.',
      MediaSyncOutcome.alreadyRunning => 'Une synchronisation est déjà en cours.',
      MediaSyncOutcome.sessionExpired =>
        'Session expirée. Veuillez vous reconnecter pour continuer la synchronisation.',
      MediaSyncOutcome.completed => summary.failed == 0
          ? 'Lot synchronisé.'
          : 'Échec de la synchronisation. Réessayez plus tard.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSyncTile(SyncStatus status) {
    final (icon, color, label) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done, Colors.green, 'Synchronisé'),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, Colors.blue, 'Synchronisation…'),
      SyncStatus.failed => (Icons.cloud_off, Colors.red, 'Échec de la synchronisation'),
      SyncStatus.pending => (Icons.cloud_upload_outlined, Colors.orange, 'En attente de synchronisation'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: const Text('Synchronisation'),
        subtitle: Text(label),
        trailing: status == SyncStatus.failed
            ? TextButton(onPressed: _retrySync, child: const Text('Réessayer'))
            : null,
      ),
    );
  }

  void _previewItemAt(List<MediaItem> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          paths: items.map((i) => i.localPath).toList(),
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    final canModify = batch.syncStatus != SyncStatus.synced;

    return Scaffold(
      appBar: AppBar(
        title: Text(batch.activity ?? 'Lot de médias'),
        actions: canModify
            ? [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
              ]
            : null,
      ),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoTile(icon: Icons.category_outlined, label: 'Activité', value: batch.activity ?? '-'),
            _InfoTile(
              icon: Icons.event_outlined,
              label: 'Date de l\'activité',
              value: AppDateUtils.frenchDate(batch.capturedAt),
            ),
            FutureBuilder<_BatchContext>(
              future: _contextFuture,
              builder: (context, snapshot) {
                final ctx = snapshot.data;
                return Column(
                  children: [
                    _InfoTile(icon: Icons.groups_outlined, label: 'CLD', value: ctx?.cld?.nom ?? '-'),
                    _InfoTile(
                      icon: Icons.holiday_village_outlined,
                      label: 'Village',
                      value: ctx?.village?.nom ?? '-',
                    ),
                  ],
                );
              },
            ),
            _InfoTile(
              icon: Icons.description_outlined,
              label: 'Description',
              value: batch.description?.isNotEmpty == true ? batch.description! : 'Aucune description.',
            ),
            _InfoTile(
              icon: Icons.location_on_outlined,
              label: 'Localisation',
              value: batch.latitude != null && batch.longitude != null
                  ? '${batch.latitude!.toStringAsFixed(5)}, ${batch.longitude!.toStringAsFixed(5)}'
                        '${batch.gpsAccuracy != null ? ' (± ${batch.gpsAccuracy!.round()} m)' : ''}'
                  : 'Localisation non disponible.',
            ),
            _buildSyncTile(batch.syncStatus),
            const SizedBox(height: 16),
            FutureBuilder<List<MediaItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!;
                final totalMb = items.fold<int>(0, (sum, i) => sum + i.fileSize) / (1024 * 1024);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} photo${items.length > 1 ? 's' : ''}'
                      '${totalMb > 0 ? ' — ${totalMb.toStringAsFixed(1).replaceAll('.', ',')} Mo' : ''}',
                      style: Theme.of(context).textTheme.titleMedium,
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
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final file = File(items[index].localPath);
                        return GestureDetector(
                          onTap: () => _previewItemAt(items, index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.image_not_supported_outlined),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
    );
  }
}

class _BatchContext {
  final Cld? cld;
  final Village? village;

  const _BatchContext({this.cld, this.village});
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
