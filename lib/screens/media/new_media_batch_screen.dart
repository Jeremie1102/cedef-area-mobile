import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_utils.dart';
import '../../models/mission.dart';
import '../../models/village.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/cld_repository.dart';
import '../../repositories/mission_repository.dart';
import '../../repositories/village_repository.dart';
import '../../services/media_service.dart';
import '../../services/mission_service.dart';
import '../../widgets/cld_selector.dart';
import 'photo_viewer_screen.dart';

/// Création d'un lot de médias : sélection multiple de photos déjà présentes
/// dans la galerie, puis description unique du lot (mission, activité, CLD,
/// village, description) — jamais de prise de photo à la caméra.
///
/// Un lot est toujours rattaché à une mission (voir section 12 du cahier des
/// charges). Deux façons d'y arriver :
/// * ouvert depuis le détail d'une mission ([missionId] fourni) : la mission
///   reste préaffichée et verrouillée, et le choix du CLD est restreint aux
///   CLD de cette mission ([allowedClds]) ;
/// * ouvert depuis « Mes lots de médias » (aucun argument) : l'agent doit
///   choisir explicitement une mission parmi les siennes (jamais toutes les
///   missions du serveur), et le territoire de la mission choisie restreint
///   alors le CLD de la même façon.
class NewMediaBatchScreen extends StatefulWidget {
  final int? missionId;
  final List<CldWithLocation>? allowedClds;

  const NewMediaBatchScreen({super.key, this.missionId, this.allowedClds});

  @override
  State<NewMediaBatchScreen> createState() => _NewMediaBatchScreenState();
}

class _NewMediaBatchScreenState extends State<NewMediaBatchScreen> {
  final _mediaService = MediaService();
  final _missionService = MissionService();
  final _missionRepository = MissionRepository();
  final _cldRepository = CldRepository();
  final _villageRepository = VillageRepository();
  final _descriptionController = TextEditingController();
  final _customActivityController = TextEditingController();

  int? _userId;

  List<XFile> _photos = [];
  bool _isPicking = false;
  bool _isSaving = false;

  String? _activity;
  CldWithLocation? _selectedCld;
  List<Village> _villages = [];
  Village? _selectedVillage;
  DateTime _activityDate = DateTime.now();

  /// Mission de la mission d'origine, quand `widget.missionId` est fourni.
  Mission? _presetMission;
  /// Missions locales de l'agent, proposées quand aucune mission n'est
  /// imposée par l'écran appelant.
  List<Mission> _myMissions = [];
  Mission? _selectedMission;
  /// CLD du territoire de [_selectedMission], résolu dynamiquement (même
  /// principe que [widget.allowedClds], mais calculé ici plutôt que reçu).
  List<CldWithLocation>? _dynamicAllowedClds;

  int _totalBytes = 0;

  bool get _hasPresetMission => widget.missionId != null;

  int? get _effectiveMissionId => widget.missionId ?? _selectedMission?.id;

  List<CldWithLocation>? get _effectiveAllowedClds =>
      _hasPresetMission ? widget.allowedClds : _dynamicAllowedClds;

  bool get _isRestrictedCld =>
      _effectiveAllowedClds != null && _effectiveAllowedClds!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthProvider>().currentUser?.id;
    if (_isRestrictedCld && widget.allowedClds!.length == 1) {
      _onCldSelected(widget.allowedClds!.first);
    }
    _loadMissionData();
  }

  Future<void> _loadMissionData() async {
    if (_hasPresetMission) {
      final mission = await _missionRepository.findById(widget.missionId!);
      if (!mounted) return;
      setState(() => _presetMission = mission);
      return;
    }
    final userId = _userId;
    if (userId == null) return;
    final missions = await _missionRepository.findByUser(userId);
    if (!mounted) return;
    setState(() => _myMissions = missions);
  }

  Future<void> _onMissionSelected(Mission? mission) async {
    setState(() {
      _selectedMission = mission;
      _dynamicAllowedClds = null;
      _selectedCld = null;
      _selectedVillage = null;
      _villages = [];
    });
    if (mission == null) return;

    final territory = await _missionService.getMissionTerritory(mission.id!);
    if (!mounted || _selectedMission?.id != mission.id) return;
    if (territory.clds.isEmpty) return;

    final withLocation = await _cldRepository.getByIdsWithLocation(
      territory.clds.map((c) => c.id!).toList(),
    );
    if (!mounted || _selectedMission?.id != mission.id) return;
    setState(() {
      _dynamicAllowedClds = withLocation;
      if (withLocation.length == 1) _onCldSelected(withLocation.first);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _customActivityController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= AppConfig.mediaBatchMaxPhotos) {
      _showMessage('Ce lot contient déjà le maximum de ${AppConfig.mediaBatchMaxPhotos} photos.');
      return;
    }
    setState(() => _isPicking = true);
    try {
      final remaining = AppConfig.mediaBatchMaxPhotos - _photos.length;
      final picked = await _mediaService.pickPhotosFromGallery(limit: remaining);
      if (!mounted) return;
      if (picked.isNotEmpty) {
        final existingPaths = _photos.map((p) => p.path).toSet();
        final newOnes = picked.where((p) => !existingPaths.contains(p.path)).toList();
        setState(() => _photos = [..._photos, ...newOnes]);
        await _refreshTotalSize();
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _refreshTotalSize() async {
    final total = await _mediaService.totalBytes(_photos);
    if (!mounted) return;
    setState(() => _totalBytes = total);
  }

  void _removePhotoAt(int index) {
    setState(() => _photos = List.of(_photos)..removeAt(index));
    _refreshTotalSize();
  }

  void _previewPhotoAt(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          paths: _photos.map((p) => p.path).toList(),
          initialIndex: index,
        ),
      ),
    );
  }

  Future<void> _onCldSelected(CldWithLocation cld) async {
    setState(() {
      _selectedCld = cld;
      _selectedVillage = null;
      _villages = [];
    });
    final villages = await _villageRepository.getByCld(cld.cld.id!);
    if (!mounted) return;
    setState(() => _villages = villages);
  }

  Future<void> _pickActivityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _activityDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _activityDate = picked);
  }

  Future<void> _save() async {
    if (_photos.isEmpty) {
      _showMessage('Sélectionnez au moins une photo.');
      return;
    }
    if (_effectiveMissionId == null) {
      _showMessage('Sélectionnez la mission concernée par ce lot.');
      return;
    }
    if (_activity == null || _selectedCld == null) {
      _showMessage('Renseignez au moins l\'activité et le CLD concerné.');
      return;
    }
    if (_activity == 'Autre' && _customActivityController.text.trim().isEmpty) {
      _showMessage('Précisez l\'activité dans le champ prévu.');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showMessage('La description du lot est obligatoire.');
      return;
    }

    final userId = _userId;
    if (userId == null) return;

    final activityValue = _activity == 'Autre' ? _customActivityController.text.trim() : _activity;

    setState(() => _isSaving = true);
    try {
      await _mediaService.createBatch(
        userId: userId,
        photos: _photos,
        missionId: _effectiveMissionId,
        secteurId: _selectedCld!.secteurId,
        groupementId: _selectedCld!.cld.groupementId,
        cldId: _selectedCld!.cld.id,
        villageId: _selectedVillage?.id,
        activity: activityValue,
        description: _descriptionController.text.trim(),
        capturedAt: _activityDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(e is AppException ? e.message : 'Impossible d\'enregistrer le lot. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau lot')),
      body: SafeArea(
        child: _photos.isEmpty ? _buildPickPrompt() : _buildForm(),
      ),
    );
  }

  Widget _buildPickPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sélectionnez les photos de la galerie qui illustrent cette activité.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isPicking ? null : _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_isPicking ? 'Ouverture…' : 'Sélectionner dans la galerie'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final totalMb = _totalBytes / (1024 * 1024);
    final isLarge = totalMb > AppConfig.mediaBatchWarningSizeMb;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_photos.length} photo${_photos.length > 1 ? 's' : ''} sélectionnée${_photos.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: _isPicking ? null : _pickPhotos,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          if (_totalBytes > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Taille estimée : ${totalMb.toStringAsFixed(1).replaceAll('.', ',')} Mo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ),
          if (isLarge)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ce lot est volumineux. Il pourra tout de même être enregistré, mais la synchronisation sera plus longue.',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) => _PhotoThumbnail(
              photo: _photos[index],
              onRemove: () => _removePhotoAt(index),
              onTap: () => _previewPhotoAt(index),
            ),
          ),
          const SizedBox(height: 24),
          _buildMissionField(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Activité', border: OutlineInputBorder()),
            items: ActivityCategories.all
                .map((activity) => DropdownMenuItem(value: activity, child: Text(activity)))
                .toList(),
            onChanged: (value) => setState(() => _activity = value),
          ),
          if (_activity == 'Autre') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customActivityController,
              decoration: const InputDecoration(
                labelText: 'Précisez l\'activité',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickActivityDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date de l\'activité',
                border: OutlineInputBorder(),
              ),
              child: Text(AppDateUtils.frenchDate(_activityDate)),
            ),
          ),
          const SizedBox(height: 16),
          _buildCldField(),
          const SizedBox(height: 16),
          DropdownButtonFormField<Village>(
            initialValue: _selectedVillage,
            decoration: InputDecoration(
              labelText: 'Village',
              border: const OutlineInputBorder(),
              hintText: _selectedCld == null ? 'Sélectionnez d\'abord un CLD' : null,
            ),
            items: _villages
                .map((village) => DropdownMenuItem(value: village, child: Text(village.nom)))
                .toList(),
            onChanged: _villages.isEmpty
                ? null
                : (value) => setState(() => _selectedVillage = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: AppConfig.mediaBatchDescriptionMaxLength,
            decoration: const InputDecoration(
              labelText: 'Description du lot *',
              hintText: 'Qu\'est-ce que montrent ces photos ? Pourquoi et par qui ont-elles été prises ?',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer le lot'),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionField() {
    if (_hasPresetMission) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Mission', border: OutlineInputBorder()),
        child: Text(_presetMission?.titre ?? '…'),
      );
    }

    return DropdownButtonFormField<Mission>(
      initialValue: _selectedMission,
      decoration: const InputDecoration(labelText: 'Mission *', border: OutlineInputBorder()),
      items: _myMissions
          .map((mission) => DropdownMenuItem(value: mission, child: Text(mission.titre)))
          .toList(),
      onChanged: _myMissions.isEmpty ? null : _onMissionSelected,
      hint: _myMissions.isEmpty ? const Text('Aucune mission disponible') : null,
    );
  }

  Widget _buildCldField() {
    final userId = _userId;
    if (!_isRestrictedCld) {
      return userId == null
          ? const SizedBox.shrink()
          : CldSelector(selected: _selectedCld, onSelected: _onCldSelected, userId: userId);
    }

    final clds = _effectiveAllowedClds!;
    if (clds.length == 1) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'CLD', border: OutlineInputBorder()),
        child: Text('${clds.first.cld.nom} — ${clds.first.groupementName}, ${clds.first.secteurName}'),
      );
    }

    return DropdownButtonFormField<CldWithLocation>(
      initialValue: _selectedCld,
      decoration: const InputDecoration(
        labelText: 'CLD (territoire de la mission)',
        border: OutlineInputBorder(),
      ),
      items: clds
          .map((cld) => DropdownMenuItem(value: cld, child: Text(cld.cld.nom)))
          .toList(),
      onChanged: (value) {
        if (value != null) _onCldSelected(value);
      },
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final XFile photo;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.photo, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Image.file(File(photo.path), fit: BoxFit.cover),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
