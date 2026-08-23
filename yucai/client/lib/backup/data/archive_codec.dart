import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Archive codec (R6 feature J, design ADR-1) — byte-compatible with the
/// server's backup encryption (backup/domain/crypto.go):
///   [magic "YC1E" 4B][salt 32B][nonce 12B][AES-256-GCM ciphertext + 16B tag]
/// with scrypt(N=32768, r=8, p=1) deriving a 32-byte key, and the plaintext
/// being the gzip-compressed envelope JSON (server Compress layer).
class ArchiveCodec {
  static const _magic = 'YC1E';
  static const _saltLen = 32;
  static const _nonceLen = 12;
  static const _keyLen = 32;
  static const _scryptN = 32768;
  static const _scryptR = 8;
  static const _scryptP = 1;

  /// Encrypts [plaintext] (raw envelope JSON bytes) with [password].
  static Uint8List encrypt(Uint8List plaintext, String password) {
    final salt = _randomBytes(_saltLen);
    final nonce = _randomBytes(_nonceLen);

    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final gzipped = gzip.encode(plaintext);
    final ct = cipher.process(Uint8List.fromList(gzipped));

    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.add(salt);
    out.add(nonce);
    out.add(ct);
    return out.toBytes();
  }

  /// Decrypts an archive produced by [encrypt] or by the Go server's
  /// domain.Encrypt. Throws NotArchiveError / WrongPasswordError /
  /// ArchiveFormatError with distinct, user-facing semantics.
  static Uint8List decrypt(Uint8List data, String password) {
    const headerLen = _magic.length + _saltLen + _nonceLen;
    if (data.length < headerLen + 16) {
      throw const NotArchiveError();
    }
    if (utf8.decode(data.sublist(0, 4), allowMalformed: true) != _magic) {
      throw const NotArchiveError();
    }
    final salt = data.sublist(4, 4 + _saltLen);
    final nonce = data.sublist(4 + _saltLen, headerLen);
    final ct = data.sublist(headerLen);

    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    Uint8List gzipped;
    try {
      gzipped = cipher.process(ct);
    } on ArgumentError {
      throw const WrongPasswordError();
    } on Exception {
      // pointycastle signals GCM tag mismatch via various exception shapes;
      // any failure here with correct framing means wrong password.
      throw const WrongPasswordError();
    }
    try {
      return Uint8List.fromList(gzip.decode(gzipped));
    } catch (_) {
      // GCM passed but gunzip failed — wrong password produced garbage that
      // coincidentally passed auth (practically impossible; treat as format).
      throw const ArchiveFormatError();
    }
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final scrypt = Scrypt()
      ..init(ScryptParameters(_scryptN, _scryptR, _scryptP, _keyLen, salt));
    return scrypt.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(n, (_) => rng.nextInt(256)));
  }
}

/// The file is not a yucai archive (bad magic / too short).
class NotArchiveError implements Exception {
  const NotArchiveError();
}

/// GCM authentication failed — wrong password (or corrupted ciphertext).
class WrongPasswordError implements Exception {
  const WrongPasswordError();
}

/// GCM passed but the inner layers (gzip / envelope) are unreadable.
class ArchiveFormatError implements Exception {
  const ArchiveFormatError();
}
