import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/stream/ctr.dart';

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

  /// Retrieves or generates a 256-bit (32 bytes) encryption key bound to this device.
  Future<Uint8List> getOrCreateDeviceKey() async {
    if (_cachedDeviceKey != null) return _cachedDeviceKey!;

    try {
      final box = GetStorage();
      final storedKey = box.read<String>(_storageKey);
      if (storedKey != null && storedKey.isNotEmpty) {
        final keyBytes = base64Decode(storedKey);
        if (keyBytes.length == 32) {
          _cachedDeviceKey = keyBytes;
          return _cachedDeviceKey!;
        }
      }
    } catch (_) {}

    // Generate a secure 256-bit random key
    final random = Random.secure();
    final newKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      newKey[i] = random.nextInt(256);
    }

    try {
      final box = GetStorage();
      await box.write(_storageKey, base64Encode(newKey));
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
    final originalLength = byteData.getInt64(0);

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
    byteData.setInt64(0, originalLength);

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

    final cipher = CTRStreamCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), header.iv));

    final ciphertext = Uint8List.sublistView(encryptedData, headerSize);
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
      carry = (carry >> 8) + (sum >> 8);
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
