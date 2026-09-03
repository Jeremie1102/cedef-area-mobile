import React, { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { BottomNav, NavTab } from './components/BottomNav';
import { HomeScreen } from './components/HomeScreen';
import { MissionsScreen } from './components/MissionsScreen';
import { MissionDetailModal } from './components/MissionDetailModal';
import { MediaScreen } from './components/MediaScreen';
import { NewMediaBatchModal } from './components/NewMediaBatchModal';
import { MediaBatchDetailModal } from './components/MediaBatchDetailModal';
import { TracksScreen } from './components/TracksScreen';
import { TrackDetailModal } from './components/TrackDetailModal';
import { TerritoryScreen } from './components/TerritoryScreen';
import { SyncStatusScreen } from './components/SyncStatusScreen';
import { ProfileScreen } from './components/ProfileScreen';
import { store } from './services/store';
import { Mission, MediaBatch, GpsPosition, User } from './types';

export function App() {
  const [, setTick] = useState(0);

  // Active Tab
  const [currentTab, setCurrentTab] = useState<NavTab>('home');

  // Modals state
  const [selectedMission, setSelectedMission] = useState<Mission | null>(null);
  const [selectedMediaBatch, setSelectedMediaBatch] = useState<MediaBatch | null>(null);
  const [isNewMediaOpen, setIsNewMediaOpen] = useState(false);
  const [newMediaContext, setNewMediaContext] = useState<{ missionId?: number; cldId?: number }>({});
  const [selectedTrack, setSelectedTrack] = useState<{ mission: Mission; positions: GpsPosition[] } | null>(null);
  const [isSyncing, setIsSyncing] = useState(false);

  // Subscribe to store updates
  useEffect(() => {
    const unsubscribe = store.subscribe(() => {
      setTick((t) => t + 1);
      // Keep selected mission fresh if updated in store
      if (selectedMission) {
        const fresh = store.getMissionById(selectedMission.id);
        if (fresh) setSelectedMission(fresh);
      }
    });
    return () => {
      unsubscribe();
    };
  }, [selectedMission]);

  // Read data from store
  const user = store.getUser();
  const isOnline = store.getIsOnline();
  const secteurs = store.getSecteurs();
  const groupements = store.getGroupements();
  const clds = store.getClds();
  const villages = store.getVillages();
  const missions = store.getMissions();
  const gpsPositions = store.getGpsPositions();
  const mediaBatches = store.getMediaBatches();
  const counts = store.getCounts();

  // Handlers
  const handleToggleOnline = () => {
    store.setIsOnline(!isOnline);
  };

  const handleStartMission = (id: number) => {
    store.startMission(id);
  };

  const handlePauseMission = (id: number) => {
    store.pauseMission(id);
  };

  const handleResumeMission = (id: number) => {
    store.resumeMission(id);
  };

  const handleCompleteMission = (id: number, observation?: string) => {
    store.completeMission(id, observation);
  };

  const handleOpenNewMediaModal = (missionId?: number, cldId?: number) => {
    setNewMediaContext({ missionId, cldId });
    setIsNewMediaOpen(true);
  };

  const handleCreateMediaBatch = (batchData: any) => {
    store.createMediaBatch(batchData);
    setIsNewMediaOpen(false);
  };

  const handleSyncAll = async () => {
    setIsSyncing(true);
    try {
      await store.syncAll();
    } finally {
      setIsSyncing(false);
    }
  };

  const handleUpdateUser = (updated: Partial<User>) => {
    store.updateUser(updated);
  };

  const handleResetDemoData = () => {
    if (confirm('Voulez-vous réinitialiser toutes les données de démonstration de CEDEF AREA ?')) {
      store.resetToDefaults();
      setSelectedMission(null);
      setSelectedMediaBatch(null);
      setSelectedTrack(null);
    }
  };

  // Header Title Resolver
  const getHeaderTitle = () => {
    switch (currentTab) {
      case 'home':
        return 'CEDEF AREA';
      case 'missions':
        return 'Mes missions';
      case 'media':
        return 'Médias terrain';
      case 'tracks':
        return 'Parcours GPS';
      case 'territory':
        return 'Territoire & CLD';
      case 'sync':
        return 'Synchronisation';
      case 'profile':
        return 'Profil agent';
      default:
        return 'CEDEF AREA';
    }
  };

  const activeMissionsCount = missions.filter((m) => m.statut === 'in_progress').length;

  return (
    <div className="min-h-screen bg-slate-100 text-slate-900 flex flex-col font-sans antialiased selection:bg-emerald-200">
      {/* Top App Bar */}
      <Header
        title={getHeaderTitle()}
        isOnline={isOnline}
        onToggleOnline={handleToggleOnline}
        pendingCount={counts.totalPending}
        onOpenSync={() => setCurrentTab('sync')}
      />

      {/* Main Viewport Content */}
      <main className="flex-1">
        {currentTab === 'home' && (
          <HomeScreen
            user={user}
            missions={missions}
            cldsCount={clds.length}
            pendingMediaCount={counts.pendingBatches}
            isOnline={isOnline}
            onNavigate={(tab) => setCurrentTab(tab)}
            onOpenMission={(m) => setSelectedMission(m)}
            onOpenSync={() => setCurrentTab('sync')}
          />
        )}

        {currentTab === 'missions' && (
          <MissionsScreen
            missions={missions}
            secteurs={secteurs}
            clds={clds}
            onSelectMission={(m) => setSelectedMission(m)}
            onResetDemoData={handleResetDemoData}
          />
        )}

        {currentTab === 'media' && (
          <MediaScreen
            batches={mediaBatches}
            clds={clds}
            villages={villages}
            missions={missions}
            onOpenNewBatch={() => handleOpenNewMediaModal()}
            onOpenBatchDetail={(b) => setSelectedMediaBatch(b)}
            onSyncPending={handleSyncAll}
            isSyncing={isSyncing}
          />
        )}

        {currentTab === 'tracks' && (
          <TracksScreen
            missions={missions}
            gpsPositions={gpsPositions}
            onOpenTrackDetail={(m, pos) => setSelectedTrack({ mission: m, positions: pos })}
            onSyncGps={handleSyncAll}
            isSyncing={isSyncing}
          />
        )}

        {currentTab === 'territory' && (
          <TerritoryScreen
            secteurs={secteurs}
            groupements={groupements}
            clds={clds}
            villages={villages}
            onResetDemoData={handleResetDemoData}
          />
        )}

        {currentTab === 'sync' && (
          <SyncStatusScreen
            isOnline={isOnline}
            onToggleOnline={handleToggleOnline}
            onSyncAll={handleSyncAll}
            isSyncing={isSyncing}
            counts={counts}
            onResetDemoData={handleResetDemoData}
          />
        )}

        {currentTab === 'profile' && (
          <ProfileScreen
            user={user}
            onUpdateUser={handleUpdateUser}
            onResetDemoData={handleResetDemoData}
          />
        )}
      </main>

      {/* Persistent Bottom Navigation */}
      <BottomNav
        currentTab={currentTab}
        onSelectTab={(tab) => setCurrentTab(tab)}
        pendingMediaCount={counts.pendingBatches}
        activeMissionCount={activeMissionsCount}
      />

      {/* Mission Detail Modal */}
      {selectedMission && (
        <MissionDetailModal
          mission={selectedMission}
          secteurs={secteurs}
          groupements={groupements}
          clds={clds}
          villages={villages}
          gpsPositions={gpsPositions}
          mediaBatches={mediaBatches}
          onClose={() => setSelectedMission(null)}
          onStart={handleStartMission}
          onPause={handlePauseMission}
          onResume={handleResumeMission}
          onComplete={handleCompleteMission}
          onOpenNewMedia={(missionId, cldId) => {
            setSelectedMission(null);
            handleOpenNewMediaModal(missionId, cldId);
          }}
          onOpenMediaBatch={(batch) => {
            setSelectedMission(null);
            setSelectedMediaBatch(batch);
          }}
        />
      )}

      {/* New Media Batch Modal */}
      {isNewMediaOpen && (
        <NewMediaBatchModal
          missions={missions}
          clds={clds}
          villages={villages}
          initialMissionId={newMediaContext.missionId}
          initialCldId={newMediaContext.cldId}
          onClose={() => setIsNewMediaOpen(false)}
          onCreate={handleCreateMediaBatch}
        />
      )}

      {/* Media Batch Detail Modal */}
      {selectedMediaBatch && (
        <MediaBatchDetailModal
          batch={selectedMediaBatch}
          clds={clds}
          villages={villages}
          missions={missions}
          onClose={() => setSelectedMediaBatch(null)}
        />
      )}

      {/* Track Detail Modal */}
      {selectedTrack && (
        <TrackDetailModal
          mission={selectedTrack.mission}
          positions={selectedTrack.positions}
          onClose={() => setSelectedTrack(null)}
        />
      )}
    </div>
  );
}

export default App;
