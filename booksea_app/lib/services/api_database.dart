import 'dart:async';
import 'dart:convert';

import 'package:booksea_app/models/boat_model.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/models/type_model.dart';
import 'package:booksea_app/services/api_client.dart';
import 'package:booksea_app/services/realtime_client.dart';

/// Drop-in replacement for the old FirestoreDatabase - same public method
/// signatures (see docs/migration-notes.md "Route map"), backed by the
/// Express/Postgres API instead of Firestore. `companyId` parameters are
/// kept for call-site compatibility but ignored: the backend always derives
/// the caller's company from their JWT, never from a client-supplied value
/// (see backend/src/lib/authz.ts).
///
/// Streams (`getToursStream`, `getSumOfPriceStream`, `getGroups`,
/// `searchTours`) are backed by socket.io change signals (see
/// RealtimeClient and backend/src/lib/realtime.ts) rather than polling: the
/// server tells us *that* something changed, and we refetch the same REST
/// call this class already exposes as a Future - see `_realtimeStream`.
///
/// Note: `companyExists` from the old FirestoreDatabase has no equivalent
/// here by design - the backend folds that check into `POST /me/company`
/// itself (404 if the code doesn't match a company), so there's nothing
/// left to separately check client-side.
class ApiDatabase {
  ApiDatabase({required this.uid});
  final String uid;

  final ApiClient _client = ApiClient.instance;
  final RealtimeClient _realtime = RealtimeClient.instance;

  // `fingerprint` lets a refetch skip re-emitting when nothing actually
  // changed - without it, a redundant `*:changed` signal (three fire
  // together on a group edit, see tours.ts/groups.ts) would rebuild the
  // StreamBuilder with a structurally-identical-but-new list/map, which is
  // what caused a visible "blink" back when this was plain polling.
  //
  // `join`/`leave` manage the socket room backing `changes` (see
  // RealtimeClient - reference-counted, since e.g. home.dart's tour list
  // and price summary both watch the same boat at once). `onConnected` is
  // included as a second trigger alongside `changes` because a signal fired
  // while this socket was briefly disconnected is simply lost - refetching
  // on every (re)connect, not just on an explicit change signal, is what
  // catches up on anything missed.
  Stream<T> _realtimeStream<T>({
    required Future<bool> Function() join,
    required void Function() leave,
    required Stream<void> changes,
    required Future<T> Function() fetch,
    String Function(T value)? fingerprint,
  }) {
    late StreamController<T> controller;
    StreamSubscription<void>? changesSub;
    StreamSubscription<void>? connectedSub;
    String? lastFingerprint;

    Future<void> refetch() async {
      try {
        final value = await fetch();
        final fp = fingerprint?.call(value);
        if (fingerprint == null || fp != lastFingerprint) {
          lastFingerprint = fp;
          controller.add(value);
        }
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    controller = StreamController<T>(
      onListen: () async {
        changesSub = changes.listen((_) => refetch());
        connectedSub = _realtime.onConnected.listen((_) => refetch());
        await join();
        await refetch();
      },
      onCancel: () async {
        await changesSub?.cancel();
        await connectedSub?.cancel();
        leave();
      },
    );
    return controller.stream;
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
        .map((e) =>
            TourModel.fromMap(e as Map<String, dynamic>, e['id'] as String))
        .toList();
  }

  // getSumOfPriceStream -> GET /boats/:id/tours/summary (socket.io push)
  Stream<Map<String, dynamic>> getSumOfPriceStream(
      String companyId, String boatId, DateTime startTime, DateTime endTime) {
    return _realtimeStream(
      join: () => _realtime.joinBoat(boatId),
      leave: () => _realtime.leaveBoat(boatId),
      changes: _realtime.summaryChanged,
      fetch: () async {
        final data =
            await _client.get('/boats/${_seg(boatId)}/tours/summary', query: {
          'from': startTime.toUtc().toIso8601String(),
          'to': endTime.toUtc().toIso8601String(),
        }) as Map<String, dynamic>;
        return {
          'totalPrice': (data['totalPrice'] as num).toDouble(),
          'totalProvision': (data['totalProvision'] as num).toDouble(),
        };
      },
      fingerprint: (value) => jsonEncode(value),
    );
  }

  static String _fingerprintTours(List<TourModel> tours) =>
      jsonEncode(tours.map((t) => t.toMap()).toList());

  // getToursStream -> GET /boats/:id/tours (socket.io push)
  Stream<List<TourModel>> getToursStream(
      String companyId, String boatId, DateTime startTime, DateTime endTime) {
    return _realtimeStream(
      join: () => _realtime.joinBoat(boatId),
      leave: () => _realtime.leaveBoat(boatId),
      changes: _realtime.toursChanged,
      fetch: () => getTours(companyId, boatId, startTime, endTime),
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
  // allowOverbook: set once the booker has confirmed a capacity warning
  // popup (boats routinely get booked a little over nominal capacity in
  // practice) - the backend still blocks accidental overbooking by default.
  Future<GroupModel> createGroup(
      String companyId, String boatId, String tourId, GroupModel group,
      {bool allowOverbook = false}) async {
    final data = await _client.post('/tours/${_seg(tourId)}/groups', {
      ...group.toMap(),
      'allowOverbook': allowOverbook,
    }) as Map<String, dynamic>;
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

  // getGroups -> GET /tours/:id/groups (socket.io push)
  Stream<List<GroupModel>> getGroups(
      String companyId, String boatId, String tourId) {
    return _realtimeStream(
      join: () => _realtime.joinTour(tourId),
      leave: () => _realtime.leaveTour(tourId),
      changes: _realtime.groupsChanged,
      fetch: () async {
        final data = await _client.get('/tours/${_seg(tourId)}/groups')
            as List<dynamic>;
        return data
            .map((e) => GroupModel.fromMap(
                e as Map<String, dynamic>, e['id'] as String))
            .toList();
      },
      fingerprint: (groups) =>
          jsonEncode(groups.map((g) => g.toMap()).toList()),
    );
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
    await _client
        .patch('/groups/${_seg(group.id)}/arrival', {'hasArrived': hasArrived});
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
          .map((e) =>
              TypeModel.fromMap(e as Map<String, dynamic>, e['id'] as String))
          .toList(),
      'boatInfo':
          boatInfoData != null ? BoatModel.fromMap(boatInfoData, boatId) : null,
    };
  }

  // getTypeInfo -> GET /boats/:id/tour-types/:name
  Future<TypeModel> getTypeInfo(
      String companyId, String boatId, String typeName) async {
    final data =
        await _client.get('/boats/${_seg(boatId)}/tour-types/${_seg(typeName)}')
            as Map<String, dynamic>;
    return TypeModel.fromMap(data, data['id'] as String);
  }

  /* Boat section */

  // createBoat -> POST /companies/:id/boats
  Future<void> createBoat(String companyId, BoatModel boat) async {
    await _client.post('/companies/${_seg(companyId)}/boats', boat.toMap());
  }

  /* Search section */

  // searchTours -> GET /boats/:id/tours/search
  // One-shot fetch, not a stream - the search screen recomputes this on
  // every rebuild anyway (several independent filter controls feed it, so
  // there's no single "did the relevant thing change" check worth writing),
  // and unlike getToursStream/getSumOfPriceStream a plain REST call has no
  // per-call socket-room cost, so recomputing it per rebuild is cheap.
  // Reacting to *pushed* changes (as opposed to the user's own filter
  // edits) is handled separately by watchBoatTourChanges below, which the
  // search screen joins once for its own lifetime instead of once per
  // keystroke/filter tap.
  Future<List<TourModel>> searchTours(
      String companyId,
      String boatId,
      List<String> tourTypeNames,
      DateTime startTime,
      DateTime endTime,
      int count) async {
    final data =
        await _client.get('/boats/${_seg(boatId)}/tours/search', query: {
      'types': tourTypeNames.join(','),
      'from': startTime.toUtc().toIso8601String(),
      'to': endTime.toUtc().toIso8601String(),
      'seats': count.toString(),
    }) as List<dynamic>;
    return data
        .map((e) =>
            TourModel.fromMap(e as Map<String, dynamic>, e['id'] as String))
        .toList();
  }

  // Joins boatId's realtime room for as long as this stream has a listener,
  // and emits once per relevant signal - a real 'tours:changed' event, or a
  // reconnect (which could have missed one while briefly disconnected) -
  // without owning a fetch itself. For screens like search that need to
  // react to a boat's tours changing but decide for themselves when and how
  // to refetch (with live filter values), unlike the other stream methods
  // above which each own one fixed fetch for their whole lifetime.
  Stream<void> watchBoatTourChanges(String boatId) {
    late StreamController<void> controller;
    StreamSubscription<void>? changesSub;
    StreamSubscription<void>? connectedSub;

    controller = StreamController<void>(
      onListen: () async {
        changesSub =
            _realtime.toursChanged.listen((_) => controller.add(null));
        connectedSub =
            _realtime.onConnected.listen((_) => controller.add(null));
        await _realtime.joinBoat(boatId);
      },
      onCancel: () async {
        await changesSub?.cancel();
        await connectedSub?.cancel();
        _realtime.leaveBoat(boatId);
      },
    );
    return controller.stream;
  }
}
