import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../database/database_tables.dart';
import '../../models/sync_queue_entry.dart';
import '../../providers/connectivity_provider.dart';
import '../../repositories/gps_repository.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/mission_repository.dart';
import '../../repositories/sync_queue_repository.dart';
import '../../services/sync_service.dart';

class _SyncCounts {
  final DateTime? lastSyncedAt;
  final int pendingMissions;
  final int pendingGps;
  final int pendingMediaBatches;
  final int pendingMediaItems;
  final List<SyncQueueEntry> history;

  const _SyncCounts({
    required this.lastSyncedAt,
    required this.pendingMissions,
    required this.pendingGps,
    required this.pendingMediaBatches,
    required this.pendingMediaItems,
    required this.history,
  });

  int get totalPending => pendingMissions + pendingGps + pendingMediaBatches + pendingMediaItems;
}

/// Écran « Synchronisation » : état de connexion, date de la dernière
/// synchronisation, éléments en attente (comptés depuis SQLite, jamais de
/// valeur fictive) et journal des dernières opérations traitées.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final _syncQueueRepository = SyncQueueRepository();
  final _missionRepository = MissionRepository();
  final _gpsRepository = GpsRepository();
  final _mediaRepository = MediaRepository();

  late Future<_SyncCounts> _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
  }

  Future<_SyncCounts> _loadCounts() async {
    final results = await Future.wait([
      _syncQueueRepository.getLastSyncedAt(),
      _missionRepository.countPendingSync(),
      _gpsRepository.countPendingOrFailedSync(),
      _mediaRepository.countPendingOrFailedSyncBatches(),
      _mediaRepository.countPendingSyncItems(),
      _syncQueueRepository.getRecentHistory(),
    ]);

    return _SyncCounts(
      lastSyncedAt: results[0] as DateTime?,
      pendingMissions: results[1] as int,
      pendingGps: results[2] as int,
      pendingMediaBatches: results[3] as int,
      pendingMediaItems: results[4] as int,
      history: results[5] as List<SyncQueueEntry>,
    );
  }

  void _refresh() {
    setState(() => _countsFuture = _loadCounts());
  }

  Future<void> _syncNow() async {
    final summary = await SyncService.instance.syncAll();
    if (!mounted) return;
    _refresh();

    final message = switch (summary.outcome) {
      SyncOutcome.offline => 'Aucune connexion Internet disponible.',
      SyncOutcome.alreadyRunning => 'Une synchronisation est déjà en cours.',
      SyncOutcome.completed => summary.failed == 0
          ? '${summary.uploaded} élément(s) synchronisé(s).'
          : '${summary.uploaded} synchronisé(s), ${summary.failed} en échec.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
                title: const Text('Connexion'),
                subtitle: Text(isOnline ? 'Internet disponible' : 'Hors ligne'),
              ),
            ),
            FutureBuilder<_SyncCounts>(
              future: _countsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final counts = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.history_outlined),
                        title: const Text('Dernière synchronisation'),
                        subtitle: Text(
                          counts.lastSyncedAt != null
                              ? AppDateUtils.frenchDateTime(counts.lastSyncedAt!)
                              : 'Jamais synchronisé.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  counts.totalPending == 0
                                      ? Icons.check_circle_outline
                                      : Icons.hourglass_empty,
                                  color: counts.totalPending == 0 ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  counts.totalPending == 0
                                      ? 'Tout est synchronisé'
                                      : '${counts.totalPending} élément(s) en attente',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (counts.pendingMissions > 0)
                              _PendingLine(label: 'Missions', count: counts.pendingMissions),
                            if (counts.pendingGps > 0)
                              _PendingLine(label: 'Positions GPS', count: counts.pendingGps),
                            if (counts.pendingMediaBatches > 0)
                              _PendingLine(label: 'Lots de médias', count: counts.pendingMediaBatches),
                            if (counts.pendingMediaItems > 0)
                              _PendingLine(label: 'Photos', count: counts.pendingMediaItems),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<SyncRunState>(
                      valueListenable: SyncService.instance.stateNotifier,
                      builder: (context, state, _) {
                        final isSyncing = state == SyncRunState.syncing;
                        return FilledButton.icon(
                          onPressed: isSyncing ? null : _syncNow,
                          icon: isSyncing
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync),
                          label: Text(isSyncing ? 'Synchronisation…' : 'Synchroniser maintenant'),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Journal', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (counts.history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Aucune opération traitée pour le moment.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: counts.history.map((entry) => _HistoryTile(entry: entry)).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingLine extends StatelessWidget {
  final String label;
  final int count;

  const _PendingLine({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text('$count', style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SyncQueueEntry entry;

  const _HistoryTile({required this.entry});

  String get _entityLabel {
    switch (entry.entityTable) {
      case DatabaseTables.missions:
        return 'Mission';
      case DatabaseTables.gpsPositions:
        return 'Position GPS';
      case DatabaseTables.mediaBatches:
        return 'Lot de médias';
      case DatabaseTables.mediaItems:
        return 'Photo';
      case DatabaseTables.users:
        return 'Profil';
      default:
        return entry.entityTable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSynced = entry.status == SyncStatus.synced;
    return ListTile(
      leading: Icon(
        isSynced ? Icons.check_circle_outline : Icons.error_outline,
        color: isSynced ? Colors.green : Colors.red,
      ),
      title: Text('$_entityLabel — ${entry.operation.value}'),
      subtitle: Text(
        isSynced
            ? AppDateUtils.frenchDateTime(entry.updatedAt)
            : (entry.lastError ?? 'Échec de synchronisation.'),
      ),
      dense: true,
    );
  }
}
