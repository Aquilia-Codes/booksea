// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:booksea_app/services/firestore_database.dart';

enum Status {
  Uninitialized,
  Authenticated,
  Authenticating,
  Unauthenticated,
  Registering,
  NoCode
} 

class AuthProvider extends ChangeNotifier {
  //Firebase Auth object
  late FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //Default status
  Status _status = Status.Uninitialized;

  String? _companyId; // Add a private variable to store the company ID

  List<String> _boatIds = []; // Declare and initialize _boatIds as a List<String>

  String? get userId => _auth.currentUser?.uid;

  Status get status => _status;

  List<String> get boatIds => _boatIds; // Ensure the getter returns List<String>

  Stream<UserModel> get user => _auth.authStateChanges().map(_userFromFirebase);

  AuthProvider() {
    //initialise object
    _auth = FirebaseAuth.instance;

    //listener for authentication changes such as user sign in and sign out
    _auth.authStateChanges().listen(onAuthStateChanged);
  }

  //Create user object based on the given User
  UserModel _userFromFirebase(User? user) {
    if (user == null) {
      return UserModel(uid: '', email: '', nickname: '', provision: 0, hasAccess: false, isAdmin: false, isOwner: false);
    }

    return UserModel(
        uid: user.uid,
        hasAccess: false,
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
      UserModel userModel = _userFromFirebase(firebaseUser);
      await _createUserDocumentIfNotExists(firebaseUser.uid, userModel);

      // Check the company code
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        _companyId = userData?['companyId'] ?? ''; // Set the company ID
        _boatIds = List<String>.from(userData?['boatIds'] ?? []); // Set the boat IDs as List<String>

        // Add logging to check the fetched data
        print('Fetched companyId: $_companyId');
        print('Fetched boatIds: $_boatIds');

        final firestoreDatabase = FirestoreDatabase(uid: firebaseUser.uid);

        if (_companyId!.isEmpty || !await firestoreDatabase.companyExists(_companyId!)) {
          _status = Status.NoCode;
        } else {
          _status = Status.Authenticated;
        }
      } else {
        _status = Status.NoCode;
      }
    } 
    notifyListeners();
  } 
  
  Future<dynamic> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
 

      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
 

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      ); 

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential); 

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

  Future<void> _createUserDocumentIfNotExists(String userId, UserModel userModel) async {
    final docRef = _firestore.collection('users').doc(userId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      await docRef.set(userModel.toMap());
    }
  }

  Future signOut() async {
    print('active user: ${_auth.currentUser}');
    _auth.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
    print('active user: ${_auth.currentUser}');
    return Future.delayed(Duration.zero);
  }

  String? get companyId => _companyId; // Getter to access the company ID 
}
 