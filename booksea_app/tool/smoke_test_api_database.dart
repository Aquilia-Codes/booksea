// Manual smoke test for ApiDatabase against a running local backend.
// Run: dart run tool/smoke_test_api_database.dart <accessToken>
// (get a token from `npm run seed:smoke` in backend/)
// Not part of the app - safe to delete once phase 6 (real auth) lands.
import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:booksea_app/services/api_client.dart';
import 'package:booksea_app/services/api_database.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tool/smoke_test_api_database.dart <accessToken>');
    return;
  }
  ApiClient.instance.setTokens(accessToken: args[0], refreshToken: 'unused');
  final db = ApiDatabase(uid: 'smoke');
  const boatId = 'Catamaran'; // name, not uuid - see docs/migration-notes.md
  const companyId = 'unused'; // backend derives this from the JWT

  print('--- getUser ---');
  final user = await db.getUser();
  print('uid=${user.uid} email=${user.email} boatIds=${user.boatIds} '
      'companyId="${user.companyId}" provision=${user.provision}');

  print('--- getTourTypesAndBoatInfo ---');
  final info = await db.getTourTypesAndBoatInfo(companyId, boatId);
  print('boatInfo=${info['boatInfo']} tourTypes=${info['tourTypes']}');

  print('--- createTour ---');
  final tour = TourModel(
    tourName: 'Smoke Test Tour',
    tourType: '',
    typeImage: 1,
    capacity: 8,
    startTime: DateTime.utc(2026, 9, 15, 9),
    endTime: DateTime.utc(2026, 9, 15, 12),
    note: 'from dart smoke test',
  );
  await db.createTour(companyId, boatId, tour);

  print('--- getTours ---');
  final tours = await db.getTours(
      companyId, boatId, DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 30));
  print('found ${tours.length} tour(s): '
      '${tours.map((t) => '${t.tourName} (${t.id}) price=${t.price} filled=${t.filled}')}');
  final createdTour = tours.firstWhere((t) => t.tourName == 'Smoke Test Tour');

  print('--- createGroup ---');
  final group = GroupModel(
    groupName: 'Dart Smoke Family',
    adultCount: 2,
    childCount: 0,
    price: 0, // whole-number price - the exact case that used to crash
    paymentStatus: 'unpaid',
    mobileNumber: '',
    countryCode: '',
    countryDialogCode: '',
  );
  final createdGroup =
      await db.createGroup(companyId, boatId, createdTour.id, group);
  print('created group ${createdGroup.id} price=${createdGroup.price} '
      'bookerId=${createdGroup.bookerId}');

  print('--- updateGroupHasArrived ---');
  await db.updateGroupHasArrived(
      companyId, boatId, createdTour.id, true, createdGroup);

  print('--- getGroups (first poll only) ---');
  final groups =
      await db.getGroups(companyId, boatId, createdTour.id).first;
  print('groups: ${groups.map((g) => '${g.groupName} hasArrived=${g.hasArrived}')}');

  print('--- cleanup: deleteGroup, deleteTour ---');
  await db.deleteGroup(companyId, boatId, createdTour.id, createdGroup.id);
  await db.deleteTour(companyId, boatId, createdTour.id);

  print('--- ALL OK ---');
}
