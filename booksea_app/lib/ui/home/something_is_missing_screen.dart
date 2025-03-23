import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/auth_provider.dart';

class SomethingIsMissingScreen extends StatelessWidget {
  const SomethingIsMissingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Something is Missing',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You don\'t have permission to access this content. Please contact your administrator for assistance.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).signOut();
                },
                child: Text('Sign Out',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
