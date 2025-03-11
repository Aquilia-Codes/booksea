import 'package:booksea_app/services/firestore_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/auth_provider.dart' as custom_auth_provider;
import 'package:firebase_auth/firebase_auth.dart';

class NoCodeHomeScreen extends StatelessWidget {
  const NoCodeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<custom_auth_provider.AuthProvider>(context, listen: false);
    String companyCode = ''; // Variable to store the input value

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home'),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter Company Code',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 8, // Limit the input to 8 characters
                    onChanged: (value) {
                      companyCode = value; // Update the variable with the input value
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final firestoreDatabase = Provider.of<FirestoreDatabase>(context, listen: false);
                      // Use the stored companyCode variable here
                      await firestoreDatabase.writeCompanyIdToUserDocument(companyCode);
                      // Trigger the authentication status check
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        await authProvider.onAuthStateChanged(currentUser);
                      }
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
