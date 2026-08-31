import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/gps/my_tracks_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/media/media_screen.dart';
import '../screens/missions/missions_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/sync/sync_status_screen.dart';
import '../screens/territory/territory_screen.dart';

/// Centralise les routes nommées de l'application.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String missions = '/missions';
  static const String media = '/media';
  static const String activity = '/activity';
  static const String territory = '/territory';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String syncStatus = '/sync';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    home: (_) => const HomeScreen(),
    missions: (_) => const MissionsScreen(),
    media: (_) => const MediaScreen(),
    activity: (_) => const MyTracksScreen(),
    territory: (_) => const TerritoryScreen(),
    profile: (_) => const ProfileScreen(),
    editProfile: (_) => const EditProfileScreen(),
    syncStatus: (_) => const SyncStatusScreen(),
  };
}
