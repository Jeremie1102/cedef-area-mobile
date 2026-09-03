import React from 'react';
import { 
  Camera, 
  Plus, 
  RefreshCw, 
  Clock, 
  CheckCircle2, 
  AlertCircle, 
  MapPin, 
  ChevronRight, 
  Image as ImageIcon 
} from 'lucide-react';
import { MediaBatch, Cld, Village, Mission } from '../types';

interface MediaScreenProps {
  batches: MediaBatch[];
  clds: Cld[];
  villages: Village[];
  missions: Mission[];
  onOpenNewBatch: () => void;
  onOpenBatchDetail: (batch: MediaBatch) => void;
  onSyncPending: () => void;
  isSyncing: boolean;
}

export const MediaScreen: React.FC<MediaScreenProps> = ({
  batches,
  clds,
  villages,
  missions,
  onOpenNewBatch,
  onOpenBatchDetail,
  onSyncPending,
  isSyncing,
}) => {
  const pendingBatches = batches.filter((b) => b.syncStatus === 'pending');

  const getCldName = (id?: number) => {
    if (!id) return null;
    return clds.find((c) => c.id === id)?.nom;
  };

  const getVillageName = (id?: number) => {
    if (!id) return null;
    return villages.find((v) => v.id === id)?.nom;
  };

  const getMissionTitle = (id?: number) => {
    if (!id) return null;
    return missions.find((m) => m.id === id)?.titre;
  };

  return (
    <div className="p-4 space-y-4 max-w-4xl mx-auto pb-24">
      {/* Header & Title */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900">Mes lots de médias</h2>
          <p className="text-xs text-slate-500">
            Documentation visuelle des activités et parcelles sur le terrain
          </p>
        </div>

        <button
          id="btn-new-media-batch-top"
          onClick={onOpenNewBatch}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-xs transition-colors"
        >
          <Plus className="w-4 h-4" />
          <span>Nouveau lot</span>
        </button>
      </div>

      {/* Sync Banner if pending */}
      {pendingBatches.length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3.5 flex items-center justify-between shadow-xs">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-amber-500 text-white flex items-center justify-center shrink-0">
              <RefreshCw className="w-4 h-4 animate-spin" />
            </div>
            <div>
              <div className="text-xs font-bold text-amber-900">
                {pendingBatches.length} lot(s) en attente de synchronisation
              </div>
              <div className="text-[11px] text-amber-700">
                Conservés localement sur l'appareil
              </div>
            </div>
          </div>

          <button
            id="sync-pending-batches-btn"
            onClick={onSyncPending}
            disabled={isSyncing}
            className="px-3 py-1.5 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-xs font-bold shadow-xs transition-colors disabled:opacity-50 shrink-0"
          >
            {isSyncing ? 'Envoi...' : 'Synchroniser'}
          </button>
        </div>
      )}

      {/* Batches List */}
      {batches.length === 0 ? (
        <div className="bg-white rounded-2xl p-10 border border-slate-200 text-center space-y-4">
          <div className="w-14 h-14 rounded-2xl bg-teal-50 text-teal-600 flex items-center justify-center mx-auto">
            <Camera className="w-7 h-7" />
          </div>
          <div className="space-y-1">
            <h3 className="font-bold text-slate-800 text-base">Aucun lot de médias enregistré</h3>
            <p className="text-xs text-slate-500 max-w-sm mx-auto">
              Prenez ou importez des photos pour documenter les réunions, les pépinières ou le bornage des parcelles lors de vos missions.
            </p>
          </div>
          <button
            id="btn-create-first-batch"
            onClick={onOpenNewBatch}
            className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-xs transition-colors"
          >
            <Plus className="w-4 h-4" />
            Créer un premier lot de photos
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {batches.map((batch) => {
            const cldName = getCldName(batch.cldId);
            const villageName = getVillageName(batch.villageId);
            const missionTitle = getMissionTitle(batch.missionId);
            const coverImage = batch.items[0]?.dataUrl;

            return (
              <div
                key={batch.id}
                id={`media-batch-${batch.id}`}
                onClick={() => onOpenBatchDetail(batch)}
                className="bg-white rounded-xl p-3.5 border border-slate-200 hover:border-teal-300 hover:shadow-xs transition-all cursor-pointer flex items-center gap-3.5"
              >
                {/* Photo Thumbnail */}
                <div className="w-16 h-16 rounded-xl bg-slate-100 border border-slate-200 overflow-hidden shrink-0 relative flex items-center justify-center">
                  {coverImage ? (
                    <img src={coverImage} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <ImageIcon className="w-6 h-6 text-slate-400" />
                  )}
                  <span className="absolute bottom-1 right-1 bg-black/70 text-white text-[10px] font-bold px-1.5 py-0.2 rounded">
                    {batch.items.length}
                  </span>
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-1">
                    <h3 className="font-bold text-slate-900 text-sm truncate">
                      {batch.activity || 'Activité de terrain'}
                    </h3>
                    <span className="shrink-0">
                      {batch.syncStatus === 'synced' ? (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                          <span className="hidden sm:inline">Synchronisé</span>
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                          <Clock className="w-3 h-3 text-amber-600" />
                          <span className="hidden sm:inline">En attente</span>
                        </span>
                      )}
                    </span>
                  </div>

                  <p className="text-xs text-slate-500 mt-0.5 truncate">
                    {missionTitle ? `Mission : ${missionTitle}` : 'Hors mission'}
                  </p>

                  <div className="flex items-center gap-2 text-[11px] text-slate-400 mt-1">
                    {(cldName || villageName) && (
                      <span className="flex items-center gap-1 text-slate-600 truncate">
                        <MapPin className="w-3 h-3 text-slate-400" />
                        {cldName} {villageName ? `· ${villageName}` : ''}
                      </span>
                    )}
                    <span>·</span>
                    <span>{new Date(batch.createdAt).toLocaleDateString('fr-FR')}</span>
                  </div>
                </div>

                <ChevronRight className="w-5 h-5 text-slate-400 shrink-0" />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
