import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/local_playback_proxy.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late LocalPlaybackProxyServer proxyServer;
  late MediaCryptoService cryptoService;
  late Directory tempDir;
  late File sampleEncryptedFile;
  late Uint8List originalPlaintext;

  setUp(() async {
    proxyServer = LocalPlaybackProxyServer.instance;
    cryptoService = MediaCryptoService.instance;
    cryptoService.setExplicitKey(Uint8List.fromList(List.generate(32, (i) => i * 3 % 256)));

    tempDir = Directory.systemTemp.createTempSync('tw_proxy_test_');

    // Create 100KB test media content
    originalPlaintext = Uint8List.fromList(
      List.generate(102400, (i) => (i * 17 + 3) % 256),
    );

    final rawFile = File('${tempDir.path}/raw_sample.mp4');
    await rawFile.writeAsBytes(originalPlaintext);

    sampleEncryptedFile = File('${tempDir.path}/sample.twenc');
    await cryptoService.encryptFile(rawFile, sampleEncryptedFile);
  });

  tearDown(() async {
    await proxyServer.stop();
    tempDir.deleteSync(recursive: true);
  });

  group('LocalPlaybackProxyServer', () {
    test('Serves encrypted file with Range request and decodes plaintext on-the-fly', () async {
      final streamUrl = await proxyServer.serveVideo('test_video_1', sampleEncryptedFile);

      expect(proxyServer.isRunning, isTrue);
      expect(streamUrl.startsWith('http://127.0.0.1:'), isTrue);

      final client = HttpClient();

      // 1. Test HEAD request
      final headReq = await client.headUrl(Uri.parse(streamUrl));
      final headResp = await headReq.close();
      expect(headResp.statusCode, HttpStatus.ok);
      expect(headResp.headers.value('accept-ranges'), 'bytes');
      expect(headResp.headers.value('content-length'), originalPlaintext.length.toString());
      expect(headResp.headers.value('content-type'), 'video/mp4');

      // 2. Test Range request: bytes 0-1023
      final rangeReq = await client.getUrl(Uri.parse(streamUrl));
      rangeReq.headers.add('Range', 'bytes=0-1023');
      final rangeResp = await rangeReq.close();

      expect(rangeResp.statusCode, HttpStatus.partialContent);
      expect(rangeResp.headers.value('content-range'), 'bytes 0-1023/${originalPlaintext.length}');
      expect(rangeResp.headers.value('content-length'), '1024');

      final rangeBytes = await rangeResp.fold<List<int>>([], (p, e) => p..addAll(e));
      expect(Uint8List.fromList(rangeBytes), Uint8List.sublistView(originalPlaintext, 0, 1024));

      // 3. Test arbitrary seek: bytes 50000-60000
      final seekReq = await client.getUrl(Uri.parse(streamUrl));
      seekReq.headers.add('Range', 'bytes=50000-60000');
      final seekResp = await seekReq.close();

      expect(seekResp.statusCode, HttpStatus.partialContent);
      expect(seekResp.headers.value('content-range'), 'bytes 50000-60000/${originalPlaintext.length}');
      final seekBytes = await seekResp.fold<List<int>>([], (p, e) => p..addAll(e));
      expect(Uint8List.fromList(seekBytes), Uint8List.sublistView(originalPlaintext, 50000, 60001));

      client.close();
    });

    test('Rejects requests without valid session token', () async {
      await proxyServer.serveVideo('test_video_2', sampleEncryptedFile);

      final invalidUrl = 'http://127.0.0.1:${proxyServer.port}/stream/test_video_2?token=wrong_token';
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(invalidUrl));
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.forbidden);
      client.close();
    });
  });
}
