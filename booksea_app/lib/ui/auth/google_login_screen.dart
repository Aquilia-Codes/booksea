import 'package:flutter/material.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  _GoogleLoginScreenState createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  // Commented out Apple login toggle
  // bool isGoogleLogin = true;
  late Future<void> _precacheImagesFuture;

  @override
  void initState() {
    super.initState();
    _precacheImagesFuture = _precacheImages();
  }

  Future<void> _precacheImages() async {
    // Precache the background and logo images
    await Future.wait([
      precacheImage(AssetImage('assets/google_splash.png'), context),
      precacheImage(AssetImage('assets/google.png'), context),
      // Commented out Apple image preloading
      // precacheImage(AssetImage('assets/apple.png'), context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    print('AGAIN LOGIN');
    return Scaffold(
      body: FutureBuilder(
          future: _precacheImagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: Text(''));
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/google_splash.png',
                  fit: BoxFit.cover,
                ),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(15),
                    ),
                    onPressed: () async {
                      try {
                        final authProvider =
                            Provider.of<AuthProvider>(context, listen: false);
                        final userCredential =
                            await authProvider.signInWithGoogle();
                        if (userCredential != null) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        // Handle any errors that occur during sign in
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to sign in with Google: ${e.toString()}')),
                        );
                      }
                    },
                    child: Image.asset(
                      'assets/google.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                ),
                // Commented out Apple login toggle button
                /*
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isGoogleLogin = !isGoogleLogin;
                        });
                      },
                      child: Text(
                        isGoogleLogin ? 'Apple login' : 'Google login',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                */
              ],
            );
          }),
    );
  }
}
