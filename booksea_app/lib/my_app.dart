import 'package:booksea_app/auth_widget_builder.dart';
import 'package:booksea_app/constants/app_themes.dart';
import 'package:booksea_app/flavour.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/routes.dart';
import 'package:booksea_app/services/firestore_database.dart';
import 'package:booksea_app/ui/calendar/calendar_screen.dart';
import 'package:booksea_app/ui/home/home.dart';
import 'package:booksea_app/ui/home/no_code_home.dart';
import 'package:booksea_app/ui/qr/qr_scanner_screen.dart';
import 'package:booksea_app/ui/settings/settings_screen.dart';
import 'package:booksea_app/ui/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/theme_provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({required Key key, required this.databaseBuilder})
      : super(key: key);

  // Expose builders for 3rd party services at the root of the widget tree
  // This is useful when mocking services while testing
  final FirestoreDatabase Function(BuildContext context, String uid)
      databaseBuilder;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 1;
  final List<Widget> _screens = [
    CalendarScreen(),
    HomeScreen(),
    QRScannerScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (_, themeProviderRef, authProviderRef, __) {
        print(
            'Current theme mode: ${themeProviderRef.isDarkModeOn ? "Dark" : "Light"}'); // Debug print
        return AuthWidgetBuilder(
          databaseBuilder: widget.databaseBuilder,
          builder:
              (BuildContext context, AsyncSnapshot<UserModel> userSnapshot) {
            return MaterialApp(
              title: Provider.of<Flavor>(context).toString(),
              routes: Routes.routes,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProviderRef.isDarkModeOn
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: Builder(
                builder: (context) {
                  switch (authProviderRef.status) {
                    case Status.Authenticated:
                      return Scaffold(
                        body: IndexedStack(
                          index: _selectedIndex,
                          children: _screens,
                        ),
                        bottomNavigationBar: BottomNavigationBar(
                          items: const <BottomNavigationBarItem>[
                            BottomNavigationBarItem(
                              icon: Icon(Icons.calendar_month),
                              label: 'Calendar',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.home),
                              label: 'Home',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.qr_code),
                              label: 'QR',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.settings),
                              label: 'Settings',
                            ),
                          ],
                          currentIndex: _selectedIndex,
                          onTap: _onItemTapped,
                        ),
                      );
                    case Status.Unauthenticated:
                      return const SplashScreen();
                    case Status.Uninitialized:
                      return const Material(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    case Status.NoCode:
                      return const NoCodeHomeScreen();
                    default:
                      return const Material(
                        child: Center(child: CircularProgressIndicator()),
                      );
                  }
                },
              ),
            );
          },
          key: const Key('AuthWidget'),
        );
      },
    );
  }
}
