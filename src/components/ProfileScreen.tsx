import React, { useState } from 'react';
import { 
  User as UserIcon, 
  Shield, 
  Phone, 
  Mail, 
  Save, 
  CheckCircle2, 
  Database, 
  Info, 
  RotateCcw,
  Sparkles 
} from 'lucide-react';
import { User, UserFonction } from '../types';

interface ProfileScreenProps {
  user: User;
  onUpdateUser: (updated: Partial<User>) => void;
  onResetDemoData: () => void;
}

export const ProfileScreen: React.FC<ProfileScreenProps> = ({
  user,
  onUpdateUser,
  onResetDemoData,
}) => {
  const [nom, setNom] = useState(user.nom);
  const [prenom, setPrenom] = useState(user.prenom);
  const [telephone, setTelephone] = useState(user.telephone);
  const [email, setEmail] = useState(user.email || '');
  const [fonction, setFonction] = useState<UserFonction>(user.fonction);
  const [matricule, setMatricule] = useState(user.matricule || '');
  const [savedSuccess, setSavedSuccess] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onUpdateUser({
      nom: nom.trim(),
      prenom: prenom.trim(),
      telephone: telephone.trim(),
      email: email.trim(),
      fonction,
      matricule: matricule.trim(),
    });
    setSavedSuccess(true);
    setTimeout(() => setSavedSuccess(false), 3000);
  };

  return (
    <div className="p-4 space-y-4 max-w-4xl mx-auto pb-24">
      {/* Header */}
      <div>
        <h2 className="text-xl font-bold text-slate-900">Profil de l'agent</h2>
        <p className="text-xs text-slate-500">
          Informations d'identification et rôle de l'agent terrain CEDEF
        </p>
      </div>

      {/* Success notification */}
      {savedSuccess && (
        <div className="p-3 bg-emerald-100 text-emerald-900 border border-emerald-300 rounded-xl text-xs font-medium flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-700 shrink-0" />
          <span>Profil mis à jour avec succès.</span>
        </div>
      )}

      {/* Profile Form Card */}
      <form onSubmit={handleSubmit} className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
        <div className="flex items-center gap-4 pb-3 border-b border-slate-100">
          <div className="w-16 h-16 rounded-2xl bg-emerald-100 border border-emerald-200 overflow-hidden flex items-center justify-center shrink-0">
            {user.photoUrl ? (
              <img src={user.photoUrl} alt="" className="w-full h-full object-cover" />
            ) : (
              <UserIcon className="w-8 h-8 text-emerald-700" />
            )}
          </div>
          <div>
            <h3 className="font-extrabold text-slate-900 text-base">
              {prenom} {nom}
            </h3>
            <p className="text-xs text-slate-500 font-mono">
              Matricule : {matricule || 'Non renseigné'}
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
          <div className="space-y-1">
            <label className="font-bold text-slate-700">Prénom</label>
            <input
              id="profile-prenom-input"
              type="text"
              required
              value={prenom}
              onChange={(e) => setPrenom(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500 font-medium"
            />
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Nom de famille</label>
            <input
              id="profile-nom-input"
              type="text"
              required
              value={nom}
              onChange={(e) => setNom(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500 font-medium"
            />
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Fonction / Rôle</label>
            <select
              id="profile-fonction-select"
              value={fonction}
              onChange={(e) => setFonction(e.target.value as UserFonction)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500 font-medium"
            >
              <option value="animateur">Animateur de terrain</option>
              <option value="mrv">Agent MRV (Mesure, Notification, Vérification)</option>
              <option value="sauvegarde">Agent Sauvegarde Environnementale</option>
              <option value="sig">Agent SIG / Cartographie</option>
            </select>
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Matricule</label>
            <input
              id="profile-matricule-input"
              type="text"
              value={matricule}
              onChange={(e) => setMatricule(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500 font-mono font-medium"
            />
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Téléphone de contact</label>
            <input
              id="profile-telephone-input"
              type="tel"
              value={telephone}
              onChange={(e) => setTelephone(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500 font-medium"
            />
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Email professionnel</label>
            <input
              id="profile-email-input"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500 font-medium"
            />
          </div>
        </div>

        <div className="pt-2 flex justify-end">
          <button
            type="submit"
            id="profile-save-button"
            className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-xs transition-colors"
          >
            <Save className="w-4 h-4" />
            <span>Enregistrer les modifications</span>
          </button>
        </div>
      </form>

      {/* Application & System Info */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 space-y-3 text-xs">
        <div className="flex items-center gap-2 font-bold text-slate-900 text-sm">
          <Info className="w-4 h-4 text-emerald-600" />
          <span>Informations système & CEDEF</span>
        </div>

        <div className="space-y-1 text-slate-600">
          <div className="flex justify-between py-1 border-b border-slate-100">
            <span>Application</span>
            <span className="font-bold text-slate-900">CEDEF AREA (Web / PWA)</span>
          </div>
          <div className="flex justify-between py-1 border-b border-slate-100">
            <span>Version</span>
            <span className="font-mono text-slate-900">1.0.0-web</span>
          </div>
          <div className="flex justify-between py-1 border-b border-slate-100">
            <span>Stockage local</span>
            <span className="font-mono text-slate-900">SQLite Web / Offline Cache</span>
          </div>
          <div className="flex justify-between py-1">
            <span>Organisme</span>
            <span className="font-semibold text-emerald-800">CEDEF RDC / Projet Agroforestier</span>
          </div>
        </div>

        <div className="pt-2 border-t border-slate-100">
          <button
            type="button"
            onClick={onResetDemoData}
            className="w-full py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Réinitialiser toutes les données de démo</span>
          </button>
        </div>
      </div>
    </div>
  );
};
