import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/gps_repository.dart';
import '../../services/gps_service.dart';
import '../../services/gps_sync_service.dart';
import '../../services/mission_service.dart';
import '../../widgets/empty_state.dart';
import 'track_detail_screen.dart';

/// Liste des parcours GPS enregistrés localement par l'agent connecté, un
/// par mission ayant au moins une position enregistrée (section 28 du
/// cahier des charges). Consultable hors connexion : tout provient de
/// SQLite, aucun appel réseau. Affiche aussi l'action de synchronisation
/// manuelle des positions en attente (section 31/32) — priorité au bouton
/// manuel, fiable, plutôt qu'à une synchronisation automatique complexe.
class MyTracksScreen extends StatefulWidget {
  const MyTracksScreen({super.key});

  @override
  State<MyTracksScreen> createState() => _MyTracksScreenState();
}

class _MyTracksScreenState extends State<MyTracksScreen> {
  final _missionService = MissionService();
  final _gpsRepository = GpsRepository();
  late Future<List<MissionTrack>> _tracksFuture;
  late Future<int> _pendingCountFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _loadTracks();
    _pendingCountFuture = _gpsRepository.countPendingOrFailedSync();
  }

  Future<List<MissionTrack>> _loadTracks() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return [];
    return _missionService.getMyTracks(userId);
  }

  void _refresh() {
    setState(() {
      _tracksFuture = _loadTracks();
      _pendingCountFuture = _gpsRepository.countPendingOrFailedSync();
    });
  }

  Future<void> _openTrack(MissionTrack track) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TrackDetailScreen(missionId: track.mission.id!)));
    _refresh();
  }

  Future<void> _syncNow() async {
    final summary = await GpsSyncService.instance.syncPendingPositions();
    if (!mounted) return;
    _refresh();

    final message = switch (summary.outcome) {
      GpsSyncOutcome.offline => 'Aucune connexion Internet disponible.',
      GpsSyncOutcome.alreadyRunning => 'Une synchronisation est déjà en cours.',
      GpsSyncOutcome.sessionExpired =>
        'Session expirée. Veuillez vous reconnecter pour continuer la synchronisation.',
      GpsSyncOutcome.completed => _completedMessage(summary),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _completedMessage(GpsSyncSummary summary) {
    if (summary.synced == 0 && summary.alreadySynced == 0 && summary.rejected == 0 && summary.failed == 0) {
      return 'Aucune position à synchroniser.';
    }
    final parts = <String>[];
    if (summary.synced > 0) parts.add('${summary.synced} synchronisée(s)');
    if (summary.alreadySynced > 0) parts.add('${summary.alreadySynced} déjà synchronisée(s)');
    if (summary.rejected > 0) parts.add('${summary.rejected} rejetée(s)');
    if (summary.failed > 0) parts.add('${summary.failed} en échec');
    return '${parts.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes parcours')),
      body: FutureBuilder<List<MissionTrack>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tracks = snapshot.data!;

          return Column(
            children: [
              _GpsSyncBanner(pendingCountFuture: _pendingCountFuture, onSync: _syncNow),
              Expanded(
                child: tracks.isEmpty
                    ? const EmptyState(
                        icon: Icons.route_outlined,
                        message: 'Aucun parcours enregistré pour le moment.\n'
                            'Un parcours apparaît ici dès qu\'une mission démarre le suivi GPS.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tracks.length,
                        itemBuilder: (context, index) => _buildCard(tracks[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(MissionTrack track) {
    final summary = track.summary;
    final distanceKm = summary.distanceMeters != null ? summary.distanceMeters! / 1000 : null;
    final duration = (summary.firstRecordedAt != null && summary.lastRecordedAt != null)
        ? summary.lastRecordedAt!.difference(summary.firstRecordedAt!)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.route_outlined),
        title: Text(track.mission.titre),
        subtitle: Text(
          [
            if (summary.firstRecordedAt != null) AppDateUtils.frenchDate(summary.firstRecordedAt!),
            '${summary.positionCount} position${summary.positionCount > 1 ? 's' : ''}',
            if (distanceKm != null && distanceKm > 0)
              '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
            if (duration != null) _formatDuration(duration),
          ].join(' · '),
        ),
        trailing: Chip(
          label: Text(track.hasPendingSync ? 'En attente' : 'Synchronisé'),
          backgroundColor: (track.hasPendingSync ? Colors.orange[800]! : Colors.green[700]!)
              .withValues(alpha: 0.12),
          labelStyle: TextStyle(color: track.hasPendingSync ? Colors.orange[800] : Colors.green[700]),
          side: BorderSide.none,
        ),
        isThreeLine: true,
        onTap: () => _openTrack(track),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '$minutes min';
  }
}

/// Bandeau « Positions en attente / Synchroniser GPS » (section 31) :
/// n'apparaît que lorsqu'au moins une position n'est pas encore synchronisée.
class _GpsSyncBanner extends StatelessWidget {
  final Future<int> pendingCountFuture;
  final VoidCallback onSync;

  const _GpsSyncBanner({required this.pendingCountFuture, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: pendingCountFuture,
      builder: (context, snapshot) {
        final pending = snapshot.data ?? 0;
        if (pending == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Positions en attente : $pending'),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: GpsSyncService.instance.isSyncingNotifier,
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
                        label: Text(isSyncing ? 'Synchronisation…' : 'Synchroniser GPS'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
