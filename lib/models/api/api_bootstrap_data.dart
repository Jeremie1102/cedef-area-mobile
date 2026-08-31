import 'api_cld.dart';
import 'api_mission.dart';
import 'api_user.dart';
import 'api_village.dart';

/// Regroupe la réponse de `GET /api/v1/bootstrap` : tout ce qu'il faut pour
/// amorcer l'application après connexion (profil, CLD affectés, villages de
/// ces CLD, missions affectées).
class ApiBootstrapData {
  final ApiUser user;
  final List<ApiCld> clds;
  final List<ApiVillage> villages;
  final List<ApiMission> missions;

  const ApiBootstrapData({
    required this.user,
    required this.clds,
    required this.villages,
    required this.missions,
  });

  factory ApiBootstrapData.fromJson(Map<String, dynamic> json) {
    final cldsJson = json['clds'] as List<dynamic>? ?? const [];
    final villagesJson = json['villages'] as List<dynamic>? ?? const [];
    final missionsJson = json['missions'] as List<dynamic>? ?? const [];

    return ApiBootstrapData(
      user: ApiUser.fromJson(json['user'] as Map<String, dynamic>),
      clds: cldsJson.map((e) => ApiCld.fromJson(e as Map<String, dynamic>)).toList(),
      villages: villagesJson.map((e) => ApiVillage.fromJson(e as Map<String, dynamic>)).toList(),
      missions: missionsJson.map((e) => ApiMission.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
