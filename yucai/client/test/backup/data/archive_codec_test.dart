// ArchiveCodec tests — round-trip and error taxonomy. Cross-language wire
// compatibility rests on the structural audit (codec framing mirrors
// server crypto.go exactly); a real Go-sample decrypt test is deferred
// until a fixture generator exists.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/backup/data/archive_codec.dart';

void main() {
  test('round-trip: decrypt(encrypt(x, p), p) == x', () {
    final plain =
        Uint8List.fromList(utf8.encode('{"version":1,"modules":{}}'));
    final sealed = ArchiveCodec.encrypt(plain, 'secret-pw');
    expect(utf8.decode(sealed.sublist(0, 4)), 'YC1E');
    // framing: 4+32+12 fixed + gzip(payload) + 16B GCM tag.
    expect(sealed.length, greaterThan(48 + 16));
    final back = ArchiveCodec.decrypt(sealed, 'secret-pw');
    expect(utf8.decode(back), utf8.decode(plain));
  });

  test('wrong password → WrongPasswordError, framing intact', () {
    final sealed = ArchiveCodec.encrypt(
        Uint8List.fromList(utf8.encode('data')), 'right');
    expect(() => ArchiveCodec.decrypt(sealed, 'wrong'),
        throwsA(isA<WrongPasswordError>()));
  });

  test('not an archive (bad magic / too short) → NotArchiveError', () {
    expect(() => ArchiveCodec.decrypt(Uint8List.fromList([1, 2, 3]), 'p'),
        throwsA(isA<NotArchiveError>()));
    final notMagic = Uint8List.fromList(utf8.encode('NOPE' * 20));
    expect(() => ArchiveCodec.decrypt(notMagic, 'p'),
        throwsA(isA<NotArchiveError>()));
  });

  test('wrong password produces distinct bytes (salt/nonce randomness)', () {
    final a = ArchiveCodec.encrypt(
        Uint8List.fromList(utf8.encode('x')), 'p');
    final b = ArchiveCodec.encrypt(
        Uint8List.fromList(utf8.encode('x')), 'p');
    expect(a.length, b.length);
    expect(a, isNot(b)); // random salt/nonce → different ciphertext
  });

  test('small-payload round-trip sanity', () {
  
    final sealed = ArchiveCodec.encrypt(
        Uint8List.fromList(utf8.encode('hello archive')), 'pw-test');
    final back = ArchiveCodec.decrypt(sealed, 'pw-test');
    expect(utf8.decode(back), 'hello archive');
  });
}
