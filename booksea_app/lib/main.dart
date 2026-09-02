import 'package:booksea_app/flavour.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:booksea_app/my_app.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/providers/theme_provider.dart';
import 'package:booksea_app/services/api_database.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // TEMP: backend migration in progress, Firebase may be unreachable.
    // Auth is bypassed (see kBypassFirebaseAuth); keep booting regardless.
    print('Firebase.initializeApp failed: $e');
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) async {
    runApp(
      /*
      * MultiProvider for top services that do not depends on any runtime values
      * such as user uid/email.
       */
      MultiProvider(
        providers: [
          Provider<Flavor>.value(value: Flavor.dev),
          ChangeNotifierProvider<ThemeProvider>(
            create: (context) => ThemeProvider(),
          ),
          ChangeNotifierProvider<AuthProvider>(
            create: (context) => AuthProvider(),
          ), 
        ],
        child: MyApp(
          databaseBuilder: (_, uid) => ApiDatabase(uid: uid),
          key: const Key('Booksea'),
        ),
      ),
    );
  });
}