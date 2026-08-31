import 'dart:convert';

import '../core/constants/app_constants.dart';

/// Une opération en attente (ou déjà traitée) dans `sync_queue`.
///
/// Représente une donnée locale (identifiée par [entityTable] + [entityLocalId],
/// c'est-à-dire le nom de la table SQLite et le `local_id` de la ligne
/// concernée) qui doit être — ou a été — envoyée à l'API Laravel.
/// [entityLocalId] est la clé qui garantit l'absence de doublon côté serveur
/// (voir `SyncQueueRepository.addToQueue`).
class SyncQueueEntry {
  final int? id;
  final String entityTable;
  final String entityLocalId;
  final SyncOperation operation;
  final Map<String, dynamic>? payload;
  final SyncStatus status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncQueueEntry({
    this.id,
    required this.entityTable,
    required this.entityLocalId,
    required this.operation,
    this.payload,
    this.status = SyncStatus.pending,
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  SyncQueueEntry copyWith({
    int? id,
    String? entityTable,
    String? entityLocalId,
    SyncOperation? operation,
    Map<String, dynamic>? payload,
    SyncStatus? status,
    int? attempts,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SyncQueueEntry(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      entityLocalId: entityLocalId ?? this.entityLocalId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_table': entityTable,
      'entity_local_id': entityLocalId,
      'operation': operation.value,
      'payload': payload != null ? jsonEncode(payload) : null,
      'status': status.value,
      'attempts': attempts,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SyncQueueEntry.fromMap(Map<String, dynamic> map) {
    final rawPayload = map['payload'] as String?;
    return SyncQueueEntry(
      id: map['id'] as int?,
      entityTable: map['entity_table'] as String,
      entityLocalId: map['entity_local_id'] as String,
      operation: SyncOperationX.fromValue(map['operation'] as String?),
      payload: (rawPayload == null || rawPayload.isEmpty)
          ? null
          : jsonDecode(rawPayload) as Map<String, dynamic>,
      status: SyncStatusX.fromValue(map['status'] as String?),
      attempts: map['attempts'] as int? ?? 0,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
