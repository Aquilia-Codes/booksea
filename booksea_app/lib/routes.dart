import 'package:booksea_app/ui/auth/google_login_screen.dart';
import 'package:booksea_app/ui/members/members_screen.dart';
import 'package:booksea_app/ui/search/search_and_filter.dart';
import 'package:booksea_app/ui/home/home.dart';
import 'package:booksea_app/ui/settings/settings_screen.dart';
import 'package:booksea_app/ui/splash/splash_screen.dart';
import 'package:flutter/material.dart';

class Routes {
  Routes._();

  static const String login = '/login';
  static const String splash = '/splash';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String search = '/search';
  static const String members = '/members';

  // PerformanceScreen isn't listed here - it takes an isOwner constructor
  // param sourced from the current user, so settings_screen.dart pushes it
  // directly with MaterialPageRoute instead of through this static map.
  static final routes = <String, WidgetBuilder>{
    splash: (context) => const SplashScreen(),
    login: (context) => const GoogleLoginScreen(),
    home: (context) => const HomeScreen(),
    settings: (context) => const SettingsScreen(),
    search: (context) => SearchAndFilterScreen(),
    members: (context) => const MembersScreen(),
  };
}
