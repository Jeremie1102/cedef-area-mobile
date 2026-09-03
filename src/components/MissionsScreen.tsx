import React, { useState } from 'react';
import { 
  ClipboardList, 
  Play, 
  Pause, 
  CheckCircle2, 
  Calendar, 
  MapPin, 
  ChevronRight, 
  Clock,
  Sparkles,
  Plus
} from 'lucide-react';
import { Mission, Secteur, Cld } from '../types';

interface MissionsScreenProps {
  missions: Mission[];
  secteurs: Secteur[];
  clds: Cld[];
  onSelectMission: (mission: Mission) => void;
  onResetDemoData: () => void;
}

export const MissionsScreen: React.FC<MissionsScreenProps> = ({
  missions,
  secteurs,
  clds,
  onSelectMission,
  onResetDemoData,
}) => {
  const [filter, setFilter] = useState<'all' | 'pending' | 'in_progress' | 'completed'>('all');

  const filteredMissions = missions.filter((m) => {
    if (filter === 'all') return true;
    if (filter === 'pending') return m.statut === 'pending';
    if (filter === 'in_progress') return m.statut === 'in_progress' || m.statut === 'paused';
    if (filter === 'completed') return m.statut === 'completed' || m.statut === 'cancelled';
    return true;
  });

  const getStatusBadge = (status: Mission['statut']) => {
    switch (status) {
      case 'pending':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-50 text-amber-800 border border-amber-200">
            <Clock className="w-3 h-3 text-amber-600" />
            À faire
          </span>
        );
      case 'in_progress':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-800 border border-emerald-200">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
            En cours (GPS actif)
          </span>
        );
      case 'paused':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-50 text-blue-800 border border-blue-200">
            <Pause className="w-3 h-3 text-blue-600" />
            En pause
          </span>
        );
      case 'completed':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200">
            <CheckCircle2 className="w-3 h-3 text-slate-500" />
            Terminée
          </span>
        );
      default:
        return null;
    }
  };

  const getSecteurName = (id?: number) => {
    if (!id) return '';
    return secteurs.find((s) => s.id === id)?.nom || '';
  };

  const getCldName = (id?: number) => {
    if (!id) return '';
    return clds.find((c) => c.id === id)?.nom || '';
  };

  const aFaire = missions.filter((m) => m.statut === 'pending');
  const enCours = missions.filter((m) => m.statut === 'in_progress' || m.statut === 'paused');
  const terminees = missions.filter((m) => m.statut === 'completed' || m.statut === 'cancelled');

  return (
    <div className="p-4 space-y-4 max-w-4xl mx-auto pb-24">
      {/* Header filter pills */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900">Mes missions</h2>
          <p className="text-xs text-slate-500">
            Missions attribuées par l'Assistant Technique
          </p>
        </div>

        <button
          onClick={onResetDemoData}
          className="text-xs text-emerald-700 hover:text-emerald-800 font-semibold px-2 py-1 bg-emerald-50 rounded-lg border border-emerald-200 transition-colors"
          title="Recharger les données de test"
        >
          Recharger démo
        </button>
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-1.5 bg-slate-200/80 p-1 rounded-xl">
        <button
          onClick={() => setFilter('all')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all ${
            filter === 'all'
              ? 'bg-white text-slate-900 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          Toutes ({missions.length})
        </button>
        <button
          onClick={() => setFilter('in_progress')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all ${
            filter === 'in_progress'
              ? 'bg-white text-slate-900 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          En cours ({enCours.length})
        </button>
        <button
          onClick={() => setFilter('pending')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all ${
            filter === 'pending'
              ? 'bg-white text-slate-900 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          À faire ({aFaire.length})
        </button>
        <button
          onClick={() => setFilter('completed')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all ${
            filter === 'completed'
              ? 'bg-white text-slate-900 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          Terminées ({terminees.length})
        </button>
      </div>

      {/* Mission List */}
      {filteredMissions.length === 0 ? (
        <div className="bg-white rounded-2xl p-8 border border-slate-200 text-center space-y-3">
          <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto">
            <ClipboardList className="w-6 h-6" />
          </div>
          <h3 className="font-bold text-slate-800 text-sm">Aucune mission dans cette catégorie</h3>
          <p className="text-xs text-slate-500 max-w-xs mx-auto">
            Les missions assignées par le superviseur apparaissent ici pour être exécutées et documentées hors ligne.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredMissions.map((mission) => {
            const secteurName = getSecteurName(mission.secteurId);
            const cldName = getCldName(mission.cldId);

            return (
              <div
                key={mission.id}
                id={`mission-card-${mission.id}`}
                onClick={() => onSelectMission(mission)}
                className="bg-white rounded-xl p-4 border border-slate-200 hover:border-emerald-300 hover:shadow-xs transition-all cursor-pointer space-y-3"
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="text-base font-bold text-slate-900 leading-snug">
                      {mission.titre}
                    </div>
                    {mission.description && (
                      <p className="text-xs text-slate-600 mt-1 line-clamp-1">
                        {mission.description}
                      </p>
                    )}
                  </div>
                  {getStatusBadge(mission.statut)}
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-slate-600 pt-2 border-t border-slate-100">
                  <div className="flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5 text-slate-400" />
                    <span>
                      {mission.dateDebut} {mission.dateFin ? `au ${mission.dateFin}` : ''}
                    </span>
                  </div>

                  {(secteurName || cldName) && (
                    <div className="flex items-center gap-1.5">
                      <MapPin className="w-3.5 h-3.5 text-slate-400" />
                      <span className="truncate">
                        {secteurName} {cldName ? `· ${cldName}` : ''}
                      </span>
                    </div>
                  )}
                </div>

                <div className="flex items-center justify-between text-xs font-semibold text-emerald-700 pt-1">
                  <span>Voir détails & actions</span>
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
