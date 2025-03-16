import 'package:booksea_app/ui/auth/google_login_screen.dart';
import 'package:booksea_app/ui/calendar/search_and_filter.dart';
import 'package:booksea_app/ui/home/home.dart';
import 'package:booksea_app/ui/qr/qr_scanner_screen.dart';
import 'package:booksea_app/ui/settings/settings_screen.dart';
import 'package:booksea_app/ui/splash/splash_screen.dart';
import 'package:flutter/material.dart';

class Routes {
  Routes._();

  static const String login = '/login';
  static const String splash = '/splash';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String calendar = '/calendar';
  static const String qrScanner = '/qrScanner';

  static final routes = <String, WidgetBuilder>{
    splash: (context) => const SplashScreen(),
    login: (context) => const GoogleLoginScreen(),
    home: (context) => const HomeScreen(),
    settings: (context) => const SettingsScreen(),
    calendar: (context) => const SearchAndFilterScreen(),
    qrScanner: (context) => const QRScannerScreen(),
  };
}
