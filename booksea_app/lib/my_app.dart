import 'package:booksea_app/auth_widget_builder.dart';
import 'package:booksea_app/constants/app_themes.dart';
import 'package:booksea_app/flavour.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/routes.dart';
import 'package:booksea_app/services/firestore_database.dart';
import 'package:booksea_app/ui/auth/google_login_screen.dart';
import 'package:booksea_app/ui/home/home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';  
import 'package:booksea_app/providers/theme_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({required Key key, required this.databaseBuilder})
      : super(key: key);

  // Expose builders for 3rd party services at the root of the widget tree
  // This is useful when mocking services while testing
  final FirestoreDatabase Function(BuildContext context, String uid)
      databaseBuilder;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (_, themeProviderRef, authProviderRef, __) {
        print('Current theme mode: ${themeProviderRef.isDarkModeOn ? "Dark" : "Light"}'); // Debug print
        return AuthWidgetBuilder(
          databaseBuilder: databaseBuilder,
          builder: (BuildContext context,
              AsyncSnapshot<UserModel> userSnapshot) {
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
                      return const HomeScreen();
                    case Status.Unauthenticated:
                      return const GoogleLoginScreen();
                    case Status.Uninitialized:
                      return const Material(
                        child: Center(child: CircularProgressIndicator()),
                      );
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