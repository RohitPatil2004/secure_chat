import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// End-to-End Encryption Service
/// Strategy:
///   - Each user has an RSA key pair (2048-bit) stored securely on device
///   - Public keys are stored on Firestore (visible to all)
///   - For each message, a random AES-256 key is generated
///   - The message is encrypted with AES-256-CBC
///   - The AES key is encrypted with the recipient's RSA public key (PKCS1)
///   - Both encrypted message + encrypted AES key are stored on Firestore
///
/// NOTE: PEM encoding/decoding is done with manual DER byte construction
/// to avoid asn1lib API incompatibilities across package versions.
class E2EEncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _privateKeyStorageKey = 'rsa_private_key';
  static const _publicKeyStorageKey = 'rsa_public_key';

  // ─── RSA Key Generation ───────────────────────────────────────────────────

  static Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>
      generateRSAKeyPair() async {
    final keyGen = RSAKeyGenerator();
    keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      _buildSecureRandom(),
    ));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  static Future<void> storeKeyPair(
      AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> keyPair) async {
    await _storage.write(
        key: _publicKeyStorageKey,
        value: encodePublicKeyToPem(keyPair.publicKey));
    await _storage.write(
        key: _privateKeyStorageKey,
        value: encodePrivateKeyToPem(keyPair.privateKey));
  }

  static Future<String?> getStoredPublicKeyPem() async =>
      _storage.read(key: _publicKeyStorageKey);

  static Future<RSAPrivateKey?> getStoredPrivateKey() async {
    final pem = await _storage.read(key: _privateKeyStorageKey);
    if (pem == null) return null;
    return decodePrivateKeyFromPem(pem);
  }

  // ─── Message Encryption ───────────────────────────────────────────────────

  static Map<String, String> encryptMessage(
      String plaintext, String recipientPublicKeyPem) {
    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final encryptedMessage = encrypter.encrypt(plaintext, iv: iv);
    final recipientPublicKey = decodePublicKeyFromPem(recipientPublicKeyPem);
    final encryptedKey = _rsaEncrypt(aesKey.bytes, recipientPublicKey);
    return {
      'encryptedMessage': encryptedMessage.base64,
      'encryptedKey': base64Encode(encryptedKey),
      'iv': iv.base64,
    };
  }

  static Future<String> decryptMessage(
    String encryptedMessage,
    String encryptedKey,
    String ivBase64,
  ) async {
    final privateKey = await getStoredPrivateKey();
    if (privateKey == null) throw Exception('Private key not found on device');
    final aesKeyBytes = _rsaDecrypt(base64Decode(encryptedKey), privateKey);
    final aesKey = enc.Key(Uint8List.fromList(aesKeyBytes));
    final iv = enc.IV.fromBase64(ivBase64);
    final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    return encrypter.decrypt(enc.Encrypted.fromBase64(encryptedMessage), iv: iv);
  }

  // ─── RSA Encrypt / Decrypt ────────────────────────────────────────────────

  static Uint8List _rsaEncrypt(List<int> data, RSAPublicKey publicKey) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return _processInBlocks(cipher, Uint8List.fromList(data));
  }

  static Uint8List _rsaDecrypt(Uint8List data, RSAPrivateKey privateKey) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return _processInBlocks(cipher, data);
  }

  static Uint8List _processInBlocks(
      AsymmetricBlockCipher engine, Uint8List input) {
    final output = <int>[];
    var offset = 0;
    while (offset < input.length) {
      final chunkSize = (offset + engine.inputBlockSize <= input.length)
          ? engine.inputBlockSize
          : input.length - offset;
      final outBuf = Uint8List(engine.outputBlockSize);
      final len = engine.processBlock(input, offset, chunkSize, outBuf, 0);
      output.addAll(outBuf.sublist(0, len));
      offset += chunkSize;
    }
    return Uint8List.fromList(output);
  }

  // ─── PEM Encoding (manual DER — no asn1lib dependency) ───────────────────

  /// Encode RSA public key → PKCS#8 SubjectPublicKeyInfo PEM
  static String encodePublicKeyToPem(RSAPublicKey key) {
    // RSAPublicKey inner SEQUENCE { modulus INTEGER, publicExponent INTEGER }
    final inner = _derSeq([
      _derInt(key.modulus!),
      _derInt(key.exponent!),
    ]);

    // SubjectPublicKeyInfo SEQUENCE {
    //   AlgorithmIdentifier SEQUENCE { OID rsaEncryption, NULL },
    //   BIT STRING { 0x00 || inner }
    // }
    final spki = _derSeq([
      _derSeq([_derOid([1, 2, 840, 113549, 1, 1, 1]), _derNull()]),
      _derBitStr(inner),
    ]);

    return _wrapPem('PUBLIC KEY', spki);
  }

  /// Encode RSA private key → PKCS#1 RSAPrivateKey PEM
  static String encodePrivateKeyToPem(RSAPrivateKey key) {
    final p = key.p!;
    final q = key.q!;
    final d = key.privateExponent!;

    final seq = _derSeq([
      _derInt(BigInt.zero),          // version = 0
      _derInt(key.modulus!),         // n
      _derInt(key.publicExponent!),  // e
      _derInt(d),                    // d
      _derInt(p),                    // p
      _derInt(q),                    // q
      _derInt(d % (p - BigInt.one)), // dp
      _derInt(d % (q - BigInt.one)), // dq
      _derInt(q.modInverse(p)),      // qInv
    ]);

    return _wrapPem('RSA PRIVATE KEY', seq);
  }

  // ─── PEM Decoding (manual DER — no asn1lib dependency) ───────────────────

  static RSAPublicKey decodePublicKeyFromPem(String pem) {
    final der = _unwrapPem(pem);
    var pos = 0;

    // Outer SEQUENCE
    var tlv = _tlv(der, pos);
    pos = tlv.vStart;

    // Skip AlgorithmIdentifier SEQUENCE
    tlv = _tlv(der, pos);
    pos = tlv.vStart + tlv.vLen;

    // BIT STRING — skip tag+length+unused-bits byte (0x00)
    tlv = _tlv(der, pos);
    final innerDer = der.sublist(tlv.vStart + 1, tlv.vStart + tlv.vLen);

    // Inner SEQUENCE
    var iPos = 0;
    tlv = _tlv(innerDer, iPos);
    iPos = tlv.vStart;

    // modulus
    tlv = _tlv(innerDer, iPos);
    final modulus = _bigInt(innerDer, tlv.vStart, tlv.vLen);
    iPos = tlv.vStart + tlv.vLen;

    // publicExponent
    tlv = _tlv(innerDer, iPos);
    final exponent = _bigInt(innerDer, tlv.vStart, tlv.vLen);

    return RSAPublicKey(modulus, exponent);
  }

  static RSAPrivateKey decodePrivateKeyFromPem(String pem) {
    final der = _unwrapPem(pem);
    var pos = 0;

    // Outer SEQUENCE
    var tlv = _tlv(der, pos);
    pos = tlv.vStart;

    // Helper: read next INTEGER and advance pos
    BigInt nextInt() {
      tlv = _tlv(der, pos);
      final val = _bigInt(der, tlv.vStart, tlv.vLen);
      pos = tlv.vStart + tlv.vLen;
      return val;
    }

    nextInt(); // version (skip)
    final n = nextInt();
    nextInt(); // e  (skip)
    final d = nextInt();
    final p = nextInt();
    final q = nextInt();

    return RSAPrivateKey(n, d, p, q);
  }

  // ─── DER Builders ────────────────────────────────────────────────────────

  static Uint8List _derSeq(List<Uint8List> children) {
    final body = Uint8List.fromList(children.expand((e) => e).toList());
    return Uint8List.fromList([0x30, ..._lenBytes(body.length), ...body]);
  }

  static Uint8List _derInt(BigInt value) {
    var bytes = _bigIntBytes(value);
    // Prepend 0x00 if high bit is set (DER sign convention)
    if (bytes[0] & 0x80 != 0) bytes = Uint8List.fromList([0x00, ...bytes]);
    return Uint8List.fromList([0x02, ..._lenBytes(bytes.length), ...bytes]);
  }

  static Uint8List _derBitStr(Uint8List content) {
    // 0x00 = number of unused bits in last byte
    final body = Uint8List.fromList([0x00, ...content]);
    return Uint8List.fromList([0x03, ..._lenBytes(body.length), ...body]);
  }

  static Uint8List _derNull() => Uint8List.fromList([0x05, 0x00]);

  static Uint8List _derOid(List<int> components) {
    final body = <int>[
      // First two arcs are combined: 40*c0 + c1
      ..._base128(components[0] * 40 + components[1]),
      for (var i = 2; i < components.length; i++) ..._base128(components[i]),
    ];
    return Uint8List.fromList([0x06, ..._lenBytes(body.length), ...body]);
  }

  static List<int> _base128(int v) {
    if (v == 0) return [0];
    final bytes = <int>[];
    while (v > 0) {
      bytes.insert(0, v & 0x7f);
      v >>= 7;
    }
    for (var i = 0; i < bytes.length - 1; i++) bytes[i] |= 0x80;
    return bytes;
  }

  static List<int> _lenBytes(int len) {
    if (len < 128) return [len];
    final octets = <int>[];
    var v = len;
    while (v > 0) {
      octets.insert(0, v & 0xff);
      v >>= 8;
    }
    return [0x80 | octets.length, ...octets];
  }

  // ─── DER Parser ──────────────────────────────────────────────────────────

  static _TLV _tlv(Uint8List data, int offset) {
    int pos = offset + 1; // skip tag byte
    int len;
    if (data[pos] & 0x80 == 0) {
      len = data[pos];
      pos++;
    } else {
      final n = data[pos] & 0x7f;
      pos++;
      len = 0;
      for (var i = 0; i < n; i++) len = (len << 8) | data[pos++];
    }
    return _TLV(tag: data[offset], vStart: pos, vLen: len);
  }

  // ─── BigInt ───────────────────────────────────────────────────────────────

  static Uint8List _bigIntBytes(BigInt n) {
    if (n == BigInt.zero) return Uint8List.fromList([0]);
    var hex = n.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    return Uint8List.fromList(List.generate(
        hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  static BigInt _bigInt(Uint8List data, int start, int len) {
    BigInt result = BigInt.zero;
    for (var i = start; i < start + len; i++) {
      result = (result << 8) | BigInt.from(data[i]);
    }
    return result;
  }

  // ─── PEM Wrap / Unwrap ───────────────────────────────────────────────────

  static String _wrapPem(String label, Uint8List der) {
    final b64 = base64.encode(der);
    final sb = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < b64.length; i += 64) {
      sb.writeln(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    sb.write('-----END $label-----');
    return sb.toString();
  }

  static Uint8List _unwrapPem(String pem) {
    final b64 = pem
        .split('\n')
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join('');
    return base64.decode(b64);
  }

  // ─── Secure Random ───────────────────────────────────────────────────────

  static SecureRandom _buildSecureRandom() {
    final rng = FortunaRandom();
    rng.seed(KeyParameter(
        Uint8List.fromList(
            List.generate(32, (_) => Random.secure().nextInt(256)))));
    return rng;
  }
}

/// Internal DER TLV structure
class _TLV {
  final int tag;
  final int vStart;  // offset where value bytes begin
  final int vLen;    // length of value in bytes
  const _TLV({required this.tag, required this.vStart, required this.vLen});
}