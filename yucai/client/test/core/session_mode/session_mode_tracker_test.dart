import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

void main() {
  test('defaults to guest (safe side before AppStarted resolves)', () {
    expect(SessionModeTracker().isGuest, isTrue);
  });

  test('settable — AuthBloc.onChange drives it', () {
    final tracker = SessionModeTracker();
    tracker.isGuest = false;
    expect(tracker.isGuest, isFalse);
    tracker.isGuest = true;
    expect(tracker.isGuest, isTrue);
  });
}
