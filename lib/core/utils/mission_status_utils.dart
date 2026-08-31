import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Libellé, icône et couleur d'un [MissionStatus], utilisés à la fois par
/// `MissionsScreen` et `MissionDetailScreen` pour rester cohérents.
class MissionStatusUtils {
  MissionStatusUtils._();

  static String label(MissionStatus status) {
    switch (status) {
      case MissionStatus.pending:
        return 'À faire';
      case MissionStatus.inProgress:
        return 'En cours';
      case MissionStatus.paused:
        return 'En pause';
      case MissionStatus.completed:
        return 'Terminée';
      case MissionStatus.cancelled:
        return 'Annulée';
    }
  }

  static IconData icon(MissionStatus status) {
    switch (status) {
      case MissionStatus.pending:
        return Icons.schedule_outlined;
      case MissionStatus.inProgress:
        return Icons.directions_run_outlined;
      case MissionStatus.paused:
        return Icons.pause_circle_outline;
      case MissionStatus.completed:
        return Icons.check_circle_outline;
      case MissionStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static Color color(MissionStatus status) {
    switch (status) {
      case MissionStatus.pending:
        return Colors.amber[800]!;
      case MissionStatus.inProgress:
        return Colors.blue[700]!;
      case MissionStatus.paused:
        return Colors.orange[800]!;
      case MissionStatus.completed:
        return Colors.green[700]!;
      case MissionStatus.cancelled:
        return Colors.red[700]!;
    }
  }
}
