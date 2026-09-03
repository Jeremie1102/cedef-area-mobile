import React from 'react';
import { 
  Users, 
  ClipboardList, 
  Camera, 
  Navigation, 
  MapPin, 
  User as UserIcon, 
  ChevronRight, 
  Play, 
  CheckCircle2, 
  Clock, 
  Activity, 
  RefreshCw,
  Sparkles,
  Layers
} from 'lucide-react';
import { User, Mission } from '../types';
import { NavTab } from './BottomNav';

interface HomeScreenProps {
  user: User;
  missions: Mission[];
  cldsCount: number;
  pendingMediaCount: number;
  isOnline: boolean;
  onNavigate: (tab: NavTab) => void;
  onOpenMission: (mission: Mission) => void;
  onOpenSync: () => void;
}

export const HomeScreen: React.FC<HomeScreenProps> = ({
  user,
  missions,
  cldsCount,
  pendingMediaCount,
  isOnline,
  onNavigate,
  onOpenMission,
  onOpenSync,
}) => {
  const getFonctionLabel = (fonction: string) => {
    switch (fonction) {
      case 'animateur':
        return 'Animateur de terrain';
      case 'mrv':
        return 'Agent MRV (Mesure, Notification et Vérification)';
      case 'sauvegarde':
        return 'Agent de sauvegarde environnementale';
      case 'sig':
        return 'Agent SIG & Cartographie';
      default:
        return 'Agent terrain';
    }
  };

  const activeMission = missions.find((m) => m.statut === 'in_progress' || m.statut === 'paused');

  return (
    <div className="p-4 space-y-5 max-w-4xl mx-auto pb-24">
      {/* Welcome Card */}
      <div className="bg-gradient-to-br from-emerald-800 to-teal-900 rounded-2xl p-5 text-white shadow-md relative overflow-hidden">
        <div className="absolute right-0 top-0 w-48 h-48 bg-white/5 rounded-full blur-2xl pointer-events-none transform translate-x-10 -translate-y-10" />
        <div className="flex items-start justify-between relative z-10">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-700/80 text-emerald-100 text-xs font-semibold uppercase tracking-wider mb-2">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-300 animate-pulse" />
              Agent actif
            </div>
            <h2 className="text-2xl font-extrabold tracking-tight">
              Bonjour {user.prenom} 👋
            </h2>
            <p className="text-emerald-100/90 text-sm mt-0.5">
              {getFonctionLabel(user.fonction)}
            </p>
            {user.matricule && (
              <p className="text-emerald-200/70 text-xs mt-1 font-mono">
                Matricule: {user.matricule}
              </p>
            )}
          </div>

          <div className="w-13 h-13 rounded-xl bg-white/10 border border-white/20 overflow-hidden flex items-center justify-center shadow-inner">
            {user.photoUrl ? (
              <img src={user.photoUrl} alt={user.prenom} className="w-full h-full object-cover" />
            ) : (
              <UserIcon className="w-7 h-7 text-white" />
            )}
          </div>
        </div>

        {/* Quick Stats in Header */}
        <div className="grid grid-cols-2 gap-3 mt-5 pt-4 border-t border-white/15">
          <div className="bg-white/10 backdrop-blur-xs rounded-xl p-3 flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-emerald-500/30 flex items-center justify-center text-emerald-200">
              <Users className="w-5 h-5" />
            </div>
            <div>
              <div className="text-xl font-bold">{cldsCount}</div>
              <div className="text-xs text-emerald-100/80">CLD assignés</div>
            </div>
          </div>

          <div className="bg-white/10 backdrop-blur-xs rounded-xl p-3 flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-teal-500/30 flex items-center justify-center text-teal-200">
              <ClipboardList className="w-5 h-5" />
            </div>
            <div>
              <div className="text-xl font-bold">{missions.length}</div>
              <div className="text-xs text-teal-100/80">Total missions</div>
            </div>
          </div>
        </div>
      </div>

      {/* Active Mission Live Alert Banner */}
      {activeMission && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 shadow-xs">
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-start gap-3">
              <div className="w-9 h-9 rounded-lg bg-amber-500 text-white flex items-center justify-center shrink-0 mt-0.5 animate-pulse">
                <Activity className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold uppercase tracking-wider text-amber-800 bg-amber-100 px-2 py-0.5 rounded">
                    {activeMission.statut === 'in_progress' ? '🟢 Mission en cours' : '⏸ En pause'}
                  </span>
                  <span className="text-xs text-slate-500">Suivi GPS actif</span>
                </div>
                <h3 className="font-bold text-slate-900 text-base mt-1">
                  {activeMission.titre}
                </h3>
                <p className="text-xs text-slate-600 mt-0.5 line-clamp-1">
                  {activeMission.instructions || 'Collecte et suivi de terrain en cours'}
                </p>
              </div>
            </div>

            <button
              id="view-active-mission-btn"
              onClick={() => onOpenMission(activeMission)}
              className="px-3 py-1.5 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-xs font-semibold shrink-0 transition-colors shadow-xs"
            >
              Gérer
            </button>
          </div>
        </div>
      )}

      {/* Module Navigation Grid */}
      <div className="space-y-2">
        <h3 className="text-xs font-bold text-slate-500 uppercase tracking-wider px-1">
          Modules principaux
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {/* Mes missions */}
          <button
            id="home-module-missions"
            onClick={() => onNavigate('missions')}
            className="flex items-center justify-between p-4 bg-white rounded-xl border border-slate-200 hover:border-emerald-300 hover:shadow-sm transition-all text-left group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-11 h-11 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center group-hover:scale-105 transition-transform">
                <ClipboardList className="w-6 h-6" />
              </div>
              <div>
                <div className="font-bold text-slate-900 text-base">Mes missions</div>
                <div className="text-xs text-slate-500">
                  {missions.filter((m) => m.statut === 'pending').length} à faire · {missions.filter((m) => m.statut === 'in_progress').length} en cours
                </div>
              </div>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400 group-hover:text-emerald-600 transition-colors" />
          </button>

          {/* Mes médias */}
          <button
            id="home-module-media"
            onClick={() => onNavigate('media')}
            className="flex items-center justify-between p-4 bg-white rounded-xl border border-slate-200 hover:border-emerald-300 hover:shadow-sm transition-all text-left group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-11 h-11 rounded-xl bg-teal-100 text-teal-700 flex items-center justify-center group-hover:scale-105 transition-transform">
                <Camera className="w-6 h-6" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-slate-900 text-base">Mes médias</span>
                  {pendingMediaCount > 0 && (
                    <span className="bg-amber-100 text-amber-800 text-[11px] font-bold px-2 py-0.5 rounded-full border border-amber-300">
                      {pendingMediaCount} en attente
                    </span>
                  )}
                </div>
                <div className="text-xs text-slate-500">Lots de photos d'activité terrain</div>
              </div>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400 group-hover:text-teal-600 transition-colors" />
          </button>

          {/* Mes parcours */}
          <button
            id="home-module-tracks"
            onClick={() => onNavigate('tracks')}
            className="flex items-center justify-between p-4 bg-white rounded-xl border border-slate-200 hover:border-emerald-300 hover:shadow-sm transition-all text-left group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-11 h-11 rounded-xl bg-sky-100 text-sky-700 flex items-center justify-center group-hover:scale-105 transition-transform">
                <Navigation className="w-6 h-6" />
              </div>
              <div>
                <div className="font-bold text-slate-900 text-base">Mes parcours</div>
                <div className="text-xs text-slate-500">Traces GPS & distances enregistrées</div>
              </div>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400 group-hover:text-sky-600 transition-colors" />
          </button>

          {/* Territoire / CLD */}
          <button
            id="home-module-territory"
            onClick={() => onNavigate('territory')}
            className="flex items-center justify-between p-4 bg-white rounded-xl border border-slate-200 hover:border-emerald-300 hover:shadow-sm transition-all text-left group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-11 h-11 rounded-xl bg-indigo-100 text-indigo-700 flex items-center justify-center group-hover:scale-105 transition-transform">
                <MapPin className="w-6 h-6" />
              </div>
              <div>
                <div className="font-bold text-slate-900 text-base">Territoire / CLD</div>
                <div className="text-xs text-slate-500">Secteurs, groupements & villages</div>
              </div>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400 group-hover:text-indigo-600 transition-colors" />
          </button>
        </div>
      </div>

      {/* Synchronization Quick Bar */}
      <div 
        onClick={onOpenSync}
        className="bg-white rounded-xl p-4 border border-slate-200 flex items-center justify-between cursor-pointer hover:bg-slate-50 transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center text-slate-700">
            <RefreshCw className="w-5 h-5" />
          </div>
          <div>
            <div className="text-sm font-bold text-slate-900">Synchronisation des données</div>
            <div className="text-xs text-slate-500 flex items-center gap-1.5 mt-0.5">
              <span className={`w-2 h-2 rounded-full ${isOnline ? 'bg-emerald-500' : 'bg-slate-400'}`} />
              {isOnline ? 'Mode connecté (Prêt à synchroniser)' : 'Mode hors-ligne (Stockage local SQLite/Local)'}
            </div>
          </div>
        </div>
        <ChevronRight className="w-5 h-5 text-slate-400" />
      </div>
    </div>
  );
};
