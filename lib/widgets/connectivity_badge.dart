import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connectivity_provider.dart';

/// Petit badge affichant l'état de connexion (en ligne / hors ligne).
class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return Chip(
      avatar: Icon(
        isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        size: 18,
        color: Colors.white,
      ),
      label: Text(isOnline ? 'En ligne' : 'Hors ligne'),
      backgroundColor: isOnline ? Colors.green : Colors.grey,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}
