import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/mission_status_utils.dart';
import '../../database/seed/demo_data_seeder.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/mission_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/main_bottom_nav.dart';
import 'mission_detail_screen.dart';

/// Liste des missions attribuées à l'agent connecté, groupées par statut :
/// à faire, en cours (ou en pause) et terminées (ou annulées).
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final _missionRepository = MissionRepository();
  late Future<List<MissionSummary>> _missionsFuture;

  @override
  void initState() {
    super.initState();
    _missionsFuture = _loadMissions();
  }

  Future<List<MissionSummary>> _loadMissions() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return [];
    return _missionRepository.getSummariesByUser(userId);
  }

  void _refresh() {
    setState(() => _missionsFuture = _loadMissions());
  }

  Future<void> _seedDemoData() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    await DemoDataSeeder.seedMissionsIfEmpty(userId);
    _refresh();
  }

  Future<void> _openMission(MissionSummary summary) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MissionDetailScreen(missionId: summary.mission.id!)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes missions')),
      body: FutureBuilder<List<MissionSummary>>(
        future: _missionsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final missions = snapshot.data!;
          if (missions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    message: 'Aucune mission attribuée pour le moment.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _seedDemoData,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Charger des données de démonstration'),
                  ),
                ],
              ),
            );
          }

          final aFaire = missions.where((m) => m.mission.statut == MissionStatus.pending).toList();
          final enCours = missions
              .where(
                (m) =>
                    m.mission.statut == MissionStatus.inProgress ||
                    m.mission.statut == MissionStatus.paused,
              )
              .toList();
          final terminees = missions
              .where(
                (m) =>
                    m.mission.statut == MissionStatus.completed ||
                    m.mission.statut == MissionStatus.cancelled,
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._section('À faire', aFaire),
              ..._section('En cours', enCours),
              ..._section('Terminées', terminees),
            ],
          );
        },
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 1),
    );
  }

  List<Widget> _section(String title, List<MissionSummary> summaries) {
    if (summaries.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.grey[700], letterSpacing: 0.5),
        ),
      ),
      ...summaries.map(_buildCard),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildCard(MissionSummary summary) {
    final mission = summary.mission;
    final status = mission.statut;
    final period = AppDateUtils.frenchDateRange(mission.dateDebut, mission.dateFin);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(MissionStatusUtils.icon(status), color: MissionStatusUtils.color(status)),
        title: Text(mission.titre),
        subtitle: Text(
          [if (period.isNotEmpty) period, if (summary.cldNames.isNotEmpty) summary.cldNames.join(', ')]
              .join('\n'),
        ),
        isThreeLine: period.isNotEmpty && summary.cldNames.isNotEmpty,
        trailing: Chip(
          label: Text(MissionStatusUtils.label(status)),
          backgroundColor: MissionStatusUtils.color(status).withValues(alpha: 0.12),
          labelStyle: TextStyle(color: MissionStatusUtils.color(status)),
          side: BorderSide.none,
        ),
        onTap: () => _openMission(summary),
      ),
    );
  }
}
