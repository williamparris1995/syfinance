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

  test('initial platform check seeds the state (cold-start offline)',
      () async {
    final gateway = ConnectivityGateway(
      statusStream: source.stream,
      initialCheck: () async => [ConnectivityResult.none],
    );
    await Future<void>.delayed(Duration.zero);
    expect(gateway.current, isFalse);

    final optimistic = ConnectivityGateway(
      statusStream: source.stream,
      initialCheck: () async => [ConnectivityResult.ethernet],
    );
    await Future<void>.delayed(Duration.zero);
    expect(optimistic.current, isTrue);
  });

  test('optimistic default until the initial check resolves', () {
    final gateway = ConnectivityGateway(
      statusStream: source.stream,
      // Never-completing initial check keeps the default visible.
      initialCheck: () => Completer<List<ConnectivityResult>>().future,
    );
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
