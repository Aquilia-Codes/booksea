import 'package:flutter/material.dart';
import 'package:booksea_app/caches/sharedpref/shared_prefrence_helper.dart';

class ThemeProvider extends ChangeNotifier {
  // shared pref object
  late SharedPreferenceHelper _sharedPrefsHelper;

  bool _isDarkModeOn = false;

  ThemeProvider() {
    _sharedPrefsHelper = SharedPreferenceHelper();
    _initializeTheme();
  }

  Future<void> _initializeTheme() async {
    _isDarkModeOn = await _sharedPrefsHelper.isDarkMode;
    notifyListeners();
    print('Initial theme: $_isDarkModeOn');
  }

  bool get isDarkModeOn => _isDarkModeOn;

  void updateTheme(bool isDarkModeOn) {
    _sharedPrefsHelper.changeTheme(isDarkModeOn);
    _sharedPrefsHelper.isDarkMode.then((darkModeStatus) {
      if (_isDarkModeOn != darkModeStatus) {
        _isDarkModeOn = darkModeStatus;
        notifyListeners();
        print('Theme changed to: $_isDarkModeOn');
      }
    });
  }
}