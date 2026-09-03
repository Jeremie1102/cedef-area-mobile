export type UserFonction = 'animateur' | 'mrv' | 'sauvegarde' | 'sig';

export interface User {
  id: number;
  localId: string;
  nom: string;
  prenom: string;
  telephone: string;
  email?: string;
  fonction: UserFonction;
  matricule?: string;
  photoUrl?: string;
}

export type MissionStatus = 'pending' | 'in_progress' | 'paused' | 'completed' | 'cancelled';

export interface Mission {
  id: number;
  localId: string;
  titre: string;
  description?: string;
  instructions?: string;
  dateDebut?: string;
  dateFin?: string;
  secteurId?: number;
  cldId?: number;
  statut: MissionStatus;
  startedAt?: string;
  endedAt?: string;
  endObservation?: string;
  syncStatus: 'pending' | 'synced' | 'failed';
  createdAt: string;
  updatedAt: string;
}

export interface Secteur {
  id: number;
  localId: string;
  nom: string;
  code: string;
  description?: string;
}

export interface Groupement {
  id: number;
  localId: string;
  secteurId: number;
  nom: string;
  description?: string;
}

export interface Cld {
  id: number;
  localId: string;
  groupementId: number;
  nom: string;
  code?: string;
  latitude?: number;
  longitude?: number;
  description?: string;
}

export interface Village {
  id: number;
  localId: string;
  cldId: number;
  nom: string;
  latitude?: number;
  longitude?: number;
  description?: string;
}

export interface GpsPosition {
  id?: number;
  localId: string;
  missionId: number;
  userId: number;
  latitude: number;
  longitude: number;
  altitude?: number;
  accuracy?: number;
  speed?: number;
  heading?: number;
  recordedAt: string;
  syncStatus: 'pending' | 'synced' | 'failed';
}

export type SyncStatus = 'pending' | 'syncing' | 'synced' | 'failed';

export interface MediaBatch {
  id: number;
  localId: string;
  missionId?: number;
  userId: number;
  cldId?: number;
  villageId?: number;
  activity?: string;
  description?: string;
  latitude?: number;
  longitude?: number;
  syncStatus: SyncStatus;
  items: MediaItem[];
  createdAt: string;
  updatedAt: string;
}

export interface MediaItem {
  id: string;
  batchLocalId: string;
  fileName: string;
  fileSize: number; // bytes
  mimeType: string;
  dataUrl: string;
  takenAt: string;
  syncStatus: SyncStatus;
}

export interface SyncQueueEntry {
  id: string;
  entityTable: string;
  entityLocalId: string;
  operation: 'create' | 'update' | 'delete';
  status: SyncStatus;
  attempts: number;
  lastError?: string;
  createdAt: string;
  updatedAt: string;
}

export type GpsTrackingStatus = 'idle' | 'searching' | 'active' | 'unavailable';
