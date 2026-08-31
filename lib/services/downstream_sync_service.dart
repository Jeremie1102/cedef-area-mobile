import '../core/constants/app_constants.dart';
import '../core/utils/id_generator.dart';
import '../models/api/api_bootstrap_data.dart';
import '../models/api/api_cld.dart';
import '../models/api/api_groupement.dart';
import '../models/api/api_mission.dart';
import '../models/api/api_sector.dart';
import '../models/api/api_user.dart';
import '../models/api/api_village.dart';
import '../models/cld.dart';
import '../models/groupement.dart';
import '../models/mission.dart';
import '../models/mission_cld.dart';
import '../models/mission_user.dart';
import '../models/secteur.dart';
import '../models/user.dart';
import '../models/village.dart';
import '../repositories/cld_repository.dart';
import '../repositories/groupement_repository.dart';
import '../repositories/mission_repository.dart';
import '../repositories/secteur_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/village_repository.dart';

/// Synchronisation descendante (Laravel -> SQLite) : persiste la réponse de
/// `GET /api/v1/bootstrap` (voir `BootstrapApiService`) dans les tables
/// locales déjà utilisées par les écrans existants (`MissionRepository`,
/// `CldRepository`, ...), afin que l'application fonctionne hors ligne après
/// une première connexion.
///
/// Service pur : aucun appel réseau ici, uniquement de la persistance. Les
/// entités sont retrouvées par `server_id` puis mises à jour, ou créées si
/// absentes — jamais de doublon, jamais de suppression (voir la règle de
/// non-écrasement ci-dessous).
///
/// Ordre de traitement imposé par les clés étrangères locales : Secteur ->
/// Groupement -> CLD -> Village, avant les missions qui en dépendent.
class DownstreamSyncService {
  final UserRepository _userRepository;
  final SecteurRepository _secteurRepository;
  final GroupementRepository _groupementRepository;
  final CldRepository _cldRepository;
  final VillageRepository _villageRepository;
  final MissionRepository _missionRepository;

  DownstreamSyncService({
    UserRepository? userRepository,
    SecteurRepository? secteurRepository,
    GroupementRepository? groupementRepository,
    CldRepository? cldRepository,
    VillageRepository? villageRepository,
    MissionRepository? missionRepository,
  }) : _userRepository = userRepository ?? UserRepository(),
       _secteurRepository = secteurRepository ?? SecteurRepository(),
       _groupementRepository = groupementRepository ?? GroupementRepository(),
       _cldRepository = cldRepository ?? CldRepository(),
       _villageRepository = villageRepository ?? VillageRepository(),
       _missionRepository = missionRepository ?? MissionRepository();

  /// Persiste l'intégralité d'une réponse `/bootstrap` et retourne la ligne
  /// locale `users` réconciliée pour l'agent connecté (utilisée par
  /// `ApiAuthProvider` pour pontuer vers `AuthProvider`).
  Future<User> applyBootstrap(ApiBootstrapData data) async {
    final localUser = await _upsertUser(data.user);

    for (final cld in data.clds) {
      final cldId = await _upsertCld(cld);
      if (cldId != null && localUser.id != null) {
        await _cldRepository.assignToUser(userId: localUser.id!, cldId: cldId);
      }
    }

    for (final village in data.villages) {
      await _upsertVillage(village);
    }

    for (final mission in data.missions) {
      await _upsertMission(mission, currentLocalUserId: localUser.id);
    }

    return localUser;
  }

  // --- Utilisateur ---------------------------------------------------------

  Future<User> _upsertUser(ApiUser api) async {
    final existing = await _userRepository.getByServerId(api.id);
    final now = DateTime.now();

    if (existing != null) {
      // Une modification locale du profil pas encore envoyée au serveur ne
      // doit jamais être écrasée par une version serveur périmée (voir la
      // règle de non-écrasement dans le rapport de cette étape).
      if (existing.syncStatus != SyncStatus.synced) return existing;

      final updated = existing.copyWith(
        nom: api.nom,
        postNom: api.postnom ?? existing.postNom,
        prenom: api.prenom ?? existing.prenom,
        photoProfil: api.photoProfil,
        isActive: api.actif,
        syncStatus: SyncStatus.synced,
        updatedAt: now,
      );
      await _userRepository.update(updated);
      return updated;
    }

    final created = User(
      localId: IdGenerator.generate(),
      serverId: api.id,
      nom: api.nom,
      postNom: api.postnom ?? '',
      prenom: api.prenom ?? '',
      fonction: UserFonctionX.fromValue(api.fonction),
      // Ce compte local n'est qu'un reflet de l'identité Laravel : aucune
      // connexion locale par mot de passe ne doit jamais l'utiliser (voir
      // `AuthApiService`/`AuthService`, deux flux distincts).
      passwordHash: '',
      photoProfil: api.photoProfil,
      isActive: api.actif,
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _userRepository.insert(created);
    return created.copyWith(id: id);
  }

  // --- Hiérarchie territoriale ----------------------------------------------

  Future<int> _upsertSecteur(ApiSector api) async {
    final existing = await _secteurRepository.getByServerId(api.id);
    final now = DateTime.now();

    if (existing != null) {
      await _secteurRepository.update(
        existing.copyWith(nom: api.nom, syncStatus: SyncStatus.synced, updatedAt: now),
      );
      return existing.id!;
    }

    final created = Secteur(
      localId: IdGenerator.generate(),
      serverId: api.id,
      nom: api.nom,
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
    return _secteurRepository.insert(created);
  }

  /// Retourne `null` si aucun secteur n'est fourni par l'API et qu'aucun
  /// groupement local n'existe déjà (impossible de satisfaire la contrainte
  /// `NOT NULL secteur_id` dans ce cas : le groupement est alors ignoré).
  Future<int?> _upsertGroupement(ApiGroupement api) async {
    final existing = await _groupementRepository.getByServerId(api.id);
    final now = DateTime.now();

    int? secteurId = api.sector != null ? await _upsertSecteur(api.sector!) : null;
    secteurId ??= existing?.secteurId;
    if (secteurId == null) return null;

    if (existing != null) {
      await _groupementRepository.update(
        existing.copyWith(
          nom: api.nom,
          secteurId: secteurId,
          syncStatus: SyncStatus.synced,
          updatedAt: now,
        ),
      );
      return existing.id!;
    }

    final created = Groupement(
      localId: IdGenerator.generate(),
      serverId: api.id,
      secteurId: secteurId,
      nom: api.nom,
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
    return _groupementRepository.insert(created);
  }

  /// Retourne `null` si le groupement parent n'a pas pu être résolu (voir
  /// [_upsertGroupement]) : le CLD est alors ignoré plutôt que d'insérer une
  /// ligne avec un `groupement_id` invalide.
  Future<int?> _upsertCld(ApiCld api) async {
    final existing = await _cldRepository.getByServerId(api.id);
    final now = DateTime.now();

    int? groupementId = api.groupement != null ? await _upsertGroupement(api.groupement!) : null;
    groupementId ??= existing?.groupementId;
    if (groupementId == null) return null;

    if (existing != null) {
      await _cldRepository.update(
        existing.copyWith(
          nom: api.nom,
          groupementId: groupementId,
          syncStatus: SyncStatus.synced,
          updatedAt: now,
        ),
      );
      return existing.id!;
    }

    final created = Cld(
      localId: IdGenerator.generate(),
      serverId: api.id,
      groupementId: groupementId,
      nom: api.nom,
      syncStatus: SyncStatus.synced,
      createdAt: now,
      updatedAt: now,
    );
    return _cldRepository.insert(created);
  }

  /// Ignore silencieusement si le CLD parent n'est pas (encore) synchronisé
  /// localement : ne devrait pas arriver en pratique, l'API renvoyant
  /// toujours les CLD concernés avant/avec leurs villages.
  Future<void> _upsertVillage(ApiVillage api) async {
    final parentCld = await _cldRepository.getByServerId(api.cldId);
    if (parentCld == null) return;

    final existing = await _villageRepository.getByServerId(api.id);
    final now = DateTime.now();

    if (existing != null) {
      await _villageRepository.update(
        existing.copyWith(
          nom: api.nom,
          cldId: parentCld.id,
          syncStatus: SyncStatus.synced,
          updatedAt: now,
        ),
      );
      return;
    }

    await _villageRepository.insert(
      Village(
        localId: IdGenerator.generate(),
        serverId: api.id,
        cldId: parentCld.id!,
        nom: api.nom,
        syncStatus: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // --- Missions --------------------------------------------------------------

  Future<void> _upsertMission(ApiMission api, {required int? currentLocalUserId}) async {
    final existing = await _missionRepository.getByServerId(api.id);
    final now = DateTime.now();

    int? secteurId = api.sector != null ? await _upsertSecteur(api.sector!) : null;
    secteurId ??= existing?.secteurId;

    int? missionLocalId;
    if (existing != null) {
      missionLocalId = existing.id;
      // Une mission en cours de traitement hors ligne (démarrée, mise en
      // pause, ...) ne doit jamais être écrasée par une version serveur
      // périmée tant qu'elle n'a pas fini de remonter (voir le rapport de
      // cette étape) : seules ses tables pivot sont rafraîchies ci-dessous.
      if (existing.syncStatus == SyncStatus.synced) {
        await _missionRepository.update(
          existing.copyWith(
            titre: api.titre,
            description: api.description,
            dateDebut: _tryParseDate(api.dateDebutPrevue),
            dateFin: _tryParseDate(api.dateFinPrevue),
            secteurId: secteurId,
            statut: MissionStatusX.fromValue(api.statut),
            syncStatus: SyncStatus.synced,
            updatedAt: now,
          ),
        );
      }
    } else {
      final created = Mission(
        localId: IdGenerator.generate(),
        serverId: api.id,
        titre: api.titre,
        description: api.description,
        dateDebut: _tryParseDate(api.dateDebutPrevue),
        dateFin: _tryParseDate(api.dateFinPrevue),
        secteurId: secteurId,
        statut: MissionStatusX.fromValue(api.statut),
        syncStatus: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
      );
      missionLocalId = await _missionRepository.insert(created);
    }

    if (missionLocalId == null) return;

    for (final cld in api.clds) {
      final cldId = await _upsertCld(cld);
      if (cldId != null) {
        await _missionRepository.assignCld(
          MissionCld(
            localId: IdGenerator.generate(),
            missionId: missionLocalId,
            cldId: cldId,
            syncStatus: SyncStatus.synced,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    for (final village in api.villages) {
      await _upsertVillage(village);
    }

    if (currentLocalUserId != null) {
      await _missionRepository.assignUser(
        MissionUser(
          localId: IdGenerator.generate(),
          missionId: missionLocalId,
          userId: currentLocalUserId,
          syncStatus: SyncStatus.synced,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  DateTime? _tryParseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
