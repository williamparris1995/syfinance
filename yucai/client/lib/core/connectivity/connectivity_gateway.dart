import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Shared online/offline gateway (R6 ADR-5): one boolean state + change
/// events that the UI and the dual-source seam (feature C) subscribe to,
/// instead of scattered connectivity_plus calls. The plugin supports the
/// Windows desktop target.
class ConnectivityGateway {
  ConnectivityGateway({Stream<List<ConnectivityResult>>? statusStream})
      : _status = (statusStream ?? Connectivity().onConnectivityChanged)
            .asBroadcastStream() {
    _status.listen(
      _onResults,
      onError: (Object _) {
        // Plugin failures must not crash consumers: stay optimistic (online)
        // and let RPC failures surface through the existing error paths.
        _update(true);
      },
    );
  }

  final Stream<List<ConnectivityResult>> _status;

  bool _current = true;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  /// Latest known connectivity. Optimistic default (true) until the first
  /// plugin event arrives.
  bool get current => _current;

  /// Distinct change events (no initial replay; poll [current] for state).
  Stream<bool> get online => _changes.stream.distinct();

  void _onResults(List<ConnectivityResult> results) =>
      _update(results.any((r) => r != ConnectivityResult.none));

  void _update(bool online) {
    final changed = online != _current;
    _current = online;
    if (changed) _changes.add(online);
  }
}
