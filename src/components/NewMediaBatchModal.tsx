import React, { useState, useRef } from 'react';
import { 
  X, 
  Camera, 
  Upload, 
  Trash2, 
  MapPin, 
  CheckCircle2, 
  AlertCircle,
  Sparkles,
  FileImage,
  Navigation
} from 'lucide-react';
import { Mission, Cld, Village } from '../types';

interface NewMediaBatchModalProps {
  missions: Mission[];
  clds: Cld[];
  villages: Village[];
  initialMissionId?: number;
  initialCldId?: number;
  onClose: () => void;
  onCreate: (batchData: {
    missionId?: number;
    cldId?: number;
    villageId?: number;
    activity: string;
    description?: string;
    latitude?: number;
    longitude?: number;
    items: {
      fileName: string;
      fileSize: number;
      mimeType: string;
      dataUrl: string;
      takenAt: string;
    }[];
  }) => void;
}

const SAMPLE_PHOTO_PRESETS = [
  {
    name: 'Assemblee_Kimpemba.jpg',
    url: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&auto=format&fit=crop&q=80',
    size: 1420000,
  },
  {
    name: 'Pepiniere_Acacias_01.jpg',
    url: 'https://images.unsplash.com/photo-1588880331179-bc9b93a8cb5e?w=800&auto=format&fit=crop&q=80',
    size: 1650000,
  },
  {
    name: 'Bornage_Parcelle_Nord.jpg',
    url: 'https://images.unsplash.com/photo-1500651230702-0e2d8a49d4ad?w=800&auto=format&fit=crop&q=80',
    size: 1890000,
  },
  {
    name: 'Reunion_Notable_Village.jpg',
    url: 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=800&auto=format&fit=crop&q=80',
    size: 1220000,
  }
];

export const NewMediaBatchModal: React.FC<NewMediaBatchModalProps> = ({
  missions,
  clds,
  villages,
  initialMissionId,
  initialCldId,
  onClose,
  onCreate,
}) => {
  const [missionId, setMissionId] = useState<number | undefined>(initialMissionId);
  const [cldId, setCldId] = useState<number | undefined>(initialCldId);
  const [villageId, setVillageId] = useState<number | undefined>(undefined);
  const [activity, setActivity] = useState('');
  const [description, setDescription] = useState('');
  const [latitude, setLatitude] = useState<number>(-4.7812);
  const [longitude, setLongitude] = useState<number>(14.8934);
  const [photos, setPhotos] = useState<{
    fileName: string;
    fileSize: number;
    mimeType: string;
    dataUrl: string;
    takenAt: string;
  }[]>([]);
  const [isLocating, setIsLocating] = useState(false);

  const fileInputRef = useRef<HTMLInputElement>(null);

  const availableVillages = cldId ? villages.filter((v) => v.cldId === cldId) : villages;

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    Array.from(files).forEach((file) => {
      if (!file.type.startsWith('image/')) return;
      const reader = new FileReader();
      reader.onload = (loadEvt) => {
        const result = loadEvt.target?.result as string;
        if (result) {
          setPhotos((prev) => [
            ...prev,
            {
              fileName: file.name,
              fileSize: file.size,
              mimeType: file.type,
              dataUrl: result,
              takenAt: new Date().toISOString(),
            },
          ]);
        }
      };
      reader.readAsDataURL(file);
    });

    // Reset input
    e.target.value = '';
  };

  const handleAddSamplePreset = (preset: typeof SAMPLE_PHOTO_PRESETS[0]) => {
    setPhotos((prev) => [
      ...prev,
      {
        fileName: preset.name,
        fileSize: preset.size,
        mimeType: 'image/jpeg',
        dataUrl: preset.url,
        takenAt: new Date().toISOString(),
      },
    ]);
  };

  const handleRemovePhoto = (idx: number) => {
    setPhotos((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleGetLiveLocation = () => {
    if (!navigator.geolocation) {
      alert('Géolocalisation non supportée par ce navigateur.');
      return;
    }
    setIsLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLatitude(pos.coords.latitude);
        setLongitude(pos.coords.longitude);
        setIsLocating(false);
      },
      () => {
        // Fallback simulated offset
        setLatitude((lat) => lat + (Math.random() - 0.5) * 0.001);
        setLongitude((lng) => lng + (Math.random() - 0.5) * 0.001);
        setIsLocating(false);
      },
      { timeout: 5000 }
    );
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!activity.trim()) {
      alert('Veuillez renseigner l\'intitulé de l\'activité.');
      return;
    }
    if (photos.length === 0) {
      alert('Veuillez ajouter au moins une photo pour ce lot.');
      return;
    }

    onCreate({
      missionId,
      cldId,
      villageId,
      activity: activity.trim(),
      description: description.trim(),
      latitude,
      longitude,
      items: photos,
    });
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto">
      <div className="bg-white w-full max-w-lg rounded-t-2xl sm:rounded-2xl max-h-[90vh] flex flex-col shadow-2xl animate-in fade-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="p-4 border-b border-slate-200 flex items-center justify-between bg-slate-50 rounded-t-2xl">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-teal-600 text-white flex items-center justify-center">
              <Camera className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">
                Nouveau lot de médias
              </h3>
              <p className="text-[11px] text-slate-500">
                Regroupez vos photos d'activité terrain
              </p>
            </div>
          </div>
          <button
            id="close-new-media-modal"
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-4 overflow-y-auto space-y-4 text-xs text-slate-700 flex-1">
          {/* Mission selection */}
          <div className="space-y-1">
            <label className="font-bold text-slate-700">
              Mission associée (optionnel)
            </label>
            <select
              id="media-mission-select"
              value={missionId || ''}
              onChange={(e) => {
                const val = e.target.value ? Number(e.target.value) : undefined;
                setMissionId(val);
                if (val) {
                  const m = missions.find((item) => item.id === val);
                  if (m?.cldId) setCldId(m.cldId);
                }
              }}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-medium focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500"
            >
              <option value="">-- Aucune (Lot indépendant) --</option>
              {missions.map((m) => (
                <option key={m.id} value={m.id}>
                  Mission #{m.id} : {m.titre} ({m.statut})
                </option>
              ))}
            </select>
          </div>

          {/* Activity title */}
          <div className="space-y-1">
            <label className="font-bold text-slate-700">
              Intitulé de l'activité <span className="text-rose-500">*</span>
            </label>
            <input
              id="media-activity-title"
              type="text"
              required
              value={activity}
              onChange={(e) => setActivity(e.target.value)}
              placeholder="Ex: Réunion de sensibilisation, Bornage de parcelle..."
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-medium focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500"
            />
            {/* Quick chips */}
            <div className="flex flex-wrap gap-1 pt-1">
              {[
                'Sensibilisation villageoise',
                'Contrôle pépinière',
                'Bornage parcelle',
                'Cartographie SIG',
              ].map((chip) => (
                <button
                  key={chip}
                  type="button"
                  onClick={() => setActivity(chip)}
                  className="px-2 py-0.5 bg-slate-100 hover:bg-slate-200 text-slate-600 rounded text-[10px] transition-colors"
                >
                  + {chip}
                </button>
              ))}
            </div>
          </div>

          {/* CLD & Village */}
          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <label className="font-bold text-slate-700">CLD concerné</label>
              <select
                id="media-cld-select"
                value={cldId || ''}
                onChange={(e) => {
                  const val = e.target.value ? Number(e.target.value) : undefined;
                  setCldId(val);
                  setVillageId(undefined);
                }}
                className="w-full p-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500"
              >
                <option value="">-- Sélectionner --</option>
                {clds.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.nom}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-1">
              <label className="font-bold text-slate-700">Village</label>
              <select
                id="media-village-select"
                value={villageId || ''}
                onChange={(e) => setVillageId(e.target.value ? Number(e.target.value) : undefined)}
                className="w-full p-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500"
              >
                <option value="">-- Sélectionner --</option>
                {availableVillages.map((v) => (
                  <option key={v.id} value={v.id}>
                    {v.nom}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Description */}
          <div className="space-y-1">
            <div className="flex justify-between">
              <label className="font-bold text-slate-700">Description / Remarques</label>
              <span className="text-[10px] text-slate-400">{description.length}/500</span>
            </div>
            <textarea
              id="media-description"
              maxLength={500}
              rows={2}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Détails sur l'activité, nombre de participants, état d'avancement..."
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:bg-white focus:outline-hidden focus:ring-2 focus:ring-emerald-500"
            />
          </div>

          {/* GPS Position Tag */}
          <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl space-y-2">
            <div className="flex items-center justify-between">
              <span className="font-bold text-slate-700 flex items-center gap-1.5">
                <Navigation className="w-3.5 h-3.5 text-emerald-600" />
                Coordonnées GPS du lot
              </span>
              <button
                type="button"
                id="get-live-gps-btn"
                onClick={handleGetLiveLocation}
                disabled={isLocating}
                className="text-[10px] font-bold text-emerald-700 hover:text-emerald-800 bg-white border border-emerald-300 px-2 py-0.5 rounded shadow-xs"
              >
                {isLocating ? 'Acquisition...' : 'Actualiser GPS'}
              </button>
            </div>
            <div className="font-mono text-[11px] text-slate-600 bg-white p-2 rounded border border-slate-200">
              Lat: {latitude.toFixed(5)} · Lon: {longitude.toFixed(5)} (±6m)
            </div>
          </div>

          {/* Photos Upload & Gallery */}
          <div className="space-y-2 pt-1">
            <div className="flex items-center justify-between">
              <label className="font-bold text-slate-800">
                Photos ({photos.length}) <span className="text-rose-500">*</span>
              </label>
              <span className="text-[10px] text-slate-500">Max 30 photos par lot</span>
            </div>

            {/* Hidden file input */}
            <input
              type="file"
              ref={fileInputRef}
              onChange={handleFileUpload}
              accept="image/*"
              multiple
              className="hidden"
            />

            {/* Upload Buttons */}
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                id="btn-upload-photos-file"
                onClick={() => fileInputRef.current?.click()}
                className="py-3 border-2 border-dashed border-teal-300 hover:border-teal-500 bg-teal-50/50 hover:bg-teal-50 rounded-xl flex flex-col items-center justify-center gap-1 text-teal-800 font-bold transition-all"
              >
                <Upload className="w-4 h-4 text-teal-600" />
                <span>Importer / Photos</span>
              </button>

              <button
                type="button"
                id="btn-upload-camera"
                onClick={() => fileInputRef.current?.click()}
                className="py-3 border-2 border-dashed border-emerald-300 hover:border-emerald-500 bg-emerald-50/50 hover:bg-emerald-50 rounded-xl flex flex-col items-center justify-center gap-1 text-emerald-800 font-bold transition-all"
              >
                <Camera className="w-4 h-4 text-emerald-600" />
                <span>Prendre photo</span>
              </button>
            </div>

            {/* Quick Demo Photo Presets */}
            <div className="bg-slate-50 p-2.5 rounded-lg border border-slate-200 space-y-1.5">
              <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1">
                <Sparkles className="w-3 h-3 text-amber-500" />
                Photos d'exemple pour test rapide :
              </span>
              <div className="flex flex-wrap gap-1.5">
                {SAMPLE_PHOTO_PRESETS.map((preset) => (
                  <button
                    key={preset.name}
                    type="button"
                    onClick={() => handleAddSamplePreset(preset)}
                    className="px-2 py-1 bg-white hover:bg-slate-100 border border-slate-200 rounded text-[10px] text-slate-700 font-medium transition-colors shadow-xs"
                  >
                    + {preset.name.split('_')[0]}
                  </button>
                ))}
              </div>
            </div>

            {/* Selected Photos Grid */}
            {photos.length > 0 && (
              <div className="grid grid-cols-3 sm:grid-cols-4 gap-2 pt-2">
                {photos.map((photo, index) => (
                  <div key={index} className="relative group rounded-lg overflow-hidden border border-slate-200 aspect-square bg-slate-100">
                    <img src={photo.dataUrl} alt="" className="w-full h-full object-cover" />
                    <button
                      type="button"
                      onClick={() => handleRemovePhoto(index)}
                      className="absolute top-1 right-1 w-6 h-6 rounded-full bg-rose-600 text-white flex items-center justify-center shadow-md hover:bg-rose-700 transition-colors"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                    <span className="absolute bottom-0 inset-x-0 bg-black/60 text-white text-[9px] px-1 py-0.5 truncate font-mono">
                      {(photo.fileSize / 1024 / 1024).toFixed(1)} MB
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Submit */}
          <div className="pt-3 border-t border-slate-200 flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-3 py-2 text-xs font-semibold text-slate-600 bg-white border border-slate-200 rounded-xl hover:bg-slate-50"
            >
              Annuler
            </button>
            <button
              type="submit"
              id="submit-create-media-batch"
              className="px-5 py-2 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl shadow-xs transition-colors"
            >
              Enregistrer le lot ({photos.length} photos)
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
