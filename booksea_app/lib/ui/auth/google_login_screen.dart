import 'package:flutter/material.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  _GoogleLoginScreenState createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  bool isGoogleLogin = true;

  @override
  Widget build(BuildContext context) {
    print('AGAIN LOGIN');
    return Scaffold(
      body: Stack(
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
                  final userCredential = await authProvider.signInWithGoogle();
                  if (userCredential != null) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  // Handle any errors that occur during sign in
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Failed to sign in with ${isGoogleLogin ? 'Google' : 'Apple'}: ${e.toString()}')),
                  );
                }
              },
              child: Image.asset(
                isGoogleLogin ? 'assets/google.png' : 'assets/apple.png',
                width: 50,
                height: 50,
              ),
            ),
          ),
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
        ],
      ),
    );
  }
}
