import 'package:booksea_app/providers/auth_provider.dart' as auth_provider;
import 'package:booksea_app/services/firestore_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NoCodeHomeScreen extends StatelessWidget {
  const NoCodeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String companyCode = ''; // Variable to store the input value

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/company_code.png'),
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 150),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Enter Company Code',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2.0),
                      ),
                      labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    maxLength: 8, // Limit the input to 8 characters
                    onChanged: (value) {
                      companyCode =
                          value; // Update the variable with the input value
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final firestoreDatabase = Provider.of<FirestoreDatabase>(
                          context,
                          listen: false);
                      // Use the stored companyCode variable here
                      await firestoreDatabase
                          .writeCompanyIdToUserDocument(companyCode);
                      // Trigger the authentication status check
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        await Provider.of<auth_provider.AuthProvider>(context,
                                listen: false)
                            .onAuthStateChanged(currentUser);
                      }
                    },
                    child: const Text('Submit'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Provider.of<auth_provider.AuthProvider>(context,
                              listen: false)
                          .signOut();
                    },
                    child: Text('Sign Out',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
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
