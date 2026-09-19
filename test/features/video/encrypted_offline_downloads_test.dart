import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/local_playback_proxy.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/datasources/local/database_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Uint8List testVideoBytes;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tw_offline_db_test_');

    // Mock path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );

    MediaCryptoService.instance.setExplicitKey(
      Uint8List.fromList(List.generate(32, (i) => (i * 11) % 256)),
    );

    // Create 10KB mock MP4 bytes
    testVideoBytes = Uint8List.fromList(
      List.generate(10240, (i) => (i ^ 0x5C) % 256),
    );
  });

  tearDown(() async {
    await LocalPlaybackProxyServer.instance.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Encrypted Offline Downloads Database Helpers', () {
    test('Saves encrypted .twenc file and correctly verifies on-disk encryption', () async {
      final offlineVideo = OfflineVideo(
        id: 'test_vid_123',
        title: 'Encrypted Offline Test Video',
        channelName: 'Truthworld Tech',
        channelImage: 'https://example.com/avatar.jpg',
        views: '1.2K',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        downloadedAt: DateTime.now(),
      );

      final rawFile = File('${tempDir.path}/temp_raw.mp4');
      await rawFile.writeAsBytes(testVideoBytes);

      // Save via database helper
      await saveOfflineVideoFile('test_vid_123', rawFile, offlineVideo);

      // Verify offline video existence
      expect(await hasOfflineVideo('test_vid_123'), isTrue);

      // Verify the file stored on disk is encrypted
      final filePath = await getVideoFilePath('test_vid_123');
      expect(filePath, isNotNull);
      expect(filePath!.endsWith('.twenc'), isTrue);

      final onDiskFile = File(filePath);
      expect(await onDiskFile.exists(), isTrue);

      // Check that disk bytes start with 'TWENC\x01' magic header
      final diskBytes = await onDiskFile.readAsBytes();
      expect(MediaCryptoService.instance.isEncryptedMedia(diskBytes), isTrue);

      // Verify that disk bytes do NOT match raw plaintext
      expect(diskBytes.sublist(MediaCryptoService.headerSize), isNot(testVideoBytes));

      // Verify that getVideoBytes returns original decrypted plaintext
      final decryptedBytes = await getVideoBytes('test_vid_123');
      expect(decryptedBytes, testVideoBytes);

      // Verify getOfflinePlaybackUrl serves via local proxy
      final playbackUrl = await getOfflinePlaybackUrl('test_vid_123');
      expect(playbackUrl, isNotNull);
      expect(playbackUrl!.startsWith('http://127.0.0.1:'), isTrue);
      expect(playbackUrl.contains('/stream/test_vid_123?token='), isTrue);

      // Verify cleanup
      await deleteVideo('test_vid_123');
      expect(await hasOfflineVideo('test_vid_123'), isFalse);
      expect(await onDiskFile.exists(), isFalse);
    });
  });
}
