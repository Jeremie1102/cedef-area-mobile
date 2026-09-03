import React, { useState } from 'react';
import { 
  RefreshCw, 
  Wifi, 
  WifiOff, 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  Database, 
  Layers, 
  RotateCcw,
  Sparkles,
  Camera,
  Navigation,
  ClipboardList
} from 'lucide-react';
import { SyncQueueEntry } from '../types';

interface SyncStatusScreenProps {
  isOnline: boolean;
  onToggleOnline: () => void;
  onSyncAll: () => Promise<void>;
  isSyncing: boolean;
  counts: {
    pendingMissions: number;
    pendingGps: number;
    pendingBatches: number;
    pendingPhotos: number;
    totalPending: number;
    lastSyncedAt: string | null;
    history: SyncQueueEntry[];
  };
  onResetDemoData: () => void;
}

export const SyncStatusScreen: React.FC<SyncStatusScreenProps> = ({
  isOnline,
  onToggleOnline,
  onSyncAll,
  isSyncing,
  counts,
  onResetDemoData,
}) => {
  const [syncFeedback, setSyncFeedback] = useState<string | null>(null);

  const handleTriggerSync = async () => {
    if (!isOnline) {
      setSyncFeedback('Impossible de synchroniser en mode hors-ligne. Activez la connexion d\'abord.');
      return;
    }
    setSyncFeedback(null);
    await onSyncAll();
    setSyncFeedback('Synchronisation terminée avec succès ! Données transmises au serveur.');
    setTimeout(() => setSyncFeedback(null), 4000);
  };

  return (
    <div className="p-4 space-y-4 max-w-4xl mx-auto pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900">Synchronisation</h2>
          <p className="text-xs text-slate-500">
            Gestion du mode hors-ligne et file d'attente d'envoi vers le serveur
          </p>
        </div>
      </div>

      {/* Online / Offline Toggle Banner */}
      <div className={`rounded-2xl p-4 border transition-all ${
        isOnline 
          ? 'bg-emerald-50 border-emerald-200 text-emerald-950' 
          : 'bg-slate-100 border-slate-300 text-slate-900'
      }`}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
              isOnline ? 'bg-emerald-600 text-white' : 'bg-slate-400 text-white'
            }`}>
              {isOnline ? <Wifi className="w-5 h-5" /> : <WifiOff className="w-5 h-5" />}
            </div>
            <div>
              <div className="font-bold text-sm">
                {isOnline ? 'Mode Connecté (En ligne)' : 'Mode Hors-ligne (Terrain rural)'}
              </div>
              <div className="text-xs opacity-80">
                {isOnline 
                  ? 'Prêt pour l\'envoi automatique et la réception des nouvelles missions.' 
                  : 'Toutes les modifications sont enregistrées en local dans la base SQLite.'}
              </div>
            </div>
          </div>

          <button
            id="toggle-connectivity-button"
            onClick={onToggleOnline}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all shadow-xs ${
              isOnline
                ? 'bg-white text-emerald-800 border border-emerald-300 hover:bg-emerald-100'
                : 'bg-emerald-600 text-white hover:bg-emerald-700'
            }`}
          >
            {isOnline ? 'Passer Hors-ligne' : 'Activer Connexion'}
          </button>
        </div>
      </div>

      {/* Feedback message */}
      {syncFeedback && (
        <div className="p-3 bg-emerald-100 text-emerald-900 border border-emerald-300 rounded-xl text-xs font-medium flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-700 shrink-0" />
          <span>{syncFeedback}</span>
        </div>
      )}

      {/* Sync Action & Metrics Card */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs font-bold text-slate-400 uppercase tracking-wider">
              File d'attente locale
            </div>
            <div className="text-2xl font-extrabold text-slate-900 mt-0.5">
              {counts.totalPending} élément(s) en attente
            </div>
          </div>

          <button
            id="trigger-full-sync-btn"
            onClick={handleTriggerSync}
            disabled={isSyncing}
            className="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-xs transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${isSyncing ? 'animate-spin' : ''}`} />
            <span>{isSyncing ? 'Synchronisation...' : 'Synchroniser tout'}</span>
          </button>
        </div>

        {/* Pending Breakdown */}
        <div className="grid grid-cols-3 gap-2.5 pt-2 border-t border-slate-100">
          <div className="bg-slate-50 p-3 rounded-xl border border-slate-100 flex flex-col items-center text-center">
            <ClipboardList className="w-5 h-5 text-emerald-600 mb-1" />
            <div className="font-bold text-slate-900 text-sm">{counts.pendingMissions}</div>
            <div className="text-[10px] text-slate-500">Missions modifiées</div>
          </div>

          <div className="bg-slate-50 p-3 rounded-xl border border-slate-100 flex flex-col items-center text-center">
            <Camera className="w-5 h-5 text-teal-600 mb-1" />
            <div className="font-bold text-slate-900 text-sm">
              {counts.pendingBatches} ({counts.pendingPhotos} photos)
            </div>
            <div className="text-[10px] text-slate-500">Lots de photos</div>
          </div>

          <div className="bg-slate-50 p-3 rounded-xl border border-slate-100 flex flex-col items-center text-center">
            <Navigation className="w-5 h-5 text-sky-600 mb-1" />
            <div className="font-bold text-slate-900 text-sm">{counts.pendingGps}</div>
            <div className="text-[10px] text-slate-500">Points GPS</div>
          </div>
        </div>

        {/* Last sync info */}
        <div className="text-[11px] text-slate-400 text-center pt-1">
          Dernière synchronisation :{' '}
          {counts.lastSyncedAt
            ? new Date(counts.lastSyncedAt).toLocaleString('fr-FR')
            : 'Aucune dans cette session'}
        </div>
      </div>

      {/* Sync Queue Table */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Journal des opérations (File locale)
          </h3>
          <button
            onClick={onResetDemoData}
            className="text-[11px] font-semibold text-slate-500 hover:text-slate-700 flex items-center gap-1"
          >
            <RotateCcw className="w-3 h-3" />
            Réinitialiser démo
          </button>
        </div>

        {counts.history.length === 0 ? (
          <div className="bg-white rounded-xl p-6 border border-slate-200 text-center text-slate-400 text-xs">
            Aucune opération dans la file d'attente.
          </div>
        ) : (
          <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
            <table className="w-full text-left text-xs border-collapse">
              <thead className="bg-slate-50 text-slate-500 border-b border-slate-200 text-[10px] uppercase font-bold">
                <tr>
                  <th className="p-3">Entité</th>
                  <th className="p-3">Opération</th>
                  <th className="p-3">Date</th>
                  <th className="p-3 text-right">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-mono text-[11px]">
                {counts.history.map((entry) => (
                  <tr key={entry.id} className="hover:bg-slate-50">
                    <td className="p-3 font-sans font-medium text-slate-900">
                      {entry.entityTable} ({entry.entityLocalId})
                    </td>
                    <td className="p-3 text-slate-600 uppercase text-[10px]">
                      {entry.operation}
                    </td>
                    <td className="p-3 text-slate-400">
                      {new Date(entry.createdAt).toLocaleTimeString('fr-FR')}
                    </td>
                    <td className="p-3 text-right">
                      {entry.status === 'synced' ? (
                        <span className="inline-flex items-center gap-1 text-[10px] font-sans font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full">
                          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                          Synchro
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[10px] font-sans font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full">
                          <Clock className="w-3 h-3 text-amber-600" />
                          Attente
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
