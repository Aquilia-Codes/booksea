import 'dart:async'; 
import 'package:booksea_app/models/boat_model.dart';
import 'package:booksea_app/models/company_model.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/services/firestore_path.dart';
import 'package:booksea_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  
import 'package:booksea_app/models/tour_model.dart';
import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/models/type_model.dart';
 

String documentIdFromCurrentDate() => DateTime.now().toIso8601String();

/*
This is the main class access/call for any UI widgets that require to perform
any CRUD activities operation in FirebaseFirestore database.
This class work hand-in-hand with FirestoreService and FirestorePath.

Notes:
For cases where you need to have a special method such as bulk update specifically
on a field, then is ok to use custom code and write it here. For example,
setAllTodoComplete is require to change all todos item to have the complete status
changed to true.

 */
class FirestoreDatabase {
  FirestoreDatabase({required this.uid});
  final String uid;

  // ignore: unused_field
  final _firestoreService = FirestoreService.instance;
  
  // Update the user document with the gotten data,
  Future<void> setUser(UserModel user) async => _firestoreService.set(
    path: FirestorePath.user(uid), 
    data: user.toMap()
  );

  // Get the user document
  Future<UserModel> getUser() async => _firestoreService.getDocument<UserModel>(
    path: FirestorePath.user(uid), 
    builder: (data, id) => UserModel.fromMap(data, id)
  );

  // Recieve company code and uid from user and check if the company code is valid, write the company id to the user document
  Future<void> writeCompanyIdToUserDocument(String companyCode) async { 
    print('Company code is $companyCode');
    final user = await _firestoreService.getDocument<UserModel>(
      path: FirestorePath.user(uid), 
      builder: (data, id) => UserModel.fromMap(data, id)
    ); 
    
    // Query the companies collection for a document with the matching companyCode
    final querySnapshot = await FirebaseFirestore.instance
        .collection(FirestorePath.companies())
        .where('companyCode', isEqualTo: companyCode)
        .get();
    
    print('Query snapshot size: ${querySnapshot.size}');
    for (var doc in querySnapshot.docs) {
      print('Found company document: ${doc.data()}');
    }
    
    if (querySnapshot.docs.isNotEmpty) {
      final companyDoc = querySnapshot.docs.first;
      final company = CompanyModel.fromMap(companyDoc.data(), companyDoc.id);
      print('Company is ${company.companyCode}');
      if (company.companyCode == companyCode) {
        print('Company code is valid');
        await setUser(user.copyWith(companyId: companyDoc.id));
      }
    } else {
      print('No company found with the provided company code');
    }
  }
  //checking if a company with the given companyid exists
  Future<bool> companyExists(String companyId) async {
    final docRef = FirebaseFirestore.instance.collection(FirestorePath.companies()).doc(companyId);
    final docSnapshot = await docRef.get();
    return docSnapshot.exists;
  }

  /* Tour section */
  
  //Get all tours by companyId and boatId in a specific date range
  Future<List<TourModel>> getTours(String companyId, String boatId, DateTime startTime, DateTime endTime) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection(FirestorePath.tours(companyId, boatId))
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .where('endTime', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
        .get();
    return querySnapshot.docs.map((doc) => TourModel.fromMap(doc.data(), doc.id)).toList();
  }

  //create a tour, needs companyId, boatId and tour data and before creating the tour, check if there is a tour in the same time range
  Future<void> createTour(String companyId, String boatId, TourModel tour) async {
    // Extend the date range to one month before and after
    final startTime = tour.startTime.toDate().subtract(Duration(days: 30));
    final endTime = tour.endTime.toDate().add(Duration(days: 30));
    
    final existingTours = await getTours(companyId, boatId, startTime, endTime);
    print('Existing tours: ${existingTours}');
    print('Tour: ${tour.startTime} to ${tour.endTime}');
    
    for (var existingTour in existingTours) {
      if ((tour.startTime.compareTo(existingTour.startTime) >= 0 && tour.startTime.compareTo(existingTour.endTime) < 0) ||
          (tour.endTime.compareTo(existingTour.startTime) > 0 && tour.endTime.compareTo(existingTour.endTime) <= 0) ||
          (tour.startTime.compareTo(existingTour.startTime) <= 0 && tour.endTime.compareTo(existingTour.endTime) >= 0)) {
        throw Exception('A tour already exists in this time range.');
      }
    }
    
    final tourRef = FirebaseFirestore.instance.collection(FirestorePath.tours(companyId, boatId)).doc();
    await tourRef.set(tour.toMap());
  }

  //update a tour, needs companyId, boatId and tourId
  Future<void> updateTour(String companyId, String boatId, String tourId, TourModel tour) async {
    final tourRef = FirebaseFirestore.instance
        .collection(FirestorePath.tours(companyId, boatId))
        .doc(tourId);
    await tourRef.update(tour.toMap());
  }

  // delete a tour, needs companyId, boatId and tourId
  Future<void> deleteTour(String companyId, String boatId, String tourId) async {
    final tourRef = FirebaseFirestore.instance
        .collection(FirestorePath.tours(companyId, boatId))
        .doc(tourId);
    await tourRef.delete();
  }

  /* Group section */
  
  // create a group, needs companyId, boatId, tourId and group data
  Future<void> createGroup(String companyId, String boatId, String tourId, GroupModel group) async {
    final groupRef = FirebaseFirestore.instance.collection(FirestorePath.groups(companyId, boatId, tourId)).doc();
    await groupRef.set(group.toMap());
  }

  // update a group, needs companyId, boatId, tourId and groupId
  Future<void> updateGroup(String companyId, String boatId, String tourId, String groupId, GroupModel group) async {  
    final groupRef = FirebaseFirestore.instance
        .collection(FirestorePath.groups(companyId, boatId, tourId))
        .doc(groupId);
    await groupRef.update(group.toMap());
  }

  // delete a group, needs companyId, boatId, tourId and groupId
  Future<void> deleteGroup(String companyId, String boatId, String tourId, String groupId) async {
    final groupRef = FirebaseFirestore.instance
        .collection(FirestorePath.groups(companyId, boatId, tourId))
        .doc(groupId);
    await groupRef.delete();
  } 

  // get all groups for a specific tour by tourId
  Future<List<GroupModel>> getGroups(String companyId, String boatId, String tourId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection(FirestorePath.groups(companyId, boatId, tourId))
        .get();
    return querySnapshot.docs.map((doc) => GroupModel.fromMap(doc.data(), doc.id)).toList();
  }

  /* Type section */

  // get tour types by companyId and boatId
  Future<Map<String, dynamic>> getTourTypesAndBoatInfo(String companyId, String boatId) async {
    final tourTypesSnapshot = await FirebaseFirestore.instance
        .collection(FirestorePath.tourTypes(companyId, boatId))
        .get(); 
    final boatSnapshot = await FirebaseFirestore.instance
        .collection(FirestorePath.boats(companyId))
        .doc(boatId)
        .get();
    
    final List<TypeModel> tourTypes = tourTypesSnapshot.docs
        .map((doc) => TypeModel.fromMap(doc.data(), doc.id))
        .toList();
    
    final boatInfo = boatSnapshot.exists ? BoatModel.fromMap(boatSnapshot.data()!, boatSnapshot.id) : null;
    
    return {
      'tourTypes': tourTypes,
      'boatInfo': boatInfo,
    };
  }
  /* Boat section */
  //Create a boat, needs companyId and boat data
  Future<void> createBoat(String companyId, BoatModel boat) async {
    final boatRef = FirebaseFirestore.instance.collection(FirestorePath.boats(companyId)).doc(boat.name);
    await boatRef.set(boat.toMap());
  }
  
  
}