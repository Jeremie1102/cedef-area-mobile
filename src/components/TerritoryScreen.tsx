import React, { useState } from 'react';
import { 
  MapPin, 
  Search, 
  ChevronRight, 
  Layers, 
  Building2, 
  Users, 
  Home as VillageIcon, 
  Sparkles,
  ArrowLeft,
  X
} from 'lucide-react';
import { Secteur, Groupement, Cld, Village } from '../types';

interface TerritoryScreenProps {
  secteurs: Secteur[];
  groupements: Groupement[];
  clds: Cld[];
  villages: Village[];
  onResetDemoData: () => void;
}

export const TerritoryScreen: React.FC<TerritoryScreenProps> = ({
  secteurs,
  groupements,
  clds,
  villages,
  onResetDemoData,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSecteur, setSelectedSecteur] = useState<Secteur | null>(null);
  const [selectedGroupement, setSelectedGroupement] = useState<Groupement | null>(null);
  const [selectedCld, setSelectedCld] = useState<Cld | null>(null);

  // Search across all 4 levels
  const query = searchQuery.trim().toLowerCase();
  const searchResults = query
    ? {
        secteurs: secteurs.filter((s) => s.nom.toLowerCase().includes(query) || s.code.toLowerCase().includes(query)),
        groupements: groupements.filter((g) => g.nom.toLowerCase().includes(query)),
        clds: clds.filter((c) => c.nom.toLowerCase().includes(query) || (c.code && c.code.toLowerCase().includes(query))),
        villages: villages.filter((v) => v.nom.toLowerCase().includes(query)),
      }
    : null;

  const isSearching = !!searchResults;

  const handleOpenSecteur = (s: Secteur) => {
    setSelectedSecteur(s);
    setSelectedGroupement(null);
    setSelectedCld(null);
    setSearchQuery('');
  };

  const handleOpenGroupement = (g: Groupement) => {
    const parentSecteur = secteurs.find((s) => s.id === g.secteurId);
    if (parentSecteur) setSelectedSecteur(parentSecteur);
    setSelectedGroupement(g);
    setSelectedCld(null);
    setSearchQuery('');
  };

  const handleOpenCld = (c: Cld) => {
    const parentGrp = groupements.find((g) => g.id === c.groupementId);
    if (parentGrp) {
      const parentSec = secteurs.find((s) => s.id === parentGrp.secteurId);
      if (parentSec) setSelectedSecteur(parentSec);
      setSelectedGroupement(parentGrp);
    }
    setSelectedCld(c);
    setSearchQuery('');
  };

  const currentGroupements = selectedSecteur
    ? groupements.filter((g) => g.secteurId === selectedSecteur.id)
    : [];

  const currentClds = selectedGroupement
    ? clds.filter((c) => c.groupementId === selectedGroupement.id)
    : [];

  const currentVillages = selectedCld
    ? villages.filter((v) => v.cldId === selectedCld.id)
    : [];

  return (
    <div className="p-4 space-y-4 max-w-4xl mx-auto pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900">Territoire / CLD</h2>
          <p className="text-xs text-slate-500">
            Hiérarchie territoriale : Secteur &gt; Groupement &gt; CLD &gt; Village
          </p>
        </div>
      </div>

      {/* Search Bar */}
      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input
          id="territory-search-input"
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Rechercher un secteur, groupement, CLD ou village..."
          className="w-full pl-10 pr-9 py-2.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-hidden focus:ring-2 focus:ring-emerald-500 shadow-xs"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Search Results Mode */}
      {isSearching ? (
        <div className="space-y-4">
          <div className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Résultats pour « {searchQuery} »
          </div>

          {searchResults.secteurs.length === 0 &&
          searchResults.groupements.length === 0 &&
          searchResults.clds.length === 0 &&
          searchResults.villages.length === 0 ? (
            <div className="bg-white rounded-xl p-8 border border-slate-200 text-center text-slate-500 text-xs">
              Aucun élément territorial correspondant trouvé.
            </div>
          ) : (
            <div className="space-y-3">
              {/* Secteurs */}
              {searchResults.secteurs.length > 0 && (
                <div className="space-y-1.5">
                  <span className="text-[11px] font-bold text-indigo-700 uppercase">Secteurs ({searchResults.secteurs.length})</span>
                  {searchResults.secteurs.map((s) => (
                    <div
                      key={s.id}
                      onClick={() => handleOpenSecteur(s)}
                      className="p-3 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <Building2 className="w-4 h-4 text-indigo-600" />
                        <div>
                          <div className="font-bold text-xs text-slate-900">{s.nom}</div>
                          <div className="text-[10px] text-slate-500 font-mono">Code: {s.code}</div>
                        </div>
                      </div>
                      <ChevronRight className="w-4 h-4 text-slate-400" />
                    </div>
                  ))}
                </div>
              )}

              {/* Groupements */}
              {searchResults.groupements.length > 0 && (
                <div className="space-y-1.5">
                  <span className="text-[11px] font-bold text-teal-700 uppercase">Groupements ({searchResults.groupements.length})</span>
                  {searchResults.groupements.map((g) => (
                    <div
                      key={g.id}
                      onClick={() => handleOpenGroupement(g)}
                      className="p-3 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <Layers className="w-4 h-4 text-teal-600" />
                        <div className="font-bold text-xs text-slate-900">{g.nom}</div>
                      </div>
                      <ChevronRight className="w-4 h-4 text-slate-400" />
                    </div>
                  ))}
                </div>
              )}

              {/* CLDs */}
              {searchResults.clds.length > 0 && (
                <div className="space-y-1.5">
                  <span className="text-[11px] font-bold text-emerald-700 uppercase">CLD ({searchResults.clds.length})</span>
                  {searchResults.clds.map((c) => (
                    <div
                      key={c.id}
                      onClick={() => handleOpenCld(c)}
                      className="p-3 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <Users className="w-4 h-4 text-emerald-600" />
                        <div>
                          <div className="font-bold text-xs text-slate-900">{c.nom}</div>
                          {c.code && <div className="text-[10px] text-slate-500 font-mono">{c.code}</div>}
                        </div>
                      </div>
                      <ChevronRight className="w-4 h-4 text-slate-400" />
                    </div>
                  ))}
                </div>
              )}

              {/* Villages */}
              {searchResults.villages.length > 0 && (
                <div className="space-y-1.5">
                  <span className="text-[11px] font-bold text-amber-700 uppercase">Villages ({searchResults.villages.length})</span>
                  {searchResults.villages.map((v) => {
                    const parentCld = clds.find((c) => c.id === v.cldId);
                    return (
                      <div
                        key={v.id}
                        onClick={() => parentCld && handleOpenCld(parentCld)}
                        className="p-3 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between cursor-pointer"
                      >
                        <div className="flex items-center gap-2.5">
                          <VillageIcon className="w-4 h-4 text-amber-600" />
                          <div>
                            <div className="font-bold text-xs text-slate-900">{v.nom}</div>
                            {parentCld && (
                              <div className="text-[10px] text-slate-500">Rattaché à : {parentCld.nom}</div>
                            )}
                          </div>
                        </div>
                        <ChevronRight className="w-4 h-4 text-slate-400" />
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>
      ) : (
        /* Hierarchical Explorer Mode */
        <div className="space-y-3">
          {/* Breadcrumb if drilled down */}
          {(selectedSecteur || selectedGroupement || selectedCld) && (
            <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-2.5 flex items-center gap-2 text-xs font-semibold text-emerald-900">
              <button
                onClick={() => {
                  setSelectedSecteur(null);
                  setSelectedGroupement(null);
                  setSelectedCld(null);
                }}
                className="hover:underline flex items-center gap-1"
              >
                <ArrowLeft className="w-3.5 h-3.5" />
                Secteurs
              </button>
              {selectedSecteur && (
                <>
                  <span>/</span>
                  <button
                    onClick={() => {
                      setSelectedGroupement(null);
                      setSelectedCld(null);
                    }}
                    className="hover:underline"
                  >
                    {selectedSecteur.nom}
                  </button>
                </>
              )}
              {selectedGroupement && (
                <>
                  <span>/</span>
                  <button
                    onClick={() => setSelectedCld(null)}
                    className="hover:underline"
                  >
                    {selectedGroupement.nom}
                  </button>
                </>
              )}
              {selectedCld && (
                <>
                  <span>/</span>
                  <span className="font-bold text-emerald-800">{selectedCld.nom}</span>
                </>
              )}
            </div>
          )}

          {/* Level 1: Secteurs List */}
          {!selectedSecteur && (
            <div className="space-y-3">
              <div className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Secteurs disponibles ({secteurs.length})
              </div>

              {secteurs.map((secteur) => {
                const sGroupements = groupements.filter((g) => g.secteurId === secteur.id);
                const sGrpIds = sGroupements.map((g) => g.id);
                const sClds = clds.filter((c) => sGrpIds.includes(c.groupementId));
                const sCldIds = sClds.map((c) => c.id);
                const sVillages = villages.filter((v) => sCldIds.includes(v.cldId));

                return (
                  <div
                    key={secteur.id}
                    id={`secteur-card-${secteur.id}`}
                    onClick={() => handleOpenSecteur(secteur)}
                    className="bg-white rounded-xl p-4 border border-slate-200 hover:border-emerald-300 hover:shadow-xs transition-all cursor-pointer space-y-2.5"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold">
                          <Building2 className="w-5 h-5" />
                        </div>
                        <div>
                          <h3 className="font-bold text-slate-900 text-base">{secteur.nom}</h3>
                          <p className="text-xs text-slate-500 font-mono">Code: {secteur.code}</p>
                        </div>
                      </div>
                      <ChevronRight className="w-5 h-5 text-slate-400" />
                    </div>

                    <div className="grid grid-cols-3 gap-2 bg-slate-50 p-2 rounded-lg border border-slate-100 text-center text-xs">
                      <div>
                        <div className="text-[10px] text-slate-400 font-bold uppercase">Groupements</div>
                        <div className="font-bold text-slate-800">{sGroupements.length}</div>
                      </div>
                      <div>
                        <div className="text-[10px] text-slate-400 font-bold uppercase">CLD</div>
                        <div className="font-bold text-emerald-700">{sClds.length}</div>
                      </div>
                      <div>
                        <div className="text-[10px] text-slate-400 font-bold uppercase">Villages</div>
                        <div className="font-bold text-slate-800">{sVillages.length}</div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Level 2: Groupements of selected secteur */}
          {selectedSecteur && !selectedGroupement && (
            <div className="space-y-3">
              <div className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Groupements dans {selectedSecteur.nom} ({currentGroupements.length})
              </div>

              {currentGroupements.map((grp) => {
                const gClds = clds.filter((c) => c.groupementId === grp.id);
                return (
                  <div
                    key={grp.id}
                    onClick={() => handleOpenGroupement(grp)}
                    className="bg-white rounded-xl p-4 border border-slate-200 hover:border-emerald-300 hover:shadow-xs transition-all cursor-pointer flex items-center justify-between"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-teal-100 text-teal-700 flex items-center justify-center font-bold">
                        <Layers className="w-5 h-5" />
                      </div>
                      <div>
                        <h3 className="font-bold text-slate-900 text-sm">{grp.nom}</h3>
                        <p className="text-xs text-slate-500">{gClds.length} CLD rattaché(s)</p>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-slate-400" />
                  </div>
                );
              })}
            </div>
          )}

          {/* Level 3: CLDs in selected Groupement */}
          {selectedGroupement && !selectedCld && (
            <div className="space-y-3">
              <div className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Comités Locaux de Développement (CLD) dans {selectedGroupement.nom} ({currentClds.length})
              </div>

              {currentClds.map((cld) => {
                const cVillages = villages.filter((v) => v.cldId === cld.id);
                return (
                  <div
                    key={cld.id}
                    onClick={() => handleOpenCld(cld)}
                    className="bg-white rounded-xl p-4 border border-slate-200 hover:border-emerald-300 hover:shadow-xs transition-all cursor-pointer flex items-center justify-between"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold">
                        <Users className="w-5 h-5" />
                      </div>
                      <div>
                        <h3 className="font-bold text-slate-900 text-sm">{cld.nom}</h3>
                        <p className="text-xs text-slate-500">
                          {cVillages.length} village(s) : {cVillages.map((v) => v.nom).join(', ') || 'Aucun'}
                        </p>
                      </div>
                    </div>
                    <ChevronRight className="w-5 h-5 text-slate-400" />
                  </div>
                );
              })}
            </div>
          )}

          {/* Level 4: Villages in selected CLD */}
          {selectedCld && (
            <div className="space-y-3">
              <div className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                Villages rattachés à {selectedCld.nom} ({currentVillages.length})
              </div>

              {currentVillages.map((village) => (
                <div
                  key={village.id}
                  className="bg-white rounded-xl p-3.5 border border-slate-200 flex items-center justify-between"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-amber-100 text-amber-700 flex items-center justify-center">
                      <VillageIcon className="w-4 h-4" />
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-900 text-xs">{village.nom}</h4>
                      {village.latitude && village.longitude && (
                        <p className="text-[10px] text-slate-400 font-mono">
                          GPS: {village.latitude.toFixed(4)}, {village.longitude.toFixed(4)}
                        </p>
                      )}
                    </div>
                  </div>
                  <span className="text-[11px] text-emerald-700 font-semibold bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                    Actif
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
