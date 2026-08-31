import '../core/constants/app_constants.dart';

/// Un fichier photo appartenant à un [MediaBatch].
///
/// Ne porte aucune information de contexte (activité, description, lieu) :
/// ces informations sont communes à tout le lot et vivent sur [MediaBatch].
class MediaItem {
  final int? id;
  final String localId;
  final int? serverId;
  final int batchId;
  final String localPath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int sortOrder;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaItem({
    this.id,
    required this.localId,
    this.serverId,
    required this.batchId,
    required this.localPath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.sortOrder = 0,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  MediaItem copyWith({
    int? id,
    String? localId,
    int? serverId,
    int? batchId,
    String? localPath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? sortOrder,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      batchId: batchId ?? this.batchId,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      sortOrder: sortOrder ?? this.sortOrder,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'server_id': serverId,
      'batch_id': batchId,
      'local_path': localPath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'sort_order': sortOrder,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as int?,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as int?,
      batchId: map['batch_id'] as int,
      localPath: map['local_path'] as String,
      fileName: map['file_name'] as String,
      fileSize: map['file_size'] as int,
      mimeType: map['mime_type'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      syncStatus: SyncStatusX.fromValue(map['sync_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
