// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:booksea_app/models/access_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Status {
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated,
  Registering
} 

class AuthProvider extends ChangeNotifier {
  //Firebase Auth object
  late FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //Default status
  Status _status = Status.Uninitialized;

  Status get status => _status;

  Stream<AccessModel> get user => _auth.authStateChanges().map(_accessFromFirebase);

  AuthProvider() {
    //initialise object
    _auth = FirebaseAuth.instance;

    //listener for authentication changes such as user sign in and sign out
    _auth.authStateChanges().listen(onAuthStateChanged);
  }

  //Create user object based on the given User
  AccessModel _accessFromFirebase(User? user) {
    if (user == null) {
      return AccessModel(userId: '', email: '', nickname: '', provision: 0, hasAccess: false, isAdmin: false, isOwner: false);
    }

    return AccessModel(
        userId: user.uid,
        hasAccess: true,
        isAdmin: false,
        isOwner: false,
        email: user.email ?? '',
        nickname: user.displayName ?? '',
        provision: 0);
  }

  //Method to detect live auth changes such as user sign in and sign out
  Future<void> onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      AccessModel accessModel = _accessFromFirebase(firebaseUser);
      _status = Status.Authenticated;
      await _createAccessDocumentIfNotExists(firebaseUser.uid, accessModel);
    }
    notifyListeners();
  }
  
  Future<dynamic> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      print('Google user: $googleUser');

      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      print('Google auth: $googleAuth');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      print('Credential: $credential');

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print('User credential: $userCredential');

      User? user = userCredential.user;
      if (user != null) {
        // Explicitly call onAuthStateChanged if needed
        await onAuthStateChanged(user);
      }

      return userCredential;
    } on Exception catch (e) {
      print('Exception: $e');
    }
  }

  Future<void> _createAccessDocumentIfNotExists(String userId, AccessModel accessModel) async {
    final docRef = _firestore.collection('access').doc(userId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      await docRef.set(accessModel.toMap());
    }
  }
}
 