import React, { useState } from 'react';
import { 
  X, 
  MapPin, 
  Calendar, 
  CheckCircle2, 
  Clock, 
  FileText, 
  Camera, 
  Navigation, 
  ExternalLink,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
import { MediaBatch, Cld, Village, Mission } from '../types';

interface MediaBatchDetailModalProps {
  batch: MediaBatch;
  clds: Cld[];
  villages: Village[];
  missions: Mission[];
  onClose: () => void;
}

export const MediaBatchDetailModal: React.FC<MediaBatchDetailModalProps> = ({
  batch,
  clds,
  villages,
  missions,
  onClose,
}) => {
  const [selectedPhotoIndex, setSelectedPhotoIndex] = useState<number | null>(null);

  const cld = clds.find((c) => c.id === batch.cldId);
  const village = villages.find((v) => v.id === batch.villageId);
  const mission = missions.find((m) => m.id === batch.missionId);

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto">
      <div className="bg-white w-full max-w-lg rounded-t-2xl sm:rounded-2xl max-h-[90vh] flex flex-col shadow-2xl animate-in fade-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="p-4 border-b border-slate-200 flex items-start justify-between bg-slate-50 rounded-t-2xl">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-bold uppercase tracking-wider mb-1 bg-teal-100 text-teal-800">
              Lot #{batch.id} · {batch.items.length} photo(s)
            </div>
            <h3 className="text-base font-bold text-slate-900 leading-snug">
              {batch.activity || 'Activité de terrain'}
            </h3>
          </div>
          <button
            id="close-batch-detail-modal"
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-4 overflow-y-auto space-y-4 text-xs text-slate-700">
          {/* Sync Status Badge */}
          <div className="flex items-center justify-between bg-slate-50 p-3 rounded-xl border border-slate-200">
            <span className="font-bold text-slate-700">État de synchronisation</span>
            {batch.syncStatus === 'synced' ? (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full font-bold text-emerald-800 bg-emerald-100 border border-emerald-300">
                <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                Synchronisé avec le serveur
              </span>
            ) : (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full font-bold text-amber-800 bg-amber-100 border border-amber-300">
                <Clock className="w-3.5 h-3.5 text-amber-600" />
                En attente d'envoi
              </span>
            )}
          </div>

          {/* Mission & Territory Info */}
          <div className="grid grid-cols-2 gap-2">
            <div className="bg-slate-50 p-2.5 rounded-lg border border-slate-100">
              <div className="text-[10px] uppercase font-bold text-slate-400">Mission</div>
              <div className="font-semibold text-slate-900 truncate">
                {mission ? `#${mission.id} ${mission.titre}` : 'Hors mission'}
              </div>
            </div>

            <div className="bg-slate-50 p-2.5 rounded-lg border border-slate-100">
              <div className="text-[10px] uppercase font-bold text-slate-400">Territoire</div>
              <div className="font-semibold text-slate-900 truncate">
                {cld?.nom || '-'} {village ? `(${village.nom})` : ''}
              </div>
            </div>
          </div>

          {/* Description */}
          {batch.description && (
            <div className="space-y-1">
              <span className="font-bold text-slate-700 uppercase tracking-wider text-[10px]">
                Description de l'activité
              </span>
              <p className="p-3 bg-slate-50 rounded-lg border border-slate-200 whitespace-pre-line text-slate-800 leading-relaxed">
                {batch.description}
              </p>
            </div>
          )}

          {/* GPS Location Tag */}
          {batch.latitude && batch.longitude && (
            <div className="p-3 bg-slate-900 text-slate-100 rounded-xl space-y-1 font-mono">
              <div className="flex items-center gap-1.5 text-emerald-400 font-bold text-[11px]">
                <Navigation className="w-3.5 h-3.5" />
                Coordonnées GPS capturées
              </div>
              <div className="text-slate-300 text-[11px]">
                Lat: {batch.latitude.toFixed(5)} · Lon: {batch.longitude.toFixed(5)}
              </div>
            </div>
          )}

          {/* Photos Grid */}
          <div className="space-y-2 pt-2">
            <span className="font-bold text-slate-900 uppercase tracking-wider text-[10px]">
              Galerie des photos ({batch.items.length})
            </span>

            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {batch.items.map((item, index) => (
                <div
                  key={item.id}
                  onClick={() => setSelectedPhotoIndex(index)}
                  className="rounded-xl overflow-hidden border border-slate-200 aspect-square bg-slate-100 relative group cursor-pointer hover:opacity-90 transition-opacity"
                >
                  <img src={item.dataUrl} alt={item.fileName} className="w-full h-full object-cover" />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity flex items-end p-2">
                    <span className="text-white text-[10px] truncate">{item.fileName}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 bg-slate-50 border-t border-slate-200 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-900 text-white rounded-xl text-xs font-bold transition-colors"
          >
            Fermer
          </button>
        </div>
      </div>

      {/* Fullscreen Photo Lightbox */}
      {selectedPhotoIndex !== null && (
        <div className="fixed inset-0 z-60 bg-black/95 flex flex-col items-center justify-between p-4 animate-in fade-in">
          <div className="w-full flex items-center justify-between text-white">
            <div className="text-xs font-medium">
              Photo {selectedPhotoIndex + 1} / {batch.items.length} · {batch.items[selectedPhotoIndex].fileName}
            </div>
            <button
              onClick={() => setSelectedPhotoIndex(null)}
              className="p-2 rounded-full bg-white/20 hover:bg-white/30 text-white"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <div className="relative max-w-2xl max-h-[75vh] flex items-center justify-center">
            <img
              src={batch.items[selectedPhotoIndex].dataUrl}
              alt=""
              className="max-h-[75vh] max-w-full rounded-lg object-contain shadow-2xl"
            />
          </div>

          <div className="flex items-center gap-4 text-white pb-2">
            <button
              disabled={selectedPhotoIndex === 0}
              onClick={() => setSelectedPhotoIndex((i) => (i !== null && i > 0 ? i - 1 : i))}
              className="px-3 py-1.5 rounded-lg bg-white/20 hover:bg-white/30 disabled:opacity-30 text-xs font-bold flex items-center gap-1"
            >
              <ChevronLeft className="w-4 h-4" /> Précédente
            </button>
            <button
              disabled={selectedPhotoIndex === batch.items.length - 1}
              onClick={() => setSelectedPhotoIndex((i) => (i !== null && i < batch.items.length - 1 ? i + 1 : i))}
              className="px-3 py-1.5 rounded-lg bg-white/20 hover:bg-white/30 disabled:opacity-30 text-xs font-bold flex items-center gap-1"
            >
              Suivante <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
