import React, { useState } from 'react';
import { 
  X, 
  Play, 
  Pause, 
  CheckCircle2, 
  Calendar, 
  MapPin, 
  Navigation, 
  Camera, 
  FileText, 
  AlertCircle,
  Clock,
  Layers,
  ChevronRight
} from 'lucide-react';
import { Mission, Secteur, Groupement, Cld, Village, GpsPosition, MediaBatch } from '../types';

interface MissionDetailModalProps {
  mission: Mission;
  secteurs: Secteur[];
  groupements: Groupement[];
  clds: Cld[];
  villages: Village[];
  gpsPositions: GpsPosition[];
  mediaBatches: MediaBatch[];
  onClose: () => void;
  onStart: (id: number) => void;
  onPause: (id: number) => void;
  onResume: (id: number) => void;
  onComplete: (id: number, observation?: string) => void;
  onOpenNewMedia: (missionId: number, cldId?: number) => void;
  onOpenMediaBatch: (batch: MediaBatch) => void;
}

export const MissionDetailModal: React.FC<MissionDetailModalProps> = ({
  mission,
  secteurs,
  groupements,
  clds,
  villages,
  gpsPositions,
  mediaBatches,
  onClose,
  onStart,
  onPause,
  onResume,
  onComplete,
  onOpenNewMedia,
  onOpenMediaBatch,
}) => {
  const [showCompletePrompt, setShowCompletePrompt] = useState(false);
  const [observationText, setObservationText] = useState(mission.endObservation || '');

  const secteur = secteurs.find((s) => s.id === mission.secteurId);
  const cld = clds.find((c) => c.id === mission.cldId);
  const relatedVillages = cld ? villages.filter((v) => v.cldId === cld.id) : [];

  const missionGps = gpsPositions.filter((g) => g.missionId === mission.id);
  const lastGps = missionGps[missionGps.length - 1];

  const missionBatches = mediaBatches.filter((b) => b.missionId === mission.id);

  const handleFinishComplete = () => {
    onComplete(mission.id, observationText.trim());
    setShowCompletePrompt(false);
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto">
      <div className="bg-white w-full max-w-lg rounded-t-2xl sm:rounded-2xl max-h-[90vh] flex flex-col shadow-2xl animate-in fade-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="p-4 border-b border-slate-200 flex items-start justify-between bg-slate-50 rounded-t-2xl">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-bold uppercase tracking-wider mb-1 bg-slate-200 text-slate-800">
              Mission #{mission.id}
            </div>
            <h3 className="text-lg font-bold text-slate-900 leading-snug">
              {mission.titre}
            </h3>
          </div>
          <button
            id="close-mission-detail"
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-4 overflow-y-auto space-y-4 text-sm text-slate-700 divide-y divide-slate-100">
          {/* Status & Timing */}
          <div className="space-y-3 pb-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Statut actuel
              </span>
              <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                mission.statut === 'in_progress'
                  ? 'bg-emerald-100 text-emerald-800'
                  : mission.statut === 'paused'
                  ? 'bg-blue-100 text-blue-800'
                  : mission.statut === 'completed'
                  ? 'bg-slate-100 text-slate-800'
                  : 'bg-amber-100 text-amber-800'
              }`}>
                {mission.statut === 'in_progress' && '🟢 En cours (GPS actif)'}
                {mission.statut === 'paused' && '⏸ En pause'}
                {mission.statut === 'completed' && '✅ Terminée'}
                {mission.statut === 'pending' && '⏳ À faire'}
              </span>
            </div>

            <div className="flex items-center gap-2 text-xs text-slate-600 bg-slate-50 p-2.5 rounded-lg border border-slate-100">
              <Calendar className="w-4 h-4 text-slate-400" />
              <span>
                Période : {mission.dateDebut || 'Non spécifiée'} {mission.dateFin ? `au ${mission.dateFin}` : ''}
              </span>
            </div>

            {mission.startedAt && (
              <div className="text-xs text-slate-500 flex items-center gap-2">
                <Clock className="w-3.5 h-3.5" />
                <span>Démarrée le {new Date(mission.startedAt).toLocaleString('fr-FR')}</span>
              </div>
            )}

            {mission.endedAt && (
              <div className="text-xs text-slate-500 flex items-center gap-2">
                <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                <span>Terminée le {new Date(mission.endedAt).toLocaleString('fr-FR')}</span>
              </div>
            )}
          </div>

          {/* Instructions */}
          <div className="space-y-1.5 pt-3 pb-3">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
              <FileText className="w-3.5 h-3.5" />
              Instructions de terrain
            </span>
            <p className="text-xs text-slate-700 bg-slate-50 p-3 rounded-lg border border-slate-200/60 whitespace-pre-line leading-relaxed">
              {mission.instructions || 'Aucune instruction spécifique fournie.'}
            </p>
          </div>

          {/* Observation de fin si complétée */}
          {mission.statut === 'completed' && mission.endObservation && (
            <div className="space-y-1.5 pt-3 pb-3">
              <span className="text-xs font-bold text-emerald-800 uppercase tracking-wider">
                Observation finale de l'agent
              </span>
              <p className="text-xs text-slate-800 bg-emerald-50/60 p-3 rounded-lg border border-emerald-200">
                {mission.endObservation}
              </p>
            </div>
          )}

          {/* Territory */}
          <div className="space-y-2 pt-3 pb-3">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
              <MapPin className="w-3.5 h-3.5" />
              Territoire concerné
            </span>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <div className="bg-slate-50 p-2.5 rounded-lg border border-slate-100">
                <div className="text-slate-400 text-[10px] uppercase font-bold">Secteur</div>
                <div className="font-semibold text-slate-900">{secteur?.nom || '-'}</div>
              </div>
              <div className="bg-slate-50 p-2.5 rounded-lg border border-slate-100">
                <div className="text-slate-400 text-[10px] uppercase font-bold">CLD</div>
                <div className="font-semibold text-slate-900">{cld?.nom || '-'}</div>
              </div>
            </div>
            {relatedVillages.length > 0 && (
              <div className="text-xs text-slate-600 bg-slate-50 p-2 rounded-lg">
                <span className="font-bold">Villages : </span>
                {relatedVillages.map((v) => v.nom).join(', ')}
              </div>
            )}
          </div>

          {/* GPS Tracking Live Status */}
          <div className="space-y-2 pt-3 pb-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
                <Navigation className="w-3.5 h-3.5" />
                Suivi GPS & Parcours
              </span>
              <span className="text-xs font-semibold text-slate-600">
                {missionGps.length} position(s)
              </span>
            </div>

            <div className="bg-slate-900 text-slate-100 p-3 rounded-xl space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className={`w-2.5 h-2.5 rounded-full ${
                    mission.statut === 'in_progress' ? 'bg-emerald-400 animate-ping' : 'bg-slate-500'
                  }`} />
                  <span className="text-xs font-bold">
                    {mission.statut === 'in_progress' ? 'Relevé GPS continu' : 'Trace GPS clôturée'}
                  </span>
                </div>
                {lastGps && (
                  <span className="text-[10px] text-slate-400 font-mono">
                    Précision: ±{lastGps.accuracy}m
                  </span>
                )}
              </div>

              {lastGps ? (
                <div className="font-mono text-xs text-emerald-400 bg-slate-800/80 p-2 rounded border border-slate-700">
                  Lat: {lastGps.latitude.toFixed(5)} · Lon: {lastGps.longitude.toFixed(5)} · Alt: {lastGps.altitude || 410}m
                </div>
              ) : (
                <div className="text-xs text-slate-400 italic">
                  Aucune position GPS enregistrée pour le moment.
                </div>
              )}
            </div>
          </div>

          {/* Media Batches for this mission */}
          <div className="space-y-2 pt-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
                <Camera className="w-3.5 h-3.5" />
                Lots de médias ({missionBatches.length})
              </span>
              <button
                id="add-media-batch-to-mission"
                onClick={() => onOpenNewMedia(mission.id, mission.cldId)}
                className="text-xs text-emerald-700 hover:text-emerald-800 font-bold flex items-center gap-1 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200"
              >
                + Ajouter des photos
              </button>
            </div>

            {missionBatches.length === 0 ? (
              <p className="text-xs text-slate-400 italic bg-slate-50 p-2.5 rounded-lg border border-slate-100">
                Aucun lot de photos rattaché à cette mission.
              </p>
            ) : (
              <div className="space-y-1.5">
                {missionBatches.map((b) => (
                  <div
                    key={b.id}
                    onClick={() => onOpenMediaBatch(b)}
                    className="p-2.5 bg-slate-50 hover:bg-slate-100 rounded-lg border border-slate-200 flex items-center justify-between cursor-pointer transition-colors"
                  >
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded bg-slate-200 overflow-hidden flex items-center justify-center">
                        {b.items[0] ? (
                          <img src={b.items[0].dataUrl} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <Camera className="w-4 h-4 text-slate-400" />
                        )}
                      </div>
                      <div>
                        <div className="text-xs font-bold text-slate-800 truncate max-w-[200px]">
                          {b.activity || 'Activité sans titre'}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          {b.items.length} photo(s) · {b.syncStatus === 'synced' ? '🟢 Synchronisé' : '🟠 En attente'}
                        </div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400" />
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Observation Completion Dialog */}
        {showCompletePrompt && (
          <div className="p-4 bg-emerald-50 border-t border-emerald-200 space-y-3">
            <h4 className="text-xs font-bold uppercase tracking-wider text-emerald-900">
              Clôturer la mission
            </h4>
            <p className="text-xs text-slate-600">
              Le suivi GPS sera arrêté et la mission sera marquée comme terminée. Vous pouvez ajouter une observation de fin de mission ci-dessous :
            </p>
            <textarea
              id="mission-observation-input"
              value={observationText}
              onChange={(e) => setObservationText(e.target.value)}
              placeholder="Ex: Réunion tenue avec 25 participants. Délimitation effectuée sans incident..."
              className="w-full p-2.5 text-xs bg-white border border-emerald-300 rounded-lg focus:outline-hidden focus:ring-2 focus:ring-emerald-500"
              rows={3}
            />
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setShowCompletePrompt(false)}
                className="px-3 py-1.5 text-xs font-semibold text-slate-600 bg-white border border-slate-200 rounded-lg hover:bg-slate-50"
              >
                Annuler
              </button>
              <button
                id="confirm-complete-mission"
                onClick={handleFinishComplete}
                className="px-4 py-1.5 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-lg shadow-xs"
              >
                Confirmer la fin
              </button>
            </div>
          </div>
        )}

        {/* Action Buttons Footer */}
        {!showCompletePrompt && (
          <div className="p-4 bg-slate-50 border-t border-slate-200 flex items-center justify-between gap-2">
            {mission.statut === 'pending' && (
              <button
                id="start-mission-action"
                onClick={() => onStart(mission.id)}
                className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-2 shadow-xs transition-colors"
              >
                <Play className="w-4 h-4 fill-white" />
                Démarrer la mission (Activer GPS)
              </button>
            )}

            {mission.statut === 'in_progress' && (
              <div className="flex w-full gap-2">
                <button
                  id="pause-mission-action"
                  onClick={() => onPause(mission.id)}
                  className="flex-1 py-2.5 bg-white border border-slate-300 hover:bg-slate-100 text-slate-800 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-colors"
                >
                  <Pause className="w-4 h-4" />
                  Mettre en pause
                </button>
                <button
                  id="complete-mission-action"
                  onClick={() => setShowCompletePrompt(true)}
                  className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-xs transition-colors"
                >
                  <CheckCircle2 className="w-4 h-4" />
                  Terminer la mission
                </button>
              </div>
            )}

            {mission.statut === 'paused' && (
              <div className="flex w-full gap-2">
                <button
                  id="resume-mission-action"
                  onClick={() => onResume(mission.id)}
                  className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-xs transition-colors"
                >
                  <Play className="w-4 h-4 fill-white" />
                  Reprendre la mission
                </button>
                <button
                  id="complete-paused-mission-action"
                  onClick={() => setShowCompletePrompt(true)}
                  className="flex-1 py-2.5 bg-slate-800 hover:bg-slate-900 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-colors"
                >
                  <CheckCircle2 className="w-4 h-4" />
                  Terminer
                </button>
              </div>
            )}

            {mission.statut === 'completed' && (
              <div className="w-full py-2 text-center text-xs font-bold text-slate-500 flex items-center justify-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                Mission archivée et clôturée
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
