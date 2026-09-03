import React from 'react';
import { Home, ClipboardList, Camera, Navigation, MapPin, User, RefreshCw } from 'lucide-react';

export type NavTab = 'home' | 'missions' | 'media' | 'tracks' | 'territory' | 'sync' | 'profile';

interface BottomNavProps {
  currentTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
  pendingMediaCount: number;
  activeMissionCount: number;
}

export const BottomNav: React.FC<BottomNavProps> = ({
  currentTab,
  onSelectTab,
  pendingMediaCount,
  activeMissionCount,
}) => {
  const tabs = [
    { id: 'home' as NavTab, label: 'Accueil', icon: Home },
    { id: 'missions' as NavTab, label: 'Missions', icon: ClipboardList, badge: activeMissionCount > 0 ? activeMissionCount : undefined },
    { id: 'media' as NavTab, label: 'Médias', icon: Camera, badge: pendingMediaCount > 0 ? pendingMediaCount : undefined },
    { id: 'tracks' as NavTab, label: 'Parcours', icon: Navigation },
    { id: 'territory' as NavTab, label: 'Territoire', icon: MapPin },
    { id: 'profile' as NavTab, label: 'Profil', icon: User },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 bg-white/95 backdrop-blur-md border-t border-slate-200 px-2 py-1 shadow-lg">
      <div className="max-w-4xl mx-auto flex items-center justify-around">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = currentTab === tab.id;
          return (
            <button
              key={tab.id}
              id={`nav-tab-${tab.id}`}
              onClick={() => onSelectTab(tab.id)}
              className={`flex flex-col items-center justify-center py-1.5 px-2 relative rounded-lg transition-all ${
                isActive
                  ? 'text-emerald-700 font-semibold'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <div className="relative">
                <Icon className={`w-5 h-5 transition-transform ${isActive ? 'scale-110' : ''}`} />
                {tab.badge !== undefined && (
                  <span className="absolute -top-1.5 -right-2 bg-emerald-600 text-white text-[10px] font-bold px-1.5 py-0.2 rounded-full min-w-[16px] text-center shadow-xs">
                    {tab.badge}
                  </span>
                )}
              </div>
              <span className="text-[10px] mt-1 tracking-tight">
                {tab.label}
              </span>
              {isActive && (
                <span className="absolute bottom-0 w-6 h-0.5 bg-emerald-600 rounded-full" />
              )}
            </button>
          );
        })}
      </div>
    </nav>
  );
};
