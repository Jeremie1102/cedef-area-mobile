import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_utils.dart';
import '../../models/gps_position.dart';
import '../../models/mission.dart';
import '../../repositories/gps_repository.dart';
import '../../services/gps_service.dart';
import '../../services/mission_service.dart';

class _TrackDetails {
  final Mission mission;
  final MissionTrackSummary summary;
  final GpsPosition? firstPosition;
  final GpsPosition? lastPosition;
  final bool hasPendingSync;

  const _TrackDetails({
    required this.mission,
    required this.summary,
    this.firstPosition,
    this.lastPosition,
    required this.hasPendingSync,
  });
}

/// Détail d'un parcours GPS enregistré pour une mission (section 29) : pas
/// de carte dans cette étape, uniquement les informations disponibles
/// localement (mission, période, nombre de positions, distance estimée,
/// première/dernière position, statut de synchronisation).
class TrackDetailScreen extends StatefulWidget {
  final int missionId;

  const TrackDetailScreen({super.key, required this.missionId});

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  final _missionService = MissionService();
  final _gpsRepository = GpsRepository();

  late Future<_TrackDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_TrackDetails> _loadDetails() async {
    final mission = await _missionService.getMissionById(widget.missionId);
    if (mission == null) {
      throw const ValidationException('Mission introuvable.');
    }

    final summary = await _missionService.getMissionTrackSummary(widget.missionId);
    final positions = await _gpsRepository.findByMission(widget.missionId);

    return _TrackDetails(
      mission: mission,
      summary: summary,
      firstPosition: positions.isNotEmpty ? positions.first : null,
      lastPosition: positions.isNotEmpty ? positions.last : null,
      hasPendingSync: positions.any((p) => p.syncStatus == SyncStatus.pending),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du parcours')),
      body: FutureBuilder<_TrackDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final message = snapshot.error is AppException
                ? (snapshot.error as AppException).message
                : 'Une erreur est survenue.';
            return Center(child: Text(message));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final details = snapshot.data!;
          final summary = details.summary;
          final distanceKm = summary.distanceMeters != null ? summary.distanceMeters! / 1000 : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(details.mission.titre, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              if (summary.firstRecordedAt != null)
                _section('Date', AppDateUtils.frenchDate(summary.firstRecordedAt!)),
              if (summary.firstRecordedAt != null)
                _section('Heure de début', AppDateUtils.frenchTime(summary.firstRecordedAt!)),
              if (summary.lastRecordedAt != null)
                _section('Heure de fin', AppDateUtils.frenchTime(summary.lastRecordedAt!)),
              _section('Positions enregistrées', '${summary.positionCount}'),
              if (distanceKm != null && distanceKm > 0)
                _section(
                  'Distance estimée',
                  '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                ),
              if (details.firstPosition != null)
                _section('Première position', _formatCoordinates(details.firstPosition!)),
              if (details.lastPosition != null)
                _section('Dernière position', _formatCoordinates(details.lastPosition!)),
              _section(
                'Synchronisation',
                details.hasPendingSync ? 'En attente de synchronisation' : 'Synchronisé',
              ),
              const SizedBox(height: 8),
              Text(
                'La distance est une estimation à vol d\'oiseau entre les positions '
                'enregistrées, pas une mesure topographique précise.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatCoordinates(GpsPosition position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  Widget _section(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
