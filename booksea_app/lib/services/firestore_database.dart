import 'dart:async'; 
import 'package:booksea_app/models/company_model.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/services/firestore_path.dart';
import 'package:booksea_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 

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
        await setUser(user.copyWith(companyId: company.id));
      }
    } else {
      print('No company found with the provided company code');
    }
  }

  //checking if a company with the given companyid exists
  Future<bool> companyExists(String companyId) async {
    final docRef = FirebaseFirestore.instance.collection('company').doc(companyId);
    final docSnapshot = await docRef.get();
    return docSnapshot.exists;
  }
}