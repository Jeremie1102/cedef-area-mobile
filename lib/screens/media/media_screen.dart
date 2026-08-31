import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/media_repository.dart';
import '../../services/media_sync_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/main_bottom_nav.dart';
import 'media_batch_detail_screen.dart';
import 'new_media_batch_screen.dart';

/// Liste des lots de médias de l'agent connecté (« Mes lots de médias »).
///
/// On n'affiche jamais les photos individuellement : chaque lot représente
/// une activité et regroupe les photos qui l'illustrent. Affiche aussi
/// l'action de synchronisation manuelle des lots en attente (section 26 du
/// cahier des charges) — priorité donnée au déclenchement manuel, fiable,
/// plutôt qu'à une synchronisation automatique complexe.
class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  final _mediaRepository = MediaRepository();
  late Future<List<MediaBatchSummary>> _batchesFuture;

  @override
  void initState() {
    super.initState();
    _batchesFuture = _loadBatches();
  }

  Future<List<MediaBatchSummary>> _loadBatches() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return [];
    return _mediaRepository.getBatchSummariesByUser(userId);
  }

  void _refresh() {
    setState(() => _batchesFuture = _loadBatches());
  }

  Future<void> _syncNow() async {
    final summary = await MediaSyncService.instance.syncPendingBatches();
    if (!mounted) return;
    _refresh();

    final message = switch (summary.outcome) {
      MediaSyncOutcome.offline => 'Aucune connexion Internet disponible.',
      MediaSyncOutcome.alreadyRunning => 'Une synchronisation est déjà en cours.',
      MediaSyncOutcome.sessionExpired =>
        'Session expirée. Veuillez vous reconnecter pour continuer la synchronisation.',
      MediaSyncOutcome.completed => summary.failed == 0
          ? '${summary.synced} lot(s) synchronisé(s).'
          : '${summary.synced} synchronisé(s), ${summary.failed} en échec.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ouvre l'écran de création : aucune mission n'est présupposée ici (voir
  /// `NewMediaBatchScreen`, qui fait choisir la mission explicitement parmi
  /// celles de l'agent — la résolution de son territoire, elle, vit
  /// entièrement dans cet écran).
  Future<void> _createBatch() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const NewMediaBatchScreen()));
    if (created == true) _refresh();
  }

  Future<void> _openBatch(MediaBatchSummary summary) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MediaBatchDetailScreen(batch: summary.batch)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes lots de médias')),
      body: FutureBuilder<List<MediaBatchSummary>>(
        future: _batchesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final batches = snapshot.data!;
          final pending = batches.where((b) => b.batch.syncStatus != SyncStatus.synced).length;

          return Column(
            children: [
              _SyncBanner(pendingCount: pending, onSync: _syncNow),
              Expanded(
                child: batches.isEmpty
                    ? const EmptyState(
                        icon: Icons.photo_library_outlined,
                        message: 'Aucun lot de médias enregistré pour le moment.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: batches.length,
                          itemBuilder: (context, index) => _BatchCard(
                            summary: batches[index],
                            onTap: () => _openBatch(batches[index]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBatch,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Nouveau lot'),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 2),
    );
  }
}

/// Bandeau « N en attente / Synchroniser » (section 26) : n'apparaît que
/// lorsqu'au moins un lot n'est pas encore synchronisé.
class _SyncBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onSync;

  const _SyncBanner({required this.pendingCount, required this.onSync});

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$pendingCount lot${pendingCount > 1 ? 's' : ''} en attente de synchronisation',
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: MediaSyncService.instance.isSyncingNotifier,
                builder: (context, isSyncing, _) {
                  return FilledButton.icon(
                    onPressed: isSyncing ? null : onSync,
                    icon: isSyncing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(isSyncing ? 'Synchronisation…' : 'Synchroniser'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final MediaBatchSummary summary;
  final VoidCallback onTap;

  const _BatchCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final batch = summary.batch;
    final coverPath = summary.coverPath;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: (coverPath != null && File(coverPath).existsSync())
                ? Image.file(File(coverPath), fit: BoxFit.cover)
                : Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.photo_library_outlined),
                  ),
          ),
        ),
        title: Text(batch.activity ?? 'Sans activité'),
        subtitle: Text(
          [
            if (summary.cldName != null) summary.cldName!,
            if (summary.villageName != null) 'Village : ${summary.villageName}',
            '${summary.itemCount} photo${summary.itemCount > 1 ? 's' : ''}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: _SyncStatusIcon(status: batch.syncStatus),
        onTap: onTap,
      ),
    );
  }
}

/// Icône représentant l'un des quatre statuts de synchronisation d'un lot
/// (section 25 : 🟠 en attente, 🔵 synchronisation, 🟢 synchronisé, 🔴 échec).
class _SyncStatusIcon extends StatelessWidget {
  final SyncStatus status;

  const _SyncStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done, Colors.green),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, Colors.blue),
      SyncStatus.failed => (Icons.cloud_off, Colors.red),
      SyncStatus.pending => (Icons.cloud_upload_outlined, Colors.orange),
    };
    return Icon(icon, color: color);
  }
}
