import 'dart:async';
import 'dart:convert';

import 'package:booksea_app/models/boat_model.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/models/type_model.dart';
import 'package:booksea_app/services/api_client.dart';

/// Drop-in replacement for the old FirestoreDatabase - same public method
/// signatures (see docs/migration-notes.md "Route map"), backed by the
/// Express/Postgres API instead of Firestore. `companyId` parameters are
/// kept for call-site compatibility but ignored: the backend always derives
/// the caller's company from their JWT, never from a client-supplied value
/// (see backend/src/lib/authz.ts).
///
/// Streams (`getToursStream`, `getSumOfPriceStream`, `getGroups`,
/// `searchTours`) are polling placeholders for now - each poll re-runs the
/// same REST call this class already exposes as a Future. Phase 7 replaces
/// this with socket.io push updates without changing these signatures.
///
/// Note: `companyExists` from the old FirestoreDatabase has no equivalent
/// here by design - the backend folds that check into `POST /me/company`
/// itself (404 if the code doesn't match a company), so there's nothing
/// left to separately check client-side.
class ApiDatabase {
  ApiDatabase({required this.uid});
  final String uid;

  final ApiClient _client = ApiClient.instance;

  static const _pollInterval = Duration(seconds: 8);

  // `fingerprint` lets a poll skip re-emitting when nothing actually
  // changed - without it, every tick rebuilds the StreamBuilder with a
  // structurally-identical-but-new list/map, which is what caused the
  // visible "blink" on every refresh even when nothing new happened.
  Stream<T> _pollStream<T>(
    Future<T> Function() fetch, {
    String Function(T value)? fingerprint,
  }) async* {
    String? lastFingerprint;
    while (true) {
      final value = await fetch();
      final fp = fingerprint?.call(value);
      if (fingerprint == null || fp != lastFingerprint) {
        lastFingerprint = fp;
        yield value;
      }
      await Future.delayed(_pollInterval);
    }
  }

  String _seg(String value) => Uri.encodeComponent(value);

  // getUser -> GET /me
  Future<UserModel> getUser() async {
    final data = await _client.get('/me') as Map<String, dynamic>;
    return UserModel.fromMap(data, data['uid'] as String);
  }

  // setUser -> PATCH /me
  // Narrower than the old Firestore setUser(): the API only allows
  // self-editing nickname/phoneNumber (see backend/src/routes/me.ts).
  Future<void> setUser(UserModel user) async {
    await _client.patch('/me', {
      'nickname': user.nickname,
      if (user.phoneNumber != null) 'phoneNumber': user.phoneNumber,
    });
  }

  // writeCompanyIdToUserDocument -> POST /me/company
  Future<void> writeCompanyIdToUserDocument(String companyCode) async {
    await _client.post('/me/company', {'companyCode': companyCode});
  }

  /* Tour section */

  // getTours -> GET /boats/:id/tours
  Future<List<TourModel>> getTours(String companyId, String boatId,
      DateTime startTime, DateTime endTime) async {
    final data = await _client.get('/boats/${_seg(boatId)}/tours', query: {
      'from': startTime.toUtc().toIso8601String(),
      'to': endTime.toUtc().toIso8601String(),
    }) as List<dynamic>;
    return data
        .map((e) => TourModel.fromMap(
            e as Map<String, dynamic>, e['id'] as String))
        .toList();
  }

  // getSumOfPriceStream -> GET /boats/:id/tours/summary (polling)
  Stream<Map<String, dynamic>> getSumOfPriceStream(String companyId,
      String boatId, DateTime startTime, DateTime endTime) {
    return _pollStream(() async {
      final data =
          await _client.get('/boats/${_seg(boatId)}/tours/summary', query: {
        'from': startTime.toUtc().toIso8601String(),
        'to': endTime.toUtc().toIso8601String(),
      }) as Map<String, dynamic>;
      return {
        'totalPrice': (data['totalPrice'] as num).toDouble(),
        'totalProvision': (data['totalProvision'] as num).toDouble(),
      };
    }, fingerprint: (value) => jsonEncode(value));
  }

  static String _fingerprintTours(List<TourModel> tours) =>
      jsonEncode(tours.map((t) => t.toMap()).toList());

  // getToursStream -> GET /boats/:id/tours (polling)
  Stream<List<TourModel>> getToursStream(
      String companyId, String boatId, DateTime startTime, DateTime endTime) {
    return _pollStream(
      () => getTours(companyId, boatId, startTime, endTime),
      fingerprint: _fingerprintTours,
    );
  }

  // createTour -> POST /boats/:id/tours
  Future<void> createTour(
      String companyId, String boatId, TourModel tour) async {
    await _client.post('/boats/${_seg(boatId)}/tours', tour.toMap());
  }

  // updateTour -> PATCH /tours/:id
  Future<void> updateTour(
      String companyId, String boatId, String tourId, TourModel tour) async {
    await _client.patch('/tours/${_seg(tourId)}', tour.toMap());
  }

  // deleteTour -> DELETE /tours/:id
  Future<void> deleteTour(
      String companyId, String boatId, String tourId) async {
    await _client.delete('/tours/${_seg(tourId)}');
  }

  /* Group section */

  // createGroup -> POST /tours/:id/groups
  Future<GroupModel> createGroup(
      String companyId, String boatId, String tourId, GroupModel group) async {
    final data = await _client.post(
        '/tours/${_seg(tourId)}/groups', group.toMap()) as Map<String, dynamic>;
    return GroupModel.fromMap(data, data['id'] as String);
  }

  // updateGroup -> PATCH /groups/:id
  Future<void> updateGroup(String companyId, String boatId, String tourId,
      String groupId, GroupModel group) async {
    await _client.patch('/groups/${_seg(groupId)}', group.toMap());
  }

  // deleteGroup -> DELETE /groups/:id
  Future<void> deleteGroup(
      String companyId, String boatId, String tourId, String groupId) async {
    await _client.delete('/groups/${_seg(groupId)}');
  }

  // getGroups -> GET /tours/:id/groups (polling)
  Stream<List<GroupModel>> getGroups(
      String companyId, String boatId, String tourId) {
    return _pollStream(() async {
      final data =
          await _client.get('/tours/${_seg(tourId)}/groups') as List<dynamic>;
      return data
          .map((e) => GroupModel.fromMap(
              e as Map<String, dynamic>, e['id'] as String))
          .toList();
    }, fingerprint: (groups) => jsonEncode(groups.map((g) => g.toMap()).toList()));
  }

  // getGroup -> GET /groups/:id
  Future<GroupModel> getGroup(
      String companyId, String boatId, String tourId, String groupId) async {
    final data =
        await _client.get('/groups/${_seg(groupId)}') as Map<String, dynamic>;
    return GroupModel.fromMap(data, data['id'] as String);
  }

  // updateGroupHasArrived -> PATCH /groups/:id/arrival
  Future<void> updateGroupHasArrived(String companyId, String boatId,
      String tourId, bool hasArrived, GroupModel group) async {
    await _client.patch(
        '/groups/${_seg(group.id)}/arrival', {'hasArrived': hasArrived});
  }

  /* Type section */

  // getTourTypesAndBoatInfo -> GET /boats/:id
  Future<Map<String, dynamic>> getTourTypesAndBoatInfo(
      String companyId, String boatId) async {
    final data =
        await _client.get('/boats/${_seg(boatId)}') as Map<String, dynamic>;
    final boatInfoData = data['boatInfo'] as Map<String, dynamic>?;
    final tourTypesData = data['tourTypes'] as List<dynamic>;
    return {
      'tourTypes': tourTypesData
          .map((e) => TypeModel.fromMap(
              e as Map<String, dynamic>, e['id'] as String))
          .toList(),
      'boatInfo': boatInfoData != null
          ? BoatModel.fromMap(boatInfoData, boatId)
          : null,
    };
  }

  // getTypeInfo -> GET /boats/:id/tour-types/:name
  Future<TypeModel> getTypeInfo(
      String companyId, String boatId, String typeName) async {
    final data = await _client.get(
        '/boats/${_seg(boatId)}/tour-types/${_seg(typeName)}') as Map<String, dynamic>;
    return TypeModel.fromMap(data, data['id'] as String);
  }

  /* Boat section */

  // createBoat -> POST /companies/:id/boats
  Future<void> createBoat(String companyId, BoatModel boat) async {
    await _client.post('/companies/${_seg(companyId)}/boats', boat.toMap());
  }

  /* Search section */

  // searchTours -> GET /boats/:id/tours/search (polling)
  Stream<List<TourModel>> searchTours(
      String companyId,
      String boatId,
      List<String> tourTypeNames,
      DateTime startTime,
      DateTime endTime,
      int count) {
    return _pollStream(() async {
      final data =
          await _client.get('/boats/${_seg(boatId)}/tours/search', query: {
        'types': tourTypeNames.join(','),
        'from': startTime.toUtc().toIso8601String(),
        'to': endTime.toUtc().toIso8601String(),
        'seats': count.toString(),
      }) as List<dynamic>;
      return data
          .map((e) => TourModel.fromMap(
              e as Map<String, dynamic>, e['id'] as String))
          .toList();
    }, fingerprint: _fingerprintTours);
  }
}
