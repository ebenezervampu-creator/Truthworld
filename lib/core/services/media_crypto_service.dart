import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/stream/ctr.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// 🔐 MEDIA CRYPTO SERVICE (AES-256-CTR)
///
/// Provides enterprise-grade cryptographic protection for Truthworld offline media.
/// Uses AES-256 in CTR (Counter) mode, allowing O(1) random byte-offset seeking
/// for video streaming without decrypting the entire file beforehand.
class MediaCryptoService {
  MediaCryptoService._();
  static final MediaCryptoService instance = MediaCryptoService._();

  /// Magic bytes identifying Truthworld Encrypted Media: 'TWENC\x01'
  static const List<int> magicHeader = [0x54, 0x57, 0x45, 0x4E, 0x43, 0x01];

  /// Total header size in bytes:
  /// - Magic: 6 bytes
  /// - Media type: 1 byte (0 = video/mp4, 1 = audio/mp3)
  /// - IV (128-bit): 16 bytes
  /// - Original content size (Int64): 8 bytes
  /// - SHA-256 digest: 32 bytes
  /// - Reserved / padding: 2 bytes
  /// Total = 65 bytes
  static const int headerSize = 65;

  static const String _storageKey = 'tw_offline_device_crypto_key';
  Uint8List? _cachedDeviceKey;

  FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  GetStorage? _legacyStorage;

  @visibleForTesting
  void setSecureStorageForTesting(FlutterSecureStorage storage, {GetStorage? legacyStorage}) {
    _secureStorage = storage;
    _legacyStorage = legacyStorage;
    _cachedDeviceKey = null;
  }

  @visibleForTesting
  void resetCachedKey() {
    _cachedDeviceKey = null;
  }

  /// Retrieves or generates a 256-bit (32 bytes) encryption key bound to this device.
  ///
  /// Device keys are stored in encrypted hardware-backed secure storage via [FlutterSecureStorage].
  /// Transparently migrates any legacy unencrypted keys from [GetStorage] into [FlutterSecureStorage]
  /// and purges the legacy record.
  Future<Uint8List> getOrCreateDeviceKey() async {
    if (_cachedDeviceKey != null) return _cachedDeviceKey!;

    // 1. Check hardware-backed secure storage for existing key
    try {
      final secureKey = await _secureStorage.read(key: _storageKey);
      if (secureKey != null && secureKey.isNotEmpty) {
        final keyBytes = base64Decode(secureKey);
        if (keyBytes.length == 32) {
          _cachedDeviceKey = keyBytes;

          // Clean up legacy GetStorage key if it lingers
          try {
            final box = _legacyStorage ?? GetStorage();
            if (box.hasData(_storageKey)) {
              await box.remove(_storageKey);
            }
          } catch (_) {}

          return _cachedDeviceKey!;
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'MediaCryptoService.getOrCreateDeviceKey.secureRead',
      );
    }

    // 2. Transparent migration: check if key exists in legacy GetStorage
    try {
      final box = _legacyStorage ?? GetStorage();
      final legacyKey = box.read<String>(_storageKey);
      if (legacyKey != null && legacyKey.isNotEmpty) {
        final keyBytes = base64Decode(legacyKey);
        if (keyBytes.length == 32) {
          // Save into FlutterSecureStorage
          await _secureStorage.write(key: _storageKey, value: legacyKey);
          // Delete from unencrypted GetStorage
          await box.remove(_storageKey);

          _cachedDeviceKey = keyBytes;
          return _cachedDeviceKey!;
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'MediaCryptoService.getOrCreateDeviceKey.migration',
      );
    }

    // 3. Generate a secure 256-bit random key
    final random = Random.secure();
    final newKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      newKey[i] = random.nextInt(256);
    }
    final encodedKey = base64Encode(newKey);

    // 4. Persist newly generated key into FlutterSecureStorage
    try {
      await _secureStorage.write(key: _storageKey, value: encodedKey);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'MediaCryptoService.getOrCreateDeviceKey.secureWrite',
      );
    }

    // Ensure legacy GetStorage is wiped clean
    try {
      final box = _legacyStorage ?? GetStorage();
      if (box.hasData(_storageKey)) {
        await box.remove(_storageKey);
      }
    } catch (_) {}

    _cachedDeviceKey = newKey;
    return _cachedDeviceKey!;
  }

  /// Sets an explicit key (useful for unit tests or cross-device restoration)
  void setExplicitKey(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('Key must be exactly 32 bytes (256-bit)');
    }
    _cachedDeviceKey = Uint8List.fromList(key);
  }

  /// Checks whether a byte buffer begins with the Truthworld encrypted header.
  bool isEncryptedMedia(List<int> bytes) {
    if (bytes.length < magicHeader.length) return false;
    for (var i = 0; i < magicHeader.length; i++) {
      if (bytes[i] != magicHeader[i]) return false;
    }
    return true;
  }

  /// Safely writes a 64-bit big-endian unsigned integer across both native VM and
  /// web runtimes (dart2js / DDC / Wasm) without triggering
  /// "Unsupported operation: Int64 accessor not supported by dart2js".
  static void writeUint64BigEndian(ByteData byteData, int offset, int value) {
    const twoPow32 = 4294967296; // 2^32
    final high = value ~/ twoPow32;
    final low = value % twoPow32;
    byteData.setUint32(offset, high);
    byteData.setUint32(offset + 4, low);
  }

  /// Safely reads a 64-bit big-endian unsigned integer across both native VM and
  /// web runtimes (dart2js / DDC / Wasm) without triggering
  /// "Unsupported operation: Int64 accessor not supported by dart2js".
  static int readUint64BigEndian(ByteData byteData, int offset) {
    const twoPow32 = 4294967296; // 2^32
    final high = byteData.getUint32(offset);
    final low = byteData.getUint32(offset + 4);
    return (high * twoPow32) + low;
  }

  /// Parses header information from an encrypted media file or byte buffer.
  EncryptedMediaHeader parseHeader(List<int> bytes) {
    if (bytes.length < headerSize) {
      throw const FormatException('Encrypted media data is too short for header');
    }
    if (!isEncryptedMedia(bytes)) {
      throw const FormatException('Data does not contain a valid TWENC header');
    }

    final isAudio = bytes[6] == 1;
    final iv = Uint8List.fromList(bytes.sublist(7, 23));

    final byteData = ByteData.sublistView(Uint8List.fromList(bytes.sublist(23, 31)));
    final originalLength = readUint64BigEndian(byteData, 0);

    final sha256Digest = Uint8List.fromList(bytes.sublist(31, 63));

    return EncryptedMediaHeader(
      isAudio: isAudio,
      iv: iv,
      originalLength: originalLength,
      sha256Digest: sha256Digest,
    );
  }

  /// Builds a 65-byte encrypted header.
  Uint8List buildHeader({
    required bool isAudio,
    required Uint8List iv,
    required int originalLength,
    required Uint8List sha256Digest,
  }) {
    if (iv.length != 16) {
      throw ArgumentError('IV must be exactly 16 bytes');
    }
    if (sha256Digest.length != 32) {
      throw ArgumentError('Digest must be 32 bytes');
    }

    final header = Uint8List(headerSize);
    header.setRange(0, 6, magicHeader);
    header[6] = isAudio ? 1 : 0;
    header.setRange(7, 23, iv);

    final byteData = ByteData.sublistView(header, 23, 31);
    writeUint64BigEndian(byteData, 0, originalLength);

    header.setRange(31, 63, sha256Digest);
    // bytes 63-64 are 0x00 reserved
    return header;
  }

  /// Encrypts an in-memory byte buffer with AES-256 CTR and prepends the TWENC header.
  Future<Uint8List> encryptBytes(
    Uint8List plaintext, {
    bool isAudio = false,
    Uint8List? keyOverride,
  }) async {
    final key = keyOverride ?? await getOrCreateDeviceKey();
    final random = Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    final digest = Uint8List.fromList(crypto.sha256.convert(plaintext).bytes);
    final header = buildHeader(
      isAudio: isAudio,
      iv: iv,
      originalLength: plaintext.length,
      sha256Digest: digest,
    );

    if (plaintext.length >= 65536) {
      return compute(
        _encryptBytesWorker,
        _EncryptTaskParams(
          plaintext: plaintext,
          key: key,
          iv: iv,
          header: header,
        ),
      );
    }

    final cipher = CTRStreamCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));

    final ciphertext = Uint8List(plaintext.length);
    cipher.processBytes(plaintext, 0, plaintext.length, ciphertext, 0);

    final result = Uint8List(headerSize + ciphertext.length);
    result.setRange(0, headerSize, header);
    result.setRange(headerSize, result.length, ciphertext);
    return result;
  }

  /// Decrypts an in-memory TWENC encrypted byte buffer.
  Future<Uint8List> decryptBytes(
    Uint8List encryptedData, {
    Uint8List? keyOverride,
    bool verifyChecksum = true,
  }) async {
    final header = parseHeader(encryptedData);
    final key = keyOverride ?? await getOrCreateDeviceKey();
    final ciphertext = Uint8List.sublistView(encryptedData, headerSize);

    if (ciphertext.length >= 65536) {
      return compute(
        _decryptBytesWorker,
        _DecryptTaskParams(
          ciphertext: ciphertext,
          key: key,
          iv: header.iv,
          originalLength: header.originalLength,
          expectedDigest: header.sha256Digest,
          verifyChecksum: verifyChecksum,
        ),
      );
    }

    final cipher = CTRStreamCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), header.iv));

    final plaintext = Uint8List(ciphertext.length);
    cipher.processBytes(ciphertext, 0, ciphertext.length, plaintext, 0);

    // Truncate to original length if needed
    final result = (plaintext.length > header.originalLength)
        ? Uint8List.sublistView(plaintext, 0, header.originalLength)
        : plaintext;

    if (verifyChecksum) {
      final actualDigest = crypto.sha256.convert(result).bytes;
      if (!listEquals(actualDigest, header.sha256Digest)) {
        throw const FormatException('Decrypted media checksum verification failed (tampered or corrupted)');
      }
    }

    return result;
  }

  /// Increments a 128-bit big-endian counter by [blocksToAdd].
  static Uint8List addBlocksToIv(Uint8List baseIv, int blocksToAdd) {
    final counter = Uint8List.fromList(baseIv);
    var carry = blocksToAdd;
    for (var i = 15; i >= 0 && carry > 0; i--) {
      final sum = counter[i] + (carry & 0xFF);
      counter[i] = sum & 0xFF;
      carry = (carry ~/ 256) + (sum >> 8);
    }
    return counter;
  }

  /// Decrypts an arbitrary slice of ciphertext starting at [byteOffset] for [length] bytes.
  /// This is the core engine for HTTP Range streaming ($O(1)$ random seek).
  Future<Uint8List> decryptRangeSlice({
    required Uint8List ciphertextSlice,
    required Uint8List baseIv,
    required int byteOffset,
    required int length,
    Uint8List? keyOverride,
  }) async {
    final key = keyOverride ?? await getOrCreateDeviceKey();

    final blockIndex = byteOffset ~/ 16;
    final offsetInBlock = byteOffset % 16;

    final blockIv = addBlocksToIv(baseIv, blockIndex);

    final cipher = CTRStreamCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), blockIv));

    // Pad buffer to block alignment if offsetInBlock > 0
    final inputLen = offsetInBlock + length;
    final alignedInput = Uint8List(inputLen);
    alignedInput.setRange(offsetInBlock, inputLen, ciphertextSlice.take(length));

    final alignedOutput = Uint8List(inputLen);
    cipher.processBytes(alignedInput, 0, inputLen, alignedOutput, 0);

    return Uint8List.sublistView(alignedOutput, offsetInBlock, offsetInBlock + length);
  }

  /// Streams an unencrypted file from disk, encrypts it on-the-fly, and writes to [destFile].
  Future<void> encryptFile(
    File sourceFile,
    File destFile, {
    bool isAudio = false,
    Function(double progress)? onProgress,
  }) async {
    final totalBytes = await sourceFile.length();
    final key = await getOrCreateDeviceKey();

    final random = Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    // Compute SHA-256 of the source file
    final sourceDigest = await crypto.sha256.bind(sourceFile.openRead()).first;
    final header = buildHeader(
      isAudio: isAudio,
      iv: iv,
      originalLength: totalBytes,
      sha256Digest: Uint8List.fromList(sourceDigest.bytes),
    );

    final cipher = CTRStreamCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));

    final sink = destFile.openWrite();
    sink.add(header);

    var processed = 0;
    await for (final chunk in sourceFile.openRead()) {
      final inputBytes = Uint8List.fromList(chunk);
      final outBytes = Uint8List(inputBytes.length);
      cipher.processBytes(inputBytes, 0, inputBytes.length, outBytes, 0);
      sink.add(outBytes);

      processed += inputBytes.length;
      if (totalBytes > 0) {
        onProgress?.call((processed / totalBytes).clamp(0.0, 1.0));
      }
    }

    await sink.flush();
    await sink.close();
  }

  /// Reads and decrypts an arbitrary byte range from a `.twenc` file on disk.
  /// [start] and [end] are offsets in the *original plaintext file* (0-indexed, inclusive).
  Future<Uint8List> readDecryptedRange(
    File encryptedFile,
    int start,
    int end, {
    Uint8List? keyOverride,
  }) async {
    final raf = await encryptedFile.open();
    try {
      final headerBytes = await raf.read(headerSize);
      final header = parseHeader(headerBytes);

      final clampedStart = start.clamp(0, header.originalLength - 1);
      final clampedEnd = end.clamp(clampedStart, header.originalLength - 1);
      final requestedLength = (clampedEnd - clampedStart) + 1;

      if (requestedLength <= 0) return Uint8List(0);

      // Seek to the ciphertext position (headerSize + clampedStart)
      await raf.setPosition(headerSize + clampedStart);
      final ciphertextSlice = await raf.read(requestedLength);

      return await decryptRangeSlice(
        ciphertextSlice: ciphertextSlice,
        baseIv: header.iv,
        byteOffset: clampedStart,
        length: requestedLength,
        keyOverride: keyOverride,
      );
    } finally {
      await raf.close();
    }
  }
}

/// Metadata header stored at the beginning of each `.twenc` file.
class EncryptedMediaHeader {
  const EncryptedMediaHeader({
    required this.isAudio,
    required this.iv,
    required this.originalLength,
    required this.sha256Digest,
  });

  final bool isAudio;
  final Uint8List iv;
  final int originalLength;
  final Uint8List sha256Digest;
}

class _EncryptTaskParams {
  const _EncryptTaskParams({
    required this.plaintext,
    required this.key,
    required this.iv,
    required this.header,
  });

  final Uint8List plaintext;
  final Uint8List key;
  final Uint8List iv;
  final Uint8List header;
}

Uint8List _encryptBytesWorker(_EncryptTaskParams params) {
  final cipher = CTRStreamCipher(AESEngine());
  cipher.init(true, ParametersWithIV(KeyParameter(params.key), params.iv));

  final ciphertext = Uint8List(params.plaintext.length);
  cipher.processBytes(params.plaintext, 0, params.plaintext.length, ciphertext, 0);

  final result = Uint8List(MediaCryptoService.headerSize + ciphertext.length);
  result.setRange(0, MediaCryptoService.headerSize, params.header);
  result.setRange(MediaCryptoService.headerSize, result.length, ciphertext);
  return result;
}

class _DecryptTaskParams {
  const _DecryptTaskParams({
    required this.ciphertext,
    required this.key,
    required this.iv,
    required this.originalLength,
    required this.expectedDigest,
    required this.verifyChecksum,
  });

  final Uint8List ciphertext;
  final Uint8List key;
  final Uint8List iv;
  final int originalLength;
  final Uint8List expectedDigest;
  final bool verifyChecksum;
}

Uint8List _decryptBytesWorker(_DecryptTaskParams params) {
  final cipher = CTRStreamCipher(AESEngine());
  cipher.init(false, ParametersWithIV(KeyParameter(params.key), params.iv));

  final plaintext = Uint8List(params.ciphertext.length);
  cipher.processBytes(params.ciphertext, 0, params.ciphertext.length, plaintext, 0);

  final result = (plaintext.length > params.originalLength)
      ? Uint8List.sublistView(plaintext, 0, params.originalLength)
      : plaintext;

  if (params.verifyChecksum) {
    final actualDigest = crypto.sha256.convert(result).bytes;
    if (!listEquals(actualDigest, params.expectedDigest)) {
      throw const FormatException('Decrypted media checksum verification failed (tampered or corrupted)');
    }
  }

  return result;
}

