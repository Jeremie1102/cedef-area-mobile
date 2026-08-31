import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/mission_status_utils.dart';
import '../../models/cld.dart';
import '../../models/gps_position.dart';
import '../../models/mission.dart';
import '../../models/village.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/cld_repository.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/secteur_repository.dart';
import '../../services/gps_service.dart';
import '../../services/mission_service.dart';
import '../../widgets/coming_soon_screen.dart';
import '../media/media_screen.dart';
import '../media/new_media_batch_screen.dart';

class _MissionDetails {
  final Mission mission;
  final String? secteurName;
  final List<Cld> clds;
  final List<Village> villages;
  final MissionTrackSummary? track;
  final int mediaBatchCount;

  const _MissionDetails({
    required this.mission,
    this.secteurName,
    required this.clds,
    required this.villages,
    this.track,
    this.mediaBatchCount = 0,
  });
}

/// Détails d'une mission attribuée à l'agent connecté : période, territoire
/// concerné, instructions, statut, et actions de suivi (démarrer, mettre en
/// pause, reprendre, terminer) — toutes exécutées et enregistrées localement,
/// sans connexion Internet. Affiche également le suivi GPS (position
/// courante pendant une mission en cours, parcours résumé une fois terminée).
class MissionDetailScreen extends StatefulWidget {
  final int missionId;

  const MissionDetailScreen({super.key, required this.missionId});

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  final _missionService = MissionService();
  final _secteurRepository = SecteurRepository();
  final _cldRepository = CldRepository();
  final _mediaRepository = MediaRepository();

  late Future<_MissionDetails> _detailsFuture;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_MissionDetails> _loadDetails() async {
    final mission = await _missionService.getMissionById(widget.missionId);
    if (mission == null) {
      throw const ValidationException('Mission introuvable.');
    }

    final territory = await _missionService.getMissionTerritory(widget.missionId);
    final secteur = mission.secteurId != null
        ? await _secteurRepository.getById(mission.secteurId!)
        : null;
    final track = mission.statut == MissionStatus.completed
        ? await _missionService.getMissionTrackSummary(widget.missionId)
        : null;
    final mediaBatches = await _mediaRepository.getBatchesByMission(widget.missionId);

    return _MissionDetails(
      mission: mission,
      secteurName: secteur?.nom,
      clds: territory.clds,
      villages: territory.villages,
      track: track,
      mediaBatchCount: mediaBatches.length,
    );
  }

  Future<void> _addMedia(_MissionDetails details) async {
    final allowedClds = await _cldRepository.getByIdsWithLocation(
      details.clds.map((c) => c.id!).toList(),
    );
    if (!mounted) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewMediaBatchScreen(missionId: widget.missionId, allowedClds: allowedClds),
      ),
    );
    if (created == true) _refresh();
  }

  void _refresh() {
    setState(() => _detailsFuture = _loadDetails());
  }

  int get _userId => context.read<AuthProvider>().currentUser!.id!;

  Future<void> _runAction(Future<Mission> Function() action, {required String successMessage}) async {
    setState(() => _actionInProgress = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException ? e.message : 'Une erreur est survenue.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _startMission() async {
    final confirmed = await _confirm(
      title: 'Démarrer la mission',
      message: 'Voulez-vous démarrer cette mission maintenant ? Le suivi GPS sera activé.',
    );
    if (confirmed != true) return;
    await _runAction(
      () => _missionService.startMission(widget.missionId, userId: _userId),
      successMessage: 'Mission démarrée.',
    );
  }

  Future<void> _pauseMission() async {
    final confirmed = await _confirm(
      title: 'Mettre en pause',
      message: 'Voulez-vous mettre cette mission en pause ? Le suivi GPS sera arrêté temporairement.',
    );
    if (confirmed != true) return;
    await _runAction(
      () => _missionService.pauseMission(widget.missionId),
      successMessage: 'Mission mise en pause.',
    );
  }

  Future<void> _resumeMission() async {
    final confirmed = await _confirm(
      title: 'Reprendre la mission',
      message: 'Voulez-vous reprendre cette mission ?',
    );
    if (confirmed != true) return;
    await _runAction(
      () => _missionService.resumeMission(widget.missionId, userId: _userId),
      successMessage: 'Mission reprise.',
    );
  }

  Future<void> _completeMission() async {
    final observation = await _promptObservation();
    if (observation == null) return;
    await _runAction(
      () => _missionService.completeMission(widget.missionId, observation: observation),
      successMessage: 'Mission terminée.',
    );
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmer')),
        ],
      ),
    );
  }

  /// Retourne l'observation saisie (chaîne vide si laissée vierge), ou `null`
  /// si l'utilisateur a annulé.
  Future<String?> _promptObservation() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la mission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirmez-vous la fin de cette mission ? Le suivi GPS sera arrêté.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Observation (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  void _openComingSoon(String title, IconData icon) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComingSoonScreen(title: title, icon: icon)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: FutureBuilder<_MissionDetails>(
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
          final isActive =
              details.mission.statut == MissionStatus.inProgress ||
              details.mission.statut == MissionStatus.paused;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(details.mission.titre, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _buildStatusChip(details.mission.statut),
              const SizedBox(height: 20),
              if (details.mission.dateDebut != null || details.mission.dateFin != null)
                _section(
                  'Période',
                  AppDateUtils.frenchDateRange(details.mission.dateDebut, details.mission.dateFin),
                ),
              if (details.secteurName != null) _section('Secteur', details.secteurName!),
              if (details.clds.isNotEmpty)
                _sectionList('CLD concernés', details.clds.map((c) => c.nom).toList()),
              if (details.villages.isNotEmpty)
                _sectionList('Villages concernés', details.villages.map((v) => v.nom).toList()),
              if (details.mission.instructions != null && details.mission.instructions!.isNotEmpty)
                _section('Instructions', details.mission.instructions!),
              if (details.mission.statut == MissionStatus.completed &&
                  (details.mission.endObservation?.isNotEmpty ?? false))
                _section('Observation de fin', details.mission.endObservation!),
              if (isActive) ...[const SizedBox(height: 8), _buildGpsCard(details.mission.statut)],
              if (details.track != null) ...[const SizedBox(height: 8), _buildTrackCard(details.track!)],
              const SizedBox(height: 24),
              ..._buildActions(details.mission.statut),
              if (isActive) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text('Mission en cours', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Ajouter des médias',
                  onTap: () => _addMedia(details),
                ),
                _ActionTile(
                  icon: Icons.description_outlined,
                  label: 'Rapport',
                  onTap: () => _openComingSoon('Rapport', Icons.description_outlined),
                ),
              ],
              if (details.mediaBatchCount > 0) ...[
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.collections_outlined,
                  label: '${details.mediaBatchCount} lot${details.mediaBatchCount > 1 ? 's' : ''} de médias enregistré${details.mediaBatchCount > 1 ? 's' : ''}',
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MediaScreen())),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Carte « Localisation » : statut du suivi et dernière position connue,
  /// mise à jour en direct via les `ValueNotifier` de `GpsService.instance`
  /// (voir section 11 du cahier des charges pour les états affichés).
  Widget _buildGpsCard(MissionStatus missionStatus) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                Text('Localisation', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<GpsTrackingStatus>(
              valueListenable: GpsService.instance.statusNotifier,
              builder: (context, gpsStatus, _) {
                return Text(_gpsStatusLabel(missionStatus, gpsStatus));
              },
            ),
            ValueListenableBuilder<GpsPosition?>(
              valueListenable: GpsService.instance.lastPositionNotifier,
              builder: (context, position, _) {
                if (position == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (position.accuracy != null)
                        Text('Précision : ${position.accuracy!.round()} m'),
                      Text('Dernière position : ${AppDateUtils.frenchDateTime(position.recordedAt)}'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _gpsStatusLabel(MissionStatus missionStatus, GpsTrackingStatus gpsStatus) {
    if (missionStatus == MissionStatus.paused) return '⏸ GPS en pause';
    switch (gpsStatus) {
      case GpsTrackingStatus.active:
        return '🟢 GPS actif';
      case GpsTrackingStatus.searching:
      case GpsTrackingStatus.idle:
        return '🟠 Recherche de position';
      case GpsTrackingStatus.unavailable:
        return '🔴 GPS indisponible';
    }
  }

  /// Carte « Parcours » d'une mission terminée (section 15/16) : pas de
  /// carte interactive dans cette étape, uniquement les informations
  /// disponibles localement.
  Widget _buildTrackCard(MissionTrackSummary track) {
    if (track.positionCount == 0) {
      return const SizedBox.shrink();
    }

    final distanceKm = track.distanceMeters != null ? track.distanceMeters! / 1000 : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined),
                const SizedBox(width: 8),
                Text('Parcours', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Positions enregistrées : ${track.positionCount}'),
            if (track.firstRecordedAt != null)
              Text('Début : ${AppDateUtils.frenchTime(track.firstRecordedAt!)}'),
            if (track.lastRecordedAt != null)
              Text('Fin : ${AppDateUtils.frenchTime(track.lastRecordedAt!)}'),
            if (distanceKm != null && distanceKm > 0)
              Text('Distance estimée : ${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(MissionStatus status) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(MissionStatusUtils.icon(status), color: MissionStatusUtils.color(status), size: 18),
        label: Text(MissionStatusUtils.label(status)),
        backgroundColor: MissionStatusUtils.color(status).withValues(alpha: 0.12),
        labelStyle: TextStyle(color: MissionStatusUtils.color(status)),
        side: BorderSide.none,
      ),
    );
  }

  List<Widget> _buildActions(MissionStatus status) {
    if (_actionInProgress) {
      return [const Center(child: CircularProgressIndicator())];
    }

    switch (status) {
      case MissionStatus.pending:
        return [
          FilledButton.icon(
            onPressed: _startMission,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Démarrer la mission'),
          ),
        ];
      case MissionStatus.inProgress:
        return [
          FilledButton.icon(
            onPressed: _completeMission,
            icon: const Icon(Icons.check),
            label: const Text('Terminer la mission'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pauseMission,
            icon: const Icon(Icons.pause),
            label: const Text('Mettre en pause'),
          ),
        ];
      case MissionStatus.paused:
        return [
          FilledButton.icon(
            onPressed: _resumeMission,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reprendre la mission'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _completeMission,
            icon: const Icon(Icons.check),
            label: const Text('Terminer la mission'),
          ),
        ];
      case MissionStatus.completed:
      case MissionStatus.cancelled:
        return [];
    }
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

  Widget _sectionList(String title, List<String> values) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
          const SizedBox(height: 4),
          ...values.map((v) => Text('• $v')),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
