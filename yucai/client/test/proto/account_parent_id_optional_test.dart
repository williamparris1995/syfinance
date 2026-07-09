// Verifies proto3 optional parent_id (field 36) on UpdateAccountRequest is
// correctly set + serialized: setting the setter marks hasParentId() so the
// field travels on the wire (server sees req.ParentId != nil).
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;

void main() {
  group('UpdateAccountRequest.parentId (proto3 optional field 36)', () {
    test('setter marks hasParentId so the field is serialized on the wire', () {
      final req = pb.UpdateAccountRequest(
        id: 'acc-1',
        version: Int64(2),
        name: '老村长',
      );
      // absent before set
      expect(req.hasParentId(), isFalse,
          reason: 'parentId should be absent on a fresh message');
      expect(req.parentId, '');

      // set via the generated setter (what remote_ds does)
      req.parentId = 'parent-uuid-1234';
      expect(req.hasParentId(), isTrue,
          reason: 'setter must mark the optional has-bit so server sees '
              'req.ParentId != nil');
      expect(req.parentId, 'parent-uuid-1234');

      // round-trip through the wire: serialize → parse → field survives
      final bytes = req.writeToBuffer();
      final decoded = pb.UpdateAccountRequest.fromBuffer(bytes);
      expect(decoded.hasParentId(), isTrue,
          reason: 'parentId must survive serialization (has-bit set on wire)');
      expect(decoded.parentId, 'parent-uuid-1234');

      // clearing works too (used if we ever need "explicitly empty")
      decoded.clearParentId();
      expect(decoded.hasParentId(), isFalse);
    });

    test('omitting parentId leaves it absent (server treats as unchanged)', () {
      final req = pb.UpdateAccountRequest(id: 'acc-1', name: 'x');
      expect(req.hasParentId(), isFalse);
      final bytes = req.writeToBuffer();
      final decoded = pb.UpdateAccountRequest.fromBuffer(bytes);
      expect(decoded.hasParentId(), isFalse,
          reason: 'absent optional must not appear on the wire');
    });
  });
}
