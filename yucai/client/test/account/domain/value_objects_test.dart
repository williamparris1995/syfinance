import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;

void main() {
  group('AccountType', () {
    for (final t in AccountType.values) {
      test('$t round-trips through proto', () {
        expect(accountTypeFromProto(t.toProto()), t);
      });
    }
    test('unspecified maps to asset (default)', () {
      expect(accountTypeFromProto(pb.AccountType.ACCOUNT_TYPE_UNSPECIFIED), AccountType.asset);
    });
    test('every type has a Chinese label', () {
      for (final t in AccountType.values) {
        expect(t.label.isNotEmpty, true);
      }
    });
  });

  group('Ownership', () {
    test('round-trips', () {
      expect(ownershipFromProto(Ownership.personal.toProto()), Ownership.personal);
      expect(ownershipFromProto(Ownership.joint.toProto()), Ownership.joint);
    });
  });

  group('AccountStatus', () {
    test('round-trips', () {
      expect(accountStatusFromProto(AccountStatus.active.toProto()), AccountStatus.active);
      expect(accountStatusFromProto(AccountStatus.archived.toProto()), AccountStatus.archived);
    });
  });
}
