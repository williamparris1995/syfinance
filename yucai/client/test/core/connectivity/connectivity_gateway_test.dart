// ConnectivityGateway unit tests: injected fake status stream drives the
// distinct online events + current flag (R6 ADR-5). No platform channel.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';

void main() {
  late StreamController<List<ConnectivityResult>> source;

  setUp(() => source = StreamController<List<ConnectivityResult>>.broadcast());

  tearDown(() => source.close());

  test('optimistic default until the first event', () {
    final gateway = ConnectivityGateway(statusStream: source.stream);
    expect(gateway.current, isTrue);
  });

  test('network recovery event flips state and emits online', () async {
    final gateway = ConnectivityGateway(statusStream: source.stream);
    final events = <bool>[];
    final sub = gateway.online.listen(events.add);

    source.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.current, isFalse);

    source.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.current, isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(events, [false, true]);
    await sub.cancel();
  });

  test('distinct: repeated same-status events do not re-emit', () async {
    final gateway = ConnectivityGateway(statusStream: source.stream);
    final events = <bool>[];
    final sub = gateway.online.listen(events.add);

    source.add([ConnectivityResult.none]);
    source.add([ConnectivityResult.none]);
    source.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(events, [false, true]);
    await sub.cancel();
  });

  test('plugin error stays optimistic (online) and does not crash', () async {
    final gateway = ConnectivityGateway(statusStream: source.stream);
    final events = <bool>[];
    final sub = gateway.online.listen(events.add);

    source.addError(StateError('channel missing'));
    await Future<void>.delayed(Duration.zero);

    expect(gateway.current, isTrue);
    expect(events, isEmpty);
    await sub.cancel();
  });
}
