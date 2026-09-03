import React, { useState } from 'react';
import { 
  X, 
  Navigation, 
  MapPin, 
  Calendar, 
  Clock, 
  Route, 
  Layers,
  CheckCircle2,
  TrendingUp,
  Activity
} from 'lucide-react';
import { Mission, GpsPosition } from '../types';

interface TrackDetailModalProps {
  mission: Mission;
  positions: GpsPosition[];
  onClose: () => void;
}

export const TrackDetailModal: React.FC<TrackDetailModalProps> = ({
  mission,
  positions,
  onClose,
}) => {
  const [selectedPoint, setSelectedPoint] = useState<GpsPosition | null>(null);

  // Compute bounding box for SVG projection
  const lats = positions.map((p) => p.latitude);
  const lons = positions.map((p) => p.longitude);
  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLon = Math.min(...lons);
  const maxLon = Math.max(...lons);

  const padding = 0.001;
  const latSpan = maxLat - minLat || 0.002;
  const lonSpan = maxLon - minLon || 0.002;

  // Convert lat/lon to SVG 0..300 / 0..200
  const projectPoint = (lat: number, lon: number) => {
    const x = 30 + ((lon - minLon) / lonSpan) * 240;
    // Invert Y because SVG coordinates go top to bottom
    const y = 170 - ((lat - minLat) / latSpan) * 140;
    return { x, y };
  };

  const svgPoints = positions.map((p) => projectPoint(p.latitude, p.longitude));
  const svgPathD = svgPoints.reduce((acc, pt, idx) => {
    return idx === 0 ? `M ${pt.x} ${pt.y}` : `${acc} L ${pt.x} ${pt.y}`;
  }, '');

  const firstPos = positions[0];
  const lastPos = positions[positions.length - 1];

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto">
      <div className="bg-white w-full max-w-lg rounded-t-2xl sm:rounded-2xl max-h-[90vh] flex flex-col shadow-2xl animate-in fade-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="p-4 border-b border-slate-200 flex items-start justify-between bg-slate-50 rounded-t-2xl">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-bold uppercase tracking-wider mb-1 bg-sky-100 text-sky-800">
              Parcours Mission #{mission.id}
            </div>
            <h3 className="text-base font-bold text-slate-900 leading-snug">
              {mission.titre}
            </h3>
          </div>
          <button
            id="close-track-detail-modal"
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-4 overflow-y-auto space-y-4 text-xs text-slate-700">
          {/* Interactive Map Visualizer */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <span className="font-bold text-slate-800 uppercase tracking-wider text-[10px] flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5 text-sky-600" />
                Tracé cartographique du parcours
              </span>
              <span className="text-[10px] text-slate-500 font-mono">
                {positions.length} waypoints relevés
              </span>
            </div>

            <div className="bg-slate-950 rounded-xl p-3 border border-slate-800 relative overflow-hidden shadow-inner">
              {/* Map grid lines */}
              <div className="absolute inset-0 bg-[radial-gradient(#1e293b_1px,transparent_1px)] [background-size:16px_16px] opacity-70" />

              <svg viewBox="0 0 300 200" className="w-full h-44 relative z-10">
                {/* Track Line */}
                <path
                  d={svgPathD}
                  fill="none"
                  stroke="#38bdf8"
                  strokeWidth="3.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  className="drop-shadow-[0_0_8px_rgba(56,189,248,0.6)]"
                />

                {/* Waypoint Dots */}
                {positions.map((pos, idx) => {
                  const pt = projectPoint(pos.latitude, pos.longitude);
                  const isFirst = idx === 0;
                  const isLast = idx === positions.length - 1;
                  const isSelected = selectedPoint?.localId === pos.localId;

                  return (
                    <g key={pos.localId} onClick={() => setSelectedPoint(pos)} className="cursor-pointer">
                      <circle
                        cx={pt.x}
                        cy={pt.y}
                        r={isSelected ? 6 : isFirst || isLast ? 5 : 3}
                        fill={isFirst ? '#22c55e' : isLast ? '#ef4444' : '#38bdf8'}
                        stroke="#0f172a"
                        strokeWidth="1.5"
                      />
                    </g>
                  );
                })}
              </svg>

              {/* Legend & Start/Finish markers */}
              <div className="flex items-center justify-between text-[10px] text-slate-400 relative z-10 pt-1 border-t border-slate-800">
                <div className="flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-500" />
                  <span>Départ ({new Date(firstPos.recordedAt).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })})</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-rose-500" />
                  <span>Arrivée ({new Date(lastPos.recordedAt).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })})</span>
                </div>
              </div>
            </div>
          </div>

          {/* Selected Waypoint Inspection */}
          {selectedPoint ? (
            <div className="p-3 bg-sky-50 border border-sky-200 rounded-xl space-y-1 font-mono">
              <div className="flex items-center justify-between text-sky-900 font-bold text-[11px]">
                <span>Point sélectionné</span>
                <span>{new Date(selectedPoint.recordedAt).toLocaleTimeString('fr-FR')}</span>
              </div>
              <div className="text-slate-700 text-[11px]">
                Lat: {selectedPoint.latitude.toFixed(6)} · Lon: {selectedPoint.longitude.toFixed(6)}
              </div>
              <div className="text-slate-500 text-[10px]">
                Altitude: {selectedPoint.altitude || 410}m · Vitesse: {selectedPoint.speed || 1.2} km/h · Précision: ±{selectedPoint.accuracy}m
              </div>
            </div>
          ) : (
            <div className="text-center p-2 text-[11px] text-slate-400 italic">
              Touchez un point sur la trace ci-dessus pour inspecter les coordonnées exactes.
            </div>
          )}

          {/* Detailed Points Table */}
          <div className="space-y-2 pt-1">
            <span className="font-bold text-slate-900 uppercase tracking-wider text-[10px]">
              Historique des relevés ({positions.length})
            </span>

            <div className="border border-slate-200 rounded-xl overflow-hidden max-h-48 overflow-y-auto">
              <table className="w-full text-left border-collapse text-[11px]">
                <thead className="bg-slate-100 text-slate-600 sticky top-0">
                  <tr>
                    <th className="p-2">Heure</th>
                    <th className="p-2">Coordonnées</th>
                    <th className="p-2">Précision</th>
                    <th className="p-2 text-right">Statut</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 font-mono">
                  {positions.map((p, idx) => (
                    <tr
                      key={p.localId}
                      onClick={() => setSelectedPoint(p)}
                      className={`cursor-pointer hover:bg-slate-50 ${
                        selectedPoint?.localId === p.localId ? 'bg-sky-50 font-bold' : ''
                      }`}
                    >
                      <td className="p-2 text-slate-600">
                        {new Date(p.recordedAt).toLocaleTimeString('fr-FR')}
                      </td>
                      <td className="p-2 text-slate-900">
                        {p.latitude.toFixed(4)}, {p.longitude.toFixed(4)}
                      </td>
                      <td className="p-2 text-slate-500">±{p.accuracy}m</td>
                      <td className="p-2 text-right">
                        {p.syncStatus === 'synced' ? (
                          <span className="text-emerald-600 font-sans text-[10px]">Sync</span>
                        ) : (
                          <span className="text-amber-600 font-sans text-[10px]">Attente</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
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
    </div>
  );
};
