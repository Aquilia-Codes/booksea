import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api_client.dart';

/// Wraps the single Socket.IO connection to the backend (see
/// backend/src/sockets.ts and backend/src/lib/realtime.ts). The server only
/// ever emits change *signals* ('tours:changed', 'summary:changed',
/// 'groups:changed') scoped to a boat/tour room - never the changed data
/// itself - so callers are expected to refetch via the REST call they
/// already use whenever one of these fires. See ApiDatabase for that half.
///
/// Room membership is reference-counted: home.dart watches a boat's tour
/// list and its price summary at the same time, both for the same boatId,
/// so two independent callers can both want the same `boat:<id>` room. The
/// room is only actually left server-side once every caller has left it.
class RealtimeClient {
  RealtimeClient._();
  static final instance = RealtimeClient._();

  IO.Socket? _socket;
  final Map<String, int> _boatRefCounts = {};
  final Map<String, int> _tourRefCounts = {};

  final _toursChangedController = StreamController<void>.broadcast();
  final _summaryChangedController = StreamController<void>.broadcast();
  final _groupsChangedController = StreamController<void>.broadcast();
  final _meChangedController = StreamController<void>.broadcast();
  final _connectedController = StreamController<void>.broadcast();

  Stream<void> get toursChanged => _toursChangedController.stream;
  Stream<void> get summaryChanged => _summaryChangedController.stream;
  Stream<void> get groupsChanged => _groupsChangedController.stream;

  /// Fires when someone else (an owner, via
  /// PATCH /companies/:id/members/:userId) changes this signed-in user's
  /// own access/role/provision. Unlike tours/groups, there's no join call
  /// for this - every authenticated socket is auto-joined to its own
  /// `user:<id>` room server-side (see sockets.ts), since a user always has
  /// access to their own data. AuthProvider is the only consumer.
  Stream<void> get meChanged => _meChangedController.stream;

  /// Fires whenever the socket (re)connects, including the very first
  /// connect. Rooms don't survive a reconnect - Socket.IO gives a
  /// reconnecting client a brand new server-side session/id - so callers
  /// use this as a cue to refetch, in case a change happened while the
  /// socket was briefly disconnected and its signal was missed entirely.
  Stream<void> get onConnected => _connectedController.stream;

  IO.Socket _ensureSocket() {
    final existing = _socket;
    if (existing != null) return existing;

    // setAuthFn (not setAuth) re-reads the token on every connection
    // attempt rather than baking in whatever was current when the socket
    // was first constructed - needed since the access token rotates
    // independently (see ApiClient._refreshOnce) and a reconnect after
    // that rotation must hand the server the new one, not the original.
    final socket = IO.io(
      ApiClient.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((cb) => cb({'token': ApiClient.instance.accessToken}))
          .build(),
    );

    socket.onConnect((_) {
      for (final boatId in _boatRefCounts.keys) {
        socket.emitWithAckAsync('join:boat', boatId);
      }
      for (final tourId in _tourRefCounts.keys) {
        socket.emitWithAckAsync('join:tour', tourId);
      }
      _connectedController.add(null);
    });

    socket.on('tours:changed', (_) => _toursChangedController.add(null));
    socket.on('summary:changed', (_) => _summaryChangedController.add(null));
    socket.on('groups:changed', (_) => _groupsChangedController.add(null));
    socket.on('me:changed', (_) => _meChangedController.add(null));

    _socket = socket;
    return socket;
  }

  /// Ensures the socket exists and is (re)connecting. `meChanged` has no
  /// join call to piggyback on the way joinBoat/joinTour implicitly create
  /// the socket for the other streams, so AuthProvider calls this directly
  /// once it wants to start listening.
  void connect() => _ensureSocket();

  Future<bool> joinBoat(String boatId) async {
    _boatRefCounts[boatId] = (_boatRefCounts[boatId] ?? 0) + 1;
    final ack = await _ensureSocket().emitWithAckAsync('join:boat', boatId);
    return ack == true;
  }

  void leaveBoat(String boatId) {
    final remaining = (_boatRefCounts[boatId] ?? 1) - 1;
    if (remaining <= 0) {
      _boatRefCounts.remove(boatId);
      _socket?.emit('leave:boat', boatId);
    } else {
      _boatRefCounts[boatId] = remaining;
    }
  }

  Future<bool> joinTour(String tourId) async {
    _tourRefCounts[tourId] = (_tourRefCounts[tourId] ?? 0) + 1;
    final ack = await _ensureSocket().emitWithAckAsync('join:tour', tourId);
    return ack == true;
  }

  void leaveTour(String tourId) {
    final remaining = (_tourRefCounts[tourId] ?? 1) - 1;
    if (remaining <= 0) {
      _tourRefCounts.remove(tourId);
      _socket?.emit('leave:tour', tourId);
    } else {
      _tourRefCounts[tourId] = remaining;
    }
  }

  /// Tears the connection down on sign-out - otherwise it would keep
  /// retrying with a token that's just been cleared, and the next signed-in
  /// user would inherit whatever rooms the previous session had joined.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _boatRefCounts.clear();
    _tourRefCounts.clear();
  }
}
