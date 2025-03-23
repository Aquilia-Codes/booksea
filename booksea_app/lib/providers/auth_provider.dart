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
  NoCode,
  NoAccess
}

class AuthProvider extends ChangeNotifier {
  //Firebase Auth object
  late FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //Default status
  Status _status = Status.Uninitialized;

  String? _companyId; // Add a private variable to store the company ID

  List<String> _boatIds =
      []; // Declare and initialize _boatIds as a List<String>

  String? get userId => _auth.currentUser?.uid;

  Status get status => _status;

  List<String> get boatIds =>
      _boatIds; // Ensure the getter returns List<String>

  Stream<UserModel> get user =>
      _auth.authStateChanges().asyncMap((user) => _userFromFirebase(user));

  User? get authUser => _auth.currentUser;

  AuthProvider() {
    //initialise object
    _auth = FirebaseAuth.instance;

    //listener for authentication changes such as user sign in and sign out
    _auth.authStateChanges().listen(onAuthStateChanged);
  }

  //Create user object based on the given User
  Future<UserModel> _userFromFirebase(User? user) async {
    if (user == null) {
      return UserModel(
          uid: '',
          email: '',
          nickname: '',
          provision: 0,
          hasAccess: false,
          isAdmin: false,
          isOwner: false,
          companyId: '',
          boatIds: []);
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final userData = docSnapshot.data()!;
      return UserModel(
        uid: user.uid,
        hasAccess: userData['hasAccess'] ?? false,
        isAdmin: userData['isAdmin'] ?? false,
        isOwner: userData['isOwner'] ?? false,
        email: user.email ?? '',
        nickname: userData['nickname'] ?? user.displayName ?? '',
        provision: userData['provision'] ?? 0,
        companyId: userData['companyId'] ?? '',
        boatIds: List<String>.from(userData['boatIds'] ?? []),
      );
    } else {
      return UserModel(
        uid: user.uid,
        hasAccess: false,
        isAdmin: false,
        isOwner: false,
        email: user.email ?? '',
        nickname: user.displayName ?? '',
        provision: 0,
        companyId: '',
        boatIds: [],
      );
    }
  }

  //Method to detect live auth changes such as user sign in and sign out
  Future<void> onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      UserModel userModel = await _userFromFirebase(firebaseUser);
      await _createUserDocumentIfNotExists(firebaseUser.uid, userModel);

      // Check the company code
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        _companyId = userData?['companyId'] ?? ''; // Set the company ID
        _boatIds = List<String>.from(
            userData?['boatIds'] ?? []); // Set the boat IDs as List<String>

        // Add logging to check the fetched data
        print('Fetched companyId: $_companyId');
        print('Fetched boatIds: $_boatIds');

        final firestoreDatabase = FirestoreDatabase(uid: firebaseUser.uid);

        // First check if company code exists
        if (_companyId!.isEmpty ||
            !await firestoreDatabase.companyExists(_companyId!)) {
          _status = Status.NoCode;
        } else {
          // Only if company code exists, check for access and boat IDs
          bool hasAccess = userData?['hasAccess'] ?? false;

          // Show "something is missing" screen if user has no access OR no boat IDs
          // but only if they already have a valid company code
          if (!hasAccess || _boatIds.isEmpty) {
            _status = Status.NoAccess;
          } else {
            _status = Status.Authenticated;
          }
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

      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

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

  Future<void> _createUserDocumentIfNotExists(
      String userId, UserModel userModel) async {
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
