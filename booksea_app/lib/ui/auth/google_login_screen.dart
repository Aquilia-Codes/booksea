import 'package:flutter/material.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class GoogleLoginScreen extends StatelessWidget {
  const GoogleLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('AGAIN LOGIN'); // Print statement added
    return Scaffold( // Removed MaterialApp
      appBar: AppBar(
        title: const Text('Booksea App'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Access the AuthProvider and call signInWithGoogle
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.signInWithGoogle();
          },
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
