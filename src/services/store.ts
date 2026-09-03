import { User, Mission, Secteur, Groupement, Cld, Village, GpsPosition, MediaBatch, MediaItem, SyncQueueEntry, GpsTrackingStatus, UserFonction } from '../types';

const STORAGE_KEYS = {
  USER: 'cedef_user_v1',
  IS_ONLINE: 'cedef_is_online_v1',
  SECTEURS: 'cedef_secteurs_v1',
  GROUPEMENTS: 'cedef_groupements_v1',
  CLDS: 'cedef_clds_v1',
  VILLAGES: 'cedef_villages_v1',
  MISSIONS: 'cedef_missions_v1',
  GPS_POSITIONS: 'cedef_gps_positions_v1',
  MEDIA_BATCHES: 'cedef_media_batches_v1',
  SYNC_QUEUE: 'cedef_sync_queue_v1',
  LAST_SYNC: 'cedef_last_synced_at_v1',
};

const DEFAULT_USER: User = {
  id: 1,
  localId: 'usr_001',
  nom: 'Luyeye',
  prenom: 'Alain',
  telephone: '+243 81 234 5678',
  email: 'alain.luyeye@cedef.org',
  fonction: 'animateur',
  matricule: 'CDF-ANI-2024-042',
  photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
};

const DEFAULT_SECTEURS: Secteur[] = [
  { id: 1, localId: 'sec_001', nom: 'Ngeba', code: 'NGEBA', description: 'Secteur rural principal de Ngeba' },
  { id: 2, localId: 'sec_002', nom: 'Ngufu', code: 'NGUFU', description: 'Secteur forestier et agricole de Ngufu' },
];

const DEFAULT_GROUPEMENTS: Groupement[] = [
  { id: 1, localId: 'grp_001', secteurId: 1, nom: 'Groupement A', description: 'Zone de savane arborée' },
  { id: 2, localId: 'grp_002', secteurId: 1, nom: 'Groupement B', description: 'Zone de vallées agricoles' },
  { id: 3, localId: 'grp_003', secteurId: 2, nom: 'Groupement C', description: 'Zone de réserve agro-forestière' },
];

const DEFAULT_CLDS: Cld[] = [
  { id: 1, localId: 'cld_001', groupementId: 1, nom: 'CLD Ngeba 001', code: 'CLD-NGB-01', latitude: -4.7523, longitude: 14.8561, description: 'Comité Local de Développement Ngeba 1' },
  { id: 2, localId: 'cld_002', groupementId: 2, nom: 'CLD Ngeba 005', code: 'CLD-NGB-05', latitude: -4.7812, longitude: 14.8934, description: 'Comité Local de Développement Ngeba 5' },
  { id: 3, localId: 'cld_003', groupementId: 3, nom: 'CLD Ngufu 003', code: 'CLD-NGF-03', latitude: -4.8145, longitude: 14.9218, description: 'Comité Local de Développement Ngufu 3' },
];

const DEFAULT_VILLAGES: Village[] = [
  { id: 1, localId: 'vil_001', cldId: 1, nom: 'Kimpemba', latitude: -4.7511, longitude: 14.8540, description: 'Village central Kimpemba' },
  { id: 2, localId: 'vil_002', cldId: 1, nom: 'Mbanza', latitude: -4.7548, longitude: 14.8582, description: 'Village Mbanza' },
  { id: 3, localId: 'vil_003', cldId: 1, nom: 'Nkondo', latitude: -4.7590, longitude: 14.8610, description: 'Village Nkondo' },
  { id: 4, localId: 'vil_004', cldId: 2, nom: 'Village A', latitude: -4.7801, longitude: 14.8910, description: 'Village pilote secteur A' },
  { id: 5, localId: 'vil_005', cldId: 2, nom: 'Village B', latitude: -4.7834, longitude: 14.8965, description: 'Village B plantations' },
  { id: 6, localId: 'vil_006', cldId: 3, nom: 'Kimvula', latitude: -4.8160, longitude: 14.9240, description: 'Village Kimvula pépinière' },
];

const now = new Date();
const todayStr = now.toISOString().split('T')[0];
const yesterday = new Date(now.getTime() - 86400000 * 1);
const twoDaysAgo = new Date(now.getTime() - 86400000 * 2);
const threeDaysAhead = new Date(now.getTime() + 86400000 * 3);
const fourDaysAhead = new Date(now.getTime() + 86400000 * 4);
const sixDaysAgo = new Date(now.getTime() - 86400000 * 6);

const DEFAULT_MISSIONS: Mission[] = [
  {
    id: 1,
    localId: 'mis_001',
    titre: 'Sensibilisation communautaire',
    description: 'Rencontre avec les comités villageois pour la sensibilisation',
    instructions: 'Organiser les séances de sensibilisation dans les villages concernés et documenter les activités réalisées avec photos et relevé GPS.',
    dateDebut: todayStr,
    dateFin: new Date(now.getTime() + 86400000 * 2).toISOString().split('T')[0],
    secteurId: 1,
    cldId: 1,
    statut: 'pending',
    syncStatus: 'synced',
    createdAt: yesterday.toISOString(),
    updatedAt: yesterday.toISOString(),
  },
  {
    id: 2,
    localId: 'mis_002',
    titre: 'Identification de terrain',
    description: 'Reconnaissance des zones reboisées et relevés des parcelles',
    instructions: 'Identifier les nouvelles étendues à cartographier et relever les coordonnées GPS des points clés de bornage.',
    dateDebut: yesterday.toISOString().split('T')[0],
    dateFin: todayStr,
    secteurId: 1,
    cldId: 2,
    statut: 'in_progress',
    startedAt: new Date(now.getTime() - 3600000 * 3).toISOString(),
    syncStatus: 'synced',
    createdAt: twoDaysAgo.toISOString(),
    updatedAt: new Date(now.getTime() - 3600000 * 3).toISOString(),
  },
  {
    id: 3,
    localId: 'mis_003',
    titre: 'Suivi des travaux de pépinière',
    description: 'Contrôle qualité des plants d\'acacias et fruitiers',
    instructions: 'Vérifier l\'état d\'avancement de la pépinière et consigner les besoins en matériel et semences.',
    dateDebut: threeDaysAhead.toISOString().split('T')[0],
    dateFin: fourDaysAhead.toISOString().split('T')[0],
    secteurId: 2,
    cldId: 3,
    statut: 'pending',
    syncStatus: 'synced',
    createdAt: yesterday.toISOString(),
    updatedAt: yesterday.toISOString(),
  },
  {
    id: 4,
    localId: 'mis_004',
    titre: 'Identification des étendues',
    description: 'Vérification cartographique post-plantation',
    instructions: 'Repérer les nouvelles étendues plantées et vérifier leur conformité environnementale.',
    dateDebut: sixDaysAgo.toISOString().split('T')[0],
    dateFin: sixDaysAgo.toISOString().split('T')[0],
    secteurId: 1,
    cldId: 1,
    statut: 'completed',
    startedAt: new Date(sixDaysAgo.getTime() + 8 * 3600000).toISOString(),
    endedAt: new Date(sixDaysAgo.getTime() + 16 * 3600000).toISOString(),
    endObservation: 'Mission réalisée sans incident. Délimitation validée avec le chef de groupement.',
    syncStatus: 'synced',
    createdAt: sixDaysAgo.toISOString(),
    updatedAt: sixDaysAgo.toISOString(),
  },
];

// Sample GPS positions for completed mission #4 and active mission #2
const DEFAULT_GPS_POSITIONS: GpsPosition[] = [
  // Mission 4 (Completed) track
  { localId: 'gps_401', missionId: 4, userId: 1, latitude: -4.7520, longitude: 14.8560, altitude: 412, accuracy: 8, speed: 1.2, recordedAt: new Date(sixDaysAgo.getTime() + 8 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_402', missionId: 4, userId: 1, latitude: -4.7535, longitude: 14.8575, altitude: 415, accuracy: 6, speed: 1.4, recordedAt: new Date(sixDaysAgo.getTime() + 8.5 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_403', missionId: 4, userId: 1, latitude: -4.7558, longitude: 14.8590, altitude: 420, accuracy: 7, speed: 1.1, recordedAt: new Date(sixDaysAgo.getTime() + 9.5 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_404', missionId: 4, userId: 1, latitude: -4.7582, longitude: 14.8615, altitude: 424, accuracy: 5, speed: 0.9, recordedAt: new Date(sixDaysAgo.getTime() + 11 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_405', missionId: 4, userId: 1, latitude: -4.7610, longitude: 14.8638, altitude: 430, accuracy: 9, speed: 1.3, recordedAt: new Date(sixDaysAgo.getTime() + 13 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_406', missionId: 4, userId: 1, latitude: -4.7645, longitude: 14.8670, altitude: 435, accuracy: 6, speed: 1.5, recordedAt: new Date(sixDaysAgo.getTime() + 15 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_407', missionId: 4, userId: 1, latitude: -4.7650, longitude: 14.8682, altitude: 436, accuracy: 5, speed: 0.2, recordedAt: new Date(sixDaysAgo.getTime() + 16 * 3600000).toISOString(), syncStatus: 'synced' },

  // Mission 2 (In Progress) track
  { localId: 'gps_201', missionId: 2, userId: 1, latitude: -4.7812, longitude: 14.8934, altitude: 390, accuracy: 7, speed: 1.1, recordedAt: new Date(now.getTime() - 3 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_202', missionId: 2, userId: 1, latitude: -4.7828, longitude: 14.8950, altitude: 395, accuracy: 6, speed: 1.3, recordedAt: new Date(now.getTime() - 2.5 * 3600000).toISOString(), syncStatus: 'synced' },
  { localId: 'gps_203', missionId: 2, userId: 1, latitude: -4.7850, longitude: 14.8975, altitude: 398, accuracy: 8, speed: 1.0, recordedAt: new Date(now.getTime() - 1.5 * 3600000).toISOString(), syncStatus: 'pending' },
  { localId: 'gps_204', missionId: 2, userId: 1, latitude: -4.7875, longitude: 14.9010, altitude: 405, accuracy: 5, speed: 1.4, recordedAt: new Date(now.getTime() - 30 * 60000).toISOString(), syncStatus: 'pending' },
  { localId: 'gps_205', missionId: 2, userId: 1, latitude: -4.7892, longitude: 14.9035, altitude: 409, accuracy: 6, speed: 0.8, recordedAt: new Date(now.getTime() - 5 * 60000).toISOString(), syncStatus: 'pending' },
];

const DEFAULT_MEDIA_BATCHES: MediaBatch[] = [
  {
    id: 1,
    localId: 'mb_001',
    missionId: 4,
    userId: 1,
    cldId: 1,
    villageId: 1,
    activity: 'Séance de sensibilisation villageoise',
    description: 'Rencontre avec les notables et producteurs agricoles de Kimpemba sur le schéma d\'aménagement.',
    latitude: -4.7523,
    longitude: 14.8561,
    syncStatus: 'synced',
    createdAt: new Date(sixDaysAgo.getTime() + 10 * 3600000).toISOString(),
    updatedAt: new Date(sixDaysAgo.getTime() + 10 * 3600000).toISOString(),
    items: [
      {
        id: 'mi_001',
        batchLocalId: 'mb_001',
        fileName: 'Kimpemba_assemblee_01.jpg',
        fileSize: 1420500,
        mimeType: 'image/jpeg',
        dataUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=600&auto=format&fit=crop&q=80',
        takenAt: new Date(sixDaysAgo.getTime() + 10.2 * 3600000).toISOString(),
        syncStatus: 'synced',
      },
      {
        id: 'mi_002',
        batchLocalId: 'mb_001',
        fileName: 'Kimpemba_assemblee_02.jpg',
        fileSize: 1250000,
        mimeType: 'image/jpeg',
        dataUrl: 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=600&auto=format&fit=crop&q=80',
        takenAt: new Date(sixDaysAgo.getTime() + 10.4 * 3600000).toISOString(),
        syncStatus: 'synced',
      }
    ]
  },
  {
    id: 2,
    localId: 'mb_002',
    missionId: 2,
    userId: 1,
    cldId: 2,
    villageId: 4,
    activity: 'Relevé de parcelle agro-forestière',
    description: 'Prise de vue du bornage Est de la nouvelle parcelle reboisée à Village A.',
    latitude: -4.7875,
    longitude: 14.9010,
    syncStatus: 'pending',
    createdAt: new Date(now.getTime() - 40 * 60000).toISOString(),
    updatedAt: new Date(now.getTime() - 40 * 60000).toISOString(),
    items: [
      {
        id: 'mi_003',
        batchLocalId: 'mb_002',
        fileName: 'VillageA_borne_nord.jpg',
        fileSize: 1840000,
        mimeType: 'image/jpeg',
        dataUrl: 'https://images.unsplash.com/photo-1500651230702-0e2d8a49d4ad?w=600&auto=format&fit=crop&q=80',
        takenAt: new Date(now.getTime() - 42 * 60000).toISOString(),
        syncStatus: 'pending',
      }
    ]
  }
];

const DEFAULT_SYNC_QUEUE: SyncQueueEntry[] = [
  {
    id: 'sq_001',
    entityTable: 'media_batches',
    entityLocalId: 'mb_002',
    operation: 'create',
    status: 'pending',
    attempts: 0,
    createdAt: new Date(now.getTime() - 40 * 60000).toISOString(),
    updatedAt: new Date(now.getTime() - 40 * 60000).toISOString(),
  },
  {
    id: 'sq_002',
    entityTable: 'gps_positions',
    entityLocalId: 'gps_203',
    operation: 'create',
    status: 'pending',
    attempts: 0,
    createdAt: new Date(now.getTime() - 1.5 * 3600000).toISOString(),
    updatedAt: new Date(now.getTime() - 1.5 * 3600000).toISOString(),
  },
  {
    id: 'sq_003',
    entityTable: 'gps_positions',
    entityLocalId: 'gps_204',
    operation: 'create',
    status: 'pending',
    attempts: 0,
    createdAt: new Date(now.getTime() - 30 * 60000).toISOString(),
    updatedAt: new Date(now.getTime() - 30 * 60000).toISOString(),
  },
  {
    id: 'sq_004',
    entityTable: 'missions',
    entityLocalId: 'mis_004',
    operation: 'update',
    status: 'synced',
    attempts: 1,
    createdAt: sixDaysAgo.toISOString(),
    updatedAt: sixDaysAgo.toISOString(),
  }
];

class StoreService {
  private listeners: Set<() => void> = new Set();
  private gpsIntervalTimer: any = null;

  constructor() {
    this.init();
  }

  private init() {
    if (!localStorage.getItem(STORAGE_KEYS.USER)) {
      this.resetToDefaults();
    }
  }

  public resetToDefaults() {
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(DEFAULT_USER));
    localStorage.setItem(STORAGE_KEYS.IS_ONLINE, JSON.stringify(true));
    localStorage.setItem(STORAGE_KEYS.SECTEURS, JSON.stringify(DEFAULT_SECTEURS));
    localStorage.setItem(STORAGE_KEYS.GROUPEMENTS, JSON.stringify(DEFAULT_GROUPEMENTS));
    localStorage.setItem(STORAGE_KEYS.CLDS, JSON.stringify(DEFAULT_CLDS));
    localStorage.setItem(STORAGE_KEYS.VILLAGES, JSON.stringify(DEFAULT_VILLAGES));
    localStorage.setItem(STORAGE_KEYS.MISSIONS, JSON.stringify(DEFAULT_MISSIONS));
    localStorage.setItem(STORAGE_KEYS.GPS_POSITIONS, JSON.stringify(DEFAULT_GPS_POSITIONS));
    localStorage.setItem(STORAGE_KEYS.MEDIA_BATCHES, JSON.stringify(DEFAULT_MEDIA_BATCHES));
    localStorage.setItem(STORAGE_KEYS.SYNC_QUEUE, JSON.stringify(DEFAULT_SYNC_QUEUE));
    localStorage.setItem(STORAGE_KEYS.LAST_SYNC, new Date().toISOString());
    this.notify();
  }

  public subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notify() {
    this.listeners.forEach((fn) => fn());
  }

  private get<T>(key: string, fallback: T): T {
    try {
      const val = localStorage.getItem(key);
      return val ? JSON.parse(val) : fallback;
    } catch {
      return fallback;
    }
  }

  private set<T>(key: string, value: T) {
    localStorage.setItem(key, JSON.stringify(value));
    this.notify();
  }

  // Connectivity
  public getIsOnline(): boolean {
    return this.get<boolean>(STORAGE_KEYS.IS_ONLINE, true);
  }

  public setIsOnline(isOnline: boolean) {
    this.set(STORAGE_KEYS.IS_ONLINE, isOnline);
  }

  // User
  public getUser(): User {
    return this.get<User>(STORAGE_KEYS.USER, DEFAULT_USER);
  }

  public updateUser(user: Partial<User>) {
    const current = this.getUser();
    const updated = { ...current, ...user };
    this.set(STORAGE_KEYS.USER, updated);
  }

  // Territory
  public getSecteurs(): Secteur[] {
    return this.get<Secteur[]>(STORAGE_KEYS.SECTEURS, []);
  }

  public getGroupements(): Groupement[] {
    return this.get<Groupement[]>(STORAGE_KEYS.GROUPEMENTS, []);
  }

  public getClds(): Cld[] {
    return this.get<Cld[]>(STORAGE_KEYS.CLDS, []);
  }

  public getVillages(): Village[] {
    return this.get<Village[]>(STORAGE_KEYS.VILLAGES, []);
  }

  // Missions
  public getMissions(): Mission[] {
    return this.get<Mission[]>(STORAGE_KEYS.MISSIONS, []);
  }

  public getMissionById(id: number): Mission | undefined {
    return this.getMissions().find((m) => m.id === id);
  }

  public startMission(id: number): Mission | undefined {
    const missions = this.getMissions();
    const mission = missions.find((m) => m.id === id);
    if (!mission) return undefined;

    const nowIso = new Date().toISOString();
    mission.statut = 'in_progress';
    mission.startedAt = mission.startedAt || nowIso;
    mission.updatedAt = nowIso;
    mission.syncStatus = 'pending';

    this.set(STORAGE_KEYS.MISSIONS, missions);
    this.enqueueSync('missions', mission.localId, 'update');
    this.startGpsTracking(id);
    return mission;
  }

  public pauseMission(id: number): Mission | undefined {
    const missions = this.getMissions();
    const mission = missions.find((m) => m.id === id);
    if (!mission) return undefined;

    mission.statut = 'paused';
    mission.updatedAt = new Date().toISOString();
    mission.syncStatus = 'pending';

    this.set(STORAGE_KEYS.MISSIONS, missions);
    this.enqueueSync('missions', mission.localId, 'update');
    this.stopGpsTracking();
    return mission;
  }

  public resumeMission(id: number): Mission | undefined {
    const missions = this.getMissions();
    const mission = missions.find((m) => m.id === id);
    if (!mission) return undefined;

    mission.statut = 'in_progress';
    mission.updatedAt = new Date().toISOString();
    mission.syncStatus = 'pending';

    this.set(STORAGE_KEYS.MISSIONS, missions);
    this.enqueueSync('missions', mission.localId, 'update');
    this.startGpsTracking(id);
    return mission;
  }

  public completeMission(id: number, observation?: string): Mission | undefined {
    const missions = this.getMissions();
    const mission = missions.find((m) => m.id === id);
    if (!mission) return undefined;

    const nowIso = new Date().toISOString();
    mission.statut = 'completed';
    mission.endedAt = nowIso;
    mission.endObservation = observation || '';
    mission.updatedAt = nowIso;
    mission.syncStatus = 'pending';

    this.set(STORAGE_KEYS.MISSIONS, missions);
    this.enqueueSync('missions', mission.localId, 'update');
    this.stopGpsTracking();
    return mission;
  }

  // GPS Tracking
  public getGpsPositions(): GpsPosition[] {
    return this.get<GpsPosition[]>(STORAGE_KEYS.GPS_POSITIONS, []);
  }

  public getGpsPositionsForMission(missionId: number): GpsPosition[] {
    return this.getGpsPositions().filter((p) => p.missionId === missionId);
  }

  public recordGpsPosition(pos: Omit<GpsPosition, 'localId' | 'syncStatus'>): GpsPosition {
    const positions = this.getGpsPositions();
    const newPos: GpsPosition = {
      ...pos,
      localId: `gps_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`,
      syncStatus: 'pending',
    };
    positions.push(newPos);
    this.set(STORAGE_KEYS.GPS_POSITIONS, positions);
    this.enqueueSync('gps_positions', newPos.localId, 'create');
    return newPos;
  }

  public startGpsTracking(missionId: number) {
    if (this.gpsIntervalTimer) clearInterval(this.gpsIntervalTimer);

    // Initial immediate record
    const baseLat = -4.7812 + (Math.random() - 0.5) * 0.002;
    const baseLng = 14.8934 + (Math.random() - 0.5) * 0.002;
    this.recordGpsPosition({
      missionId,
      userId: this.getUser().id,
      latitude: baseLat,
      longitude: baseLng,
      altitude: 400 + Math.round(Math.random() * 20),
      accuracy: 5 + Math.round(Math.random() * 5),
      speed: 1.2,
      recordedAt: new Date().toISOString(),
    });

    // Periodic simulation recording every 20s
    this.gpsIntervalTimer = setInterval(() => {
      const activeMission = this.getMissionById(missionId);
      if (!activeMission || activeMission.statut !== 'in_progress') {
        this.stopGpsTracking();
        return;
      }

      const existingPositions = this.getGpsPositionsForMission(missionId);
      const lastPos = existingPositions[existingPositions.length - 1];
      const deltaLat = (Math.random() - 0.3) * 0.0015;
      const deltaLng = (Math.random() - 0.2) * 0.0015;
      const newLat = (lastPos ? lastPos.latitude : baseLat) + deltaLat;
      const newLng = (lastPos ? lastPos.longitude : baseLng) + deltaLng;

      this.recordGpsPosition({
        missionId,
        userId: this.getUser().id,
        latitude: newLat,
        longitude: newLng,
        altitude: 400 + Math.round(Math.random() * 30),
        accuracy: 4 + Math.round(Math.random() * 6),
        speed: 1.1 + (Math.random() * 0.5),
        recordedAt: new Date().toISOString(),
      });
    }, 20000);
  }

  public stopGpsTracking() {
    if (this.gpsIntervalTimer) {
      clearInterval(this.gpsIntervalTimer);
      this.gpsIntervalTimer = null;
    }
  }

  // Media Batches
  public getMediaBatches(): MediaBatch[] {
    return this.get<MediaBatch[]>(STORAGE_KEYS.MEDIA_BATCHES, []);
  }

  public getMediaBatchesForMission(missionId: number): MediaBatch[] {
    return this.getMediaBatches().filter((b) => b.missionId === missionId);
  }

  public createMediaBatch(batchData: {
    missionId?: number;
    cldId?: number;
    villageId?: number;
    activity: string;
    description?: string;
    latitude?: number;
    longitude?: number;
    items: Omit<MediaItem, 'id' | 'batchLocalId' | 'syncStatus'>[];
  }): MediaBatch {
    const batches = this.getMediaBatches();
    const batchLocalId = `mb_${Date.now()}`;
    const nextId = batches.length > 0 ? Math.max(...batches.map((b) => b.id)) + 1 : 1;
    const nowIso = new Date().toISOString();

    const items: MediaItem[] = batchData.items.map((item, idx) => ({
      id: `mi_${batchLocalId}_${idx + 1}`,
      batchLocalId,
      fileName: item.fileName,
      fileSize: item.fileSize,
      mimeType: item.mimeType,
      dataUrl: item.dataUrl,
      takenAt: item.takenAt || nowIso,
      syncStatus: 'pending',
    }));

    const newBatch: MediaBatch = {
      id: nextId,
      localId: batchLocalId,
      missionId: batchData.missionId,
      userId: this.getUser().id,
      cldId: batchData.cldId,
      villageId: batchData.villageId,
      activity: batchData.activity,
      description: batchData.description,
      latitude: batchData.latitude,
      longitude: batchData.longitude,
      syncStatus: 'pending',
      items,
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    batches.unshift(newBatch);
    this.set(STORAGE_KEYS.MEDIA_BATCHES, batches);
    this.enqueueSync('media_batches', newBatch.localId, 'create');
    return newBatch;
  }

  // Sync Queue & Synchronization
  public getSyncQueue(): SyncQueueEntry[] {
    return this.get<SyncQueueEntry[]>(STORAGE_KEYS.SYNC_QUEUE, []);
  }

  public getLastSyncedAt(): string | null {
    return localStorage.getItem(STORAGE_KEYS.LAST_SYNC);
  }

  private enqueueSync(entityTable: string, entityLocalId: string, operation: 'create' | 'update' | 'delete') {
    const queue = this.getSyncQueue();
    const nowIso = new Date().toISOString();
    const existing = queue.find((q) => q.entityTable === entityTable && q.entityLocalId === entityLocalId);

    if (existing) {
      existing.operation = operation;
      existing.status = 'pending';
      existing.updatedAt = nowIso;
    } else {
      queue.unshift({
        id: `sq_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`,
        entityTable,
        entityLocalId,
        operation,
        status: 'pending',
        attempts: 0,
        createdAt: nowIso,
        updatedAt: nowIso,
      });
    }

    this.set(STORAGE_KEYS.SYNC_QUEUE, queue);
  }

  public async syncAll(): Promise<{ uploaded: number; failed: number; outcome: 'offline' | 'alreadyRunning' | 'completed' }> {
    if (!this.getIsOnline()) {
      return { uploaded: 0, failed: 0, outcome: 'offline' };
    }

    // Simulate network delay for real sync feedback
    await new Promise((r) => setTimeout(r, 1200));

    const queue = this.getSyncQueue();
    const missions = this.getMissions();
    const gpsPositions = this.getGpsPositions();
    const batches = this.getMediaBatches();
    let uploaded = 0;

    // Process queue items
    queue.forEach((item) => {
      if (item.status === 'pending') {
        item.status = 'synced';
        item.attempts += 1;
        item.updatedAt = new Date().toISOString();
        uploaded++;
      }
    });

    // Mark missions as synced
    missions.forEach((m) => {
      if (m.syncStatus === 'pending') m.syncStatus = 'synced';
    });

    // Mark GPS positions as synced
    gpsPositions.forEach((g) => {
      if (g.syncStatus === 'pending') g.syncStatus = 'synced';
    });

    // Mark media batches as synced
    batches.forEach((b) => {
      if (b.syncStatus === 'pending') {
        b.syncStatus = 'synced';
        b.items.forEach((it) => (it.syncStatus = 'synced'));
      }
    });

    this.set(STORAGE_KEYS.SYNC_QUEUE, queue);
    this.set(STORAGE_KEYS.MISSIONS, missions);
    this.set(STORAGE_KEYS.GPS_POSITIONS, gpsPositions);
    this.set(STORAGE_KEYS.MEDIA_BATCHES, batches);
    localStorage.setItem(STORAGE_KEYS.LAST_SYNC, new Date().toISOString());

    this.notify();
    return { uploaded, failed: 0, outcome: 'completed' };
  }

  // Count summaries
  public getCounts() {
    const missions = this.getMissions();
    const gps = this.getGpsPositions();
    const batches = this.getMediaBatches();
    const queue = this.getSyncQueue();

    const pendingMissions = missions.filter((m) => m.syncStatus === 'pending').length;
    const pendingGps = gps.filter((g) => g.syncStatus === 'pending').length;
    const pendingBatches = batches.filter((b) => b.syncStatus === 'pending').length;
    const pendingPhotos = batches.reduce((acc, b) => acc + b.items.filter((i) => i.syncStatus === 'pending').length, 0);

    return {
      pendingMissions,
      pendingGps,
      pendingBatches,
      pendingPhotos,
      totalPending: pendingMissions + pendingGps + pendingBatches + pendingPhotos,
      lastSyncedAt: this.getLastSyncedAt(),
      history: queue.slice(0, 10),
    };
  }
}

export const store = new StoreService();
