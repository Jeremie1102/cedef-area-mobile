import React from 'react';
import { 
  Navigation, 
  RefreshCw, 
  MapPin, 
  Clock, 
  CheckCircle2, 
  Route, 
  ChevronRight,
  Sparkles
} from 'lucide-react';
import { Mission, GpsPosition } from '../types';

interface TracksScreenProps {
  missions: Mission[];
  gpsPositions: GpsPosition[];
  onOpenTrackDetail: (mission: Mission, positions: GpsPosition[]) => void;
  onSyncGps: () => void;
  isSyncing: boolean;
}

export const TracksScreen: React.FC<TracksScreenProps> = ({
  missions,
  gpsPositions,
  onOpenTrackDetail,
  onSyncGps,
  isSyncing,
}) => {
  // Group tracks by mission that have at least 1 recorded position
  const missionsWithTracks = missions
    .map((m) => {
      const positions = gpsPositions.filter((g) => g.missionId === m.id);
      return { mission: m, positions };
    })
    .filter((t) => t.positions.length > 0);

  const pendingGpsCount = gpsPositions.filter((g) => g.syncStatus === 'pending').length;

  const calculateDistance = (positions: GpsPosition[]): number => {
    if (positions.length < 2) return 0;
    let total = 0;
    for (let i = 1; i < positions.length; i++) {
      const p1 = positions[i - 1];
      const p2 = positions[i];
      // Haversine approximation in km
      const R = 6371; // Earth radius in km
      const dLat = ((p2.latitude - p1.latitude) * Math.PI) / 180;
      const dLon = ((p2.longitude - p1.longitude) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((p1.latitude * Math.PI) / 180) *
          Math.cos((p2.latitude * Math.PI) / 180) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      total += R * c;
    }
    return total;
  };

  return (
    <div className="p-4 space-y-4 max-w-4xl mx-auto pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900">Mes parcours GPS</h2>
          <p className="text-xs text-slate-500">
            Traces et relevés d'itinéraires enregistrés lors des missions
          </p>
        </div>
      </div>

      {/* GPS Sync Banner */}
      {pendingGpsCount > 0 && (
        <div className="bg-sky-50 border border-sky-200 rounded-xl p-3.5 flex items-center justify-between shadow-xs">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-sky-600 text-white flex items-center justify-center shrink-0">
              <RefreshCw className="w-4 h-4 animate-spin" />
            </div>
            <div>
              <div className="text-xs font-bold text-sky-900">
                {pendingGpsCount} position(s) GPS en attente
              </div>
              <div className="text-[11px] text-sky-700">
                Relevées hors ligne, prêtes pour le serveur SIG
              </div>
            </div>
          </div>

          <button
            id="sync-gps-positions-btn"
            onClick={onSyncGps}
            disabled={isSyncing}
            className="px-3 py-1.5 bg-sky-600 hover:bg-sky-700 text-white rounded-lg text-xs font-bold shadow-xs transition-colors disabled:opacity-50 shrink-0"
          >
            {isSyncing ? 'Envoi...' : 'Synchroniser GPS'}
          </button>
        </div>
      )}

      {/* Tracks List */}
      {missionsWithTracks.length === 0 ? (
        <div className="bg-white rounded-2xl p-10 border border-slate-200 text-center space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-sky-50 text-sky-600 flex items-center justify-center mx-auto">
            <Navigation className="w-7 h-7" />
          </div>
          <div className="space-y-1">
            <h3 className="font-bold text-slate-800 text-base">Aucun parcours enregistré</h3>
            <p className="text-xs text-slate-500 max-w-sm mx-auto">
              Un parcours s'enregistre automatiquement dès que vous démarrez une mission sur le terrain.
            </p>
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          {missionsWithTracks.map(({ mission, positions }) => {
            const distanceKm = calculateDistance(positions);
            const firstPos = positions[0];
            const lastPos = positions[positions.length - 1];
            const hasPending = positions.some((p) => p.syncStatus === 'pending');

            return (
              <div
                key={mission.id}
                id={`track-card-mission-${mission.id}`}
                onClick={() => onOpenTrackDetail(mission, positions)}
                className="bg-white rounded-xl p-4 border border-slate-200 hover:border-sky-300 hover:shadow-xs transition-all cursor-pointer space-y-3"
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-xl bg-sky-100 text-sky-700 flex items-center justify-center shrink-0 mt-0.5">
                      <Route className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-900 text-sm leading-snug">
                        {mission.titre}
                      </h3>
                      <div className="text-xs text-slate-500 mt-0.5">
                        Mission #{mission.id} · {new Date(firstPos.recordedAt).toLocaleDateString('fr-FR')}
                      </div>
                    </div>
                  </div>

                  {hasPending ? (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                      <Clock className="w-3 h-3 text-amber-600" />
                      En attente
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                      <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                      Synchronisé
                    </span>
                  )}
                </div>

                {/* Track metrics */}
                <div className="grid grid-cols-3 gap-2 bg-slate-50 p-2.5 rounded-lg border border-slate-100 text-center">
                  <div>
                    <div className="text-[10px] text-slate-400 font-bold uppercase">Points GPS</div>
                    <div className="text-xs font-bold text-slate-800">{positions.length}</div>
                  </div>
                  <div>
                    <div className="text-[10px] text-slate-400 font-bold uppercase">Distance est.</div>
                    <div className="text-xs font-bold text-sky-700">
                      {distanceKm > 0 ? `${distanceKm.toFixed(2)} km` : '< 100 m'}
                    </div>
                  </div>
                  <div>
                    <div className="text-[10px] text-slate-400 font-bold uppercase">Précision</div>
                    <div className="text-xs font-bold text-slate-800">±{lastPos?.accuracy || 5}m</div>
                  </div>
                </div>

                <div className="flex items-center justify-between text-xs font-semibold text-sky-700 pt-0.5">
                  <span>Afficher la trace sur carte & détails</span>
                  <ChevronRight className="w-4 h-4" />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
