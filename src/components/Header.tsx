import React from 'react';
import { Wifi, WifiOff, RefreshCw, Layers } from 'lucide-react';
import { store } from '../services/store';

interface HeaderProps {
  title: string;
  isOnline: boolean;
  onToggleOnline: () => void;
  pendingCount: number;
  onOpenSync: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  title,
  isOnline,
  onToggleOnline,
  pendingCount,
  onOpenSync,
}) => {
  return (
    <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200 px-4 py-3 shadow-xs">
      <div className="max-w-4xl mx-auto flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg bg-emerald-600 flex items-center justify-center text-white font-bold text-sm shadow-xs">
            CA
          </div>
          <div>
            <h1 className="text-base font-bold tracking-tight text-slate-900 leading-tight">
              {title}
            </h1>
            <p className="text-[11px] font-medium text-emerald-700 tracking-wide uppercase">
              CEDEF AREA
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Quick sync button if items pending */}
          <button
            id="header-sync-button"
            onClick={onOpenSync}
            className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold transition-all ${
              pendingCount > 0
                ? 'bg-amber-100 text-amber-800 border border-amber-300 hover:bg-amber-200'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
            title="État de la synchronisation"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${pendingCount > 0 ? 'text-amber-700' : 'text-slate-500'}`} />
            <span>{pendingCount > 0 ? `${pendingCount} en attente` : 'Synchronisé'}</span>
          </button>

          {/* Online / Offline status toggle button */}
          <button
            id="network-toggle-button"
            onClick={onToggleOnline}
            className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium transition-all ${
              isOnline
                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100'
                : 'bg-rose-50 text-rose-700 border border-rose-200 hover:bg-rose-100'
            }`}
            title="Basculer le mode Connecté / Hors ligne pour simuler le terrain"
          >
            {isOnline ? (
              <>
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                <Wifi className="w-3.5 h-3.5 text-emerald-600" />
                <span className="hidden sm:inline">Connecté</span>
              </>
            ) : (
              <>
                <span className="w-2 h-2 rounded-full bg-rose-500" />
                <WifiOff className="w-3.5 h-3.5 text-rose-600" />
                <span className="hidden sm:inline">Hors-ligne</span>
              </>
            )}
          </button>
        </div>
      </div>
    </header>
  );
};
