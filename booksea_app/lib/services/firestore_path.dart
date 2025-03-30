/*
This class defines all the possible read/write locations from the FirebaseFirestore database.
In future, any new path can be added here.
This class work together with FirestoreService and FirestoreDatabase.
 */
/* this later will be replaced with the actual path from the FirebaseFirestore database */
class FirestorePath {
  //This is the path for all tours for a specific boat
  static String tours(String companyId, String boatId) =>
      'company/$companyId/boats/$boatId/tours';
  //This is the path for a specific tour for a specific boat
  static String tour(String companyId, String boatId, String tourId) =>
      'company/$companyId/boats/$boatId/tours/$tourId';

  //This is the path for all the types of tours for a specific boat
  static String tourTypes(String companyId, String boatId) =>
      'company/$companyId/boats/$boatId/tourTypes';
  //This is the path for a specific type of tour for a specific boat
  static String tourType(String companyId, String boatId, String tourTypeId) =>
      'company/$companyId/boats/$boatId/tourTypes/$tourTypeId';

  //This is the path for all groups for a specific tour
  static String groups(String companyId, String boatId, String tourId) =>
      'company/$companyId/boats/$boatId/tours/$tourId/groups';
  //This is the path for a specific group for a specific tour
  static String group(
          String companyId, String boatId, String tourId, String groupId) =>
      'company/$companyId/boats/$boatId/tours/$tourId/groups/$groupId';

  //This is the path for a specific company
  static String company(String companyId) => 'company/$companyId';

  //This is the path to the companies collection
  static String companies() => 'company';

  //This is the path to the company document with the company code field
  static String companyWithCodeField(String companyCode) =>
      'company?companyCode=$companyCode';

  //This is the path for a specific user
  static String user(String userId) => 'users/$userId';

  //This is the path for a specific boat
  static String boat(String companyId, String boatId) =>
      'company/$companyId/boats/$boatId';

  //This is the path for the boats collection
  static String boats(String companyId) => 'company/$companyId/boats';

  //This is the path for the logs collection
  static String logs(String companyId) => 'company/$companyId/logs';
}
