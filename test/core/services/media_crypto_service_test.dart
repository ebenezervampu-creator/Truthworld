import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MediaCryptoService cryptoService;
  late Uint8List testKey;

  setUp(() {
    cryptoService = MediaCryptoService.instance;
    testKey = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
    cryptoService.setExplicitKey(testKey);
  });

  group('MediaCryptoService', () {
    test('Header building and parsing round-trip', () {
      final iv = Uint8List.fromList(List.generate(16, (i) => i));
      final digest = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      const originalLength = 123456789;

      final headerBytes = cryptoService.buildHeader(
        isAudio: true,
        iv: iv,
        originalLength: originalLength,
        sha256Digest: digest,
      );

      expect(headerBytes.length, MediaCryptoService.headerSize);
      expect(cryptoService.isEncryptedMedia(headerBytes), isTrue);

      final parsed = cryptoService.parseHeader(headerBytes);
      expect(parsed.isAudio, isTrue);
      expect(parsed.iv, iv);
      expect(parsed.originalLength, originalLength);
      expect(parsed.sha256Digest, digest);
    });

    test('Cross-platform 64-bit integer encoding and decoding (dart2js compatible)', () {
      final testLengths = [
        0,
        1,
        1024,
        65536,
        123456789,
        0xFFFFFFFF, // 4,294,967,295 (Max 32-bit unsigned)
        0x100000000, // 4,294,967,296 (2^32)
        5368709120, // ~5 GB
        10737418240, // ~10 GB
      ];

      for (final length in testLengths) {
        final buffer = Uint8List(8);
        final bd = ByteData.sublistView(buffer);
        MediaCryptoService.writeUint64BigEndian(bd, 0, length);
        final readBack = MediaCryptoService.readUint64BigEndian(bd, 0);
        expect(readBack, length, reason: 'Failed for length $length');
      }

      // Verify exact big-endian byte representation for 123456789 (0x075BCD15)
      final sampleBuffer = Uint8List(8);
      final sampleBd = ByteData.sublistView(sampleBuffer);
      MediaCryptoService.writeUint64BigEndian(sampleBd, 0, 123456789);
      expect(sampleBuffer, [0x00, 0x00, 0x00, 0x00, 0x07, 0x5B, 0xCD, 0x15]);

      // Verify exact big-endian byte representation for 5GB (0x140000000)
      final largeBuffer = Uint8List(8);
      final largeBd = ByteData.sublistView(largeBuffer);
      MediaCryptoService.writeUint64BigEndian(largeBd, 0, 5368709120);
      expect(largeBuffer, [0x00, 0x00, 0x00, 0x01, 0x40, 0x00, 0x00, 0x00]);
    });

    test('In-memory AES-256 CTR encrypt and decrypt round-trip', () async {
      final plaintext = Uint8List.fromList(
        List.generate(1024, (i) => (i * 13 + 7) % 256),
      );

      final encrypted = await cryptoService.encryptBytes(
        plaintext,
        keyOverride: testKey,
      );

      expect(cryptoService.isEncryptedMedia(encrypted), isTrue);
      expect(encrypted.length, plaintext.length + MediaCryptoService.headerSize);

      final decrypted = await cryptoService.decryptBytes(
        encrypted,
        keyOverride: testKey,
      );

      expect(decrypted, plaintext);
    });

    test('Random-access byte slice decryption matches exact offset', () async {
      // 5KB of test data
      final plaintext = Uint8List.fromList(
        List.generate(5120, (i) => (i * 31) % 256),
      );

      final encrypted = await cryptoService.encryptBytes(
        plaintext,
        keyOverride: testKey,
      );

      final header = cryptoService.parseHeader(encrypted);
      final ciphertext = Uint8List.sublistView(encrypted, MediaCryptoService.headerSize);

      // Test multiple arbitrary offsets and lengths (including non-16-byte-aligned)
      final testCases = [
        {'offset': 0, 'length': 100},
        {'offset': 15, 'length': 20},
        {'offset': 16, 'length': 64},
        {'offset': 17, 'length': 150},
        {'offset': 500, 'length': 1024},
        {'offset': 2047, 'length': 513},
        {'offset': 5000, 'length': 120},
      ];

      for (final tc in testCases) {
        final offset = tc['offset']!;
        final length = tc['length']!;

        final cipherSlice = Uint8List.sublistView(ciphertext, offset, offset + length);
        final decryptedSlice = await cryptoService.decryptRangeSlice(
          ciphertextSlice: cipherSlice,
          baseIv: header.iv,
          byteOffset: offset,
          length: length,
          keyOverride: testKey,
        );

        final expectedSlice = Uint8List.sublistView(plaintext, offset, offset + length);
        expect(decryptedSlice, expectedSlice, reason: 'Failed at offset $offset with length $length');
      }
    });

    test('File encryption and range decryption on disk', () async {
      final tempDir = Directory.systemTemp.createTempSync('tw_crypto_test_');
      try {
        final sourceFile = File('${tempDir.path}/sample.mp4');
        final encryptedFile = File('${tempDir.path}/sample.twenc');

        // Create 20KB test media file
        final testBytes = Uint8List.fromList(
          List.generate(20480, (i) => (i ^ 0xAA) % 256),
        );
        await sourceFile.writeAsBytes(testBytes);

        await cryptoService.encryptFile(sourceFile, encryptedFile);

        expect(await encryptedFile.exists(), isTrue);
        final encLength = await encryptedFile.length();
        expect(encLength, testBytes.length + MediaCryptoService.headerSize);

        // Read decrypted range from disk (e.g. byte 500 to 1500)
        final rangeBytes = await cryptoService.readDecryptedRange(
          encryptedFile,
          500,
          1500,
          keyOverride: testKey,
        );

        final expectedRange = Uint8List.sublistView(testBytes, 500, 1501);
        expect(rangeBytes, expectedRange);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
