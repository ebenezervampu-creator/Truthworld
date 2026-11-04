import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter.dart';
import 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter_io.dart';
import 'package:truthworld/core/network/ssl_pinning_manager.dart';
import 'package:truthworld/core/security/biometric_security_service.dart';
import 'package:truthworld/core/services/local_playback_proxy.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';

import '../../test_helpers/mock_firebase.dart';

class _RealHttpOverrides extends HttpOverrides {}

class _MockSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data.containsKey(key);
  }
}

class _MockSslPinningAdapter implements SslPinningAdapter {
  final Map<String, bool> hostResponses = {};

  @override
  http.Client createPinnedClient() => http.Client();

  @override
  Future<bool> validateHostHandshake(String host, {int port = 443}) async {
    return hostResponses[host] ?? false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('TW-SEC-06: Local Playback Proxy DNS Rebinding & Token Isolation', () {
    late LocalPlaybackProxyServer proxy;
    late Directory tempDir;
    late File videoAFile;
    late File videoBFile;

    setUp(() async {
      proxy = LocalPlaybackProxyServer.instance;
      tempDir = Directory.systemTemp.createTempSync('proxy_sec_test_');

      // Create two sample encrypted media files
      final crypto = MediaCryptoService.instance;
      crypto.setExplicitKey(Uint8List.fromList(List.generate(32, (i) => i * 3 % 256)));

      final plainA = Uint8List.fromList(List.generate(2048, (i) => (i * 7) % 256));
      final rawA = File('${tempDir.path}/raw_a.mp4');
      await rawA.writeAsBytes(plainA);
      videoAFile = File('${tempDir.path}/a.twenc');
      await crypto.encryptFile(rawA, videoAFile);

      final plainB = Uint8List.fromList(List.generate(2048, (i) => (i * 11) % 256));
      final rawB = File('${tempDir.path}/raw_b.mp4');
      await rawB.writeAsBytes(plainB);
      videoBFile = File('${tempDir.path}/b.twenc');
      await crypto.encryptFile(rawB, videoBFile);
    });

    tearDown(() async {
      await proxy.stop();
      MediaCryptoService.instance.resetCachedKey();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('issues unique stream-scoped session tokens for different videos', () async {
      final urlA = await proxy.serveVideo('vid_alpha', videoAFile);
      final urlB = await proxy.serveVideo('vid_beta', videoBFile);

      final tokenA = Uri.parse(urlA).queryParameters['token'];
      final tokenB = Uri.parse(urlB).queryParameters['token'];

      expect(tokenA, isNotNull);
      expect(tokenB, isNotNull);
      expect(tokenA, isNotEmpty);
      expect(tokenB, isNotEmpty);
      expect(tokenA, isNot(equals(tokenB)), reason: 'Each stream must have an isolated, unique token');
    });

    test('rejects cross-stream token reuse with 403 Forbidden', () async {
      await proxy.serveVideo('vid_alpha', videoAFile);
      final urlB = await proxy.serveVideo('vid_beta', videoBFile);

      final tokenB = Uri.parse(urlB).queryParameters['token']!;

      // Attacker attempts to access video A using token from video B
      final spoofedUrl = 'http://127.0.0.1:${proxy.port}/stream/vid_alpha?token=$tokenB';
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(spoofedUrl));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.forbidden));
      client.close();
    });

    test('invalidates stream token upon unregisterVideo', () async {
      final urlA = await proxy.serveVideo('vid_alpha', videoAFile);

      // Access before unregistering succeeds
      final client = HttpClient();
      final req1 = await client.getUrl(Uri.parse(urlA));
      final resp1 = await req1.close();
      expect(resp1.statusCode, equals(HttpStatus.ok));

      // Dismiss / unregister video
      proxy.unregisterVideo('vid_alpha');

      // Access after unregistering fails with 403
      final req2 = await client.getUrl(Uri.parse(urlA));
      final resp2 = await req2.close();
      expect(resp2.statusCode, equals(HttpStatus.forbidden));
      client.close();
    });

    test('rejects requests bearing an Origin header to prevent browser DNS rebinding', () async {
      final urlA = await proxy.serveVideo('vid_alpha', videoAFile);

      final client = HttpClient();
      final socket = await Socket.connect('127.0.0.1', proxy.port!);

      // Construct raw HTTP request with an Origin header (as a malicious browser script would send)
      final uri = Uri.parse(urlA);
      final rawHttp = 'GET ${uri.path}?${uri.query} HTTP/1.1\r\n'
          'Host: 127.0.0.1:${proxy.port}\r\n'
          'Origin: http://evil-attacker.com\r\n'
          'Connection: close\r\n\r\n';

      socket.write(rawHttp);
      await socket.flush();

      final responseBytes = await socket.fold<List<int>>([], (p, e) => p..addAll(e));
      socket.destroy();
      client.close();

      final responseString = utf8.decode(responseBytes);
      expect(responseString, contains('403 Forbidden'));
      expect(responseString, contains('cross-origin requests forbidden'));
    });

    test('rejects mismatched or spoofed Host header to prevent DNS rebinding', () async {
      final urlA = await proxy.serveVideo('vid_alpha', videoAFile);

      final socket = await Socket.connect('127.0.0.1', proxy.port!);
      final uri = Uri.parse(urlA);

      // Malicious Host header pointing to attacker's rebinding domain
      final rawHttp = 'GET ${uri.path}?${uri.query} HTTP/1.1\r\n'
          'Host: attacker.rebind.network:${proxy.port}\r\n'
          'Connection: close\r\n\r\n';

      socket.write(rawHttp);
      await socket.flush();

      final responseBytes = await socket.fold<List<int>>([], (p, e) => p..addAll(e));
      socket.destroy();

      final responseString = utf8.decode(responseBytes);
      expect(responseString, contains('403 Forbidden'));
      expect(responseString, contains('invalid Host header'));
    });

    test('injects strict security response headers (nosniff & CORP same-origin)', () async {
      final urlA = await proxy.serveVideo('vid_alpha', videoAFile);

      final client = HttpClient();
      final req = await client.headUrl(Uri.parse(urlA));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.ok));
      expect(resp.headers.value('x-content-type-options'), equals('nosniff'));
      expect(resp.headers.value('cross-origin-resource-policy'), equals('same-origin'));
      client.close();
    });
  });

  group('TW-SEC-07: Media Crypto Service Persistent Encrypted Device Key Storage', () {
    late _MockSecureStorage mockSecureStorage;
    late GetStorage legacyStorage;
    const storageKey = 'tw_offline_device_crypto_key';

    setUp(() async {
      mockSecureStorage = _MockSecureStorage();
      legacyStorage = GetStorage();
      await legacyStorage.remove(storageKey);
      MediaCryptoService.instance.resetCachedKey();
      MediaCryptoService.instance.setSecureStorageForTesting(
        mockSecureStorage,
        legacyStorage: legacyStorage,
      );
    });

    tearDown(() async {
      await legacyStorage.remove(storageKey);
      MediaCryptoService.instance.resetCachedKey();
    });

    test('stores newly generated device keys in FlutterSecureStorage, never in GetStorage', () async {
      final key = await MediaCryptoService.instance.getOrCreateDeviceKey();

      expect(key.length, equals(32));

      // Verify key was persisted into FlutterSecureStorage
      final secureVal = await mockSecureStorage.read(key: storageKey);
      expect(secureVal, isNotNull);
      expect(base64Decode(secureVal!).length, equals(32));
      expect(base64Decode(secureVal), equals(key));

      // Verify GetStorage remains clean (Zero unencrypted keys)
      expect(legacyStorage.hasData(storageKey), isFalse);
    });

    test('transparently migrates pre-existing key from GetStorage to FlutterSecureStorage and deletes legacy record', () async {
      // Simulate legacy installation: key pre-existing in unencrypted GetStorage
      final legacyRawKey = Uint8List.fromList(List.generate(32, (i) => (i * 13 + 5) % 256));
      final legacyBase64 = base64Encode(legacyRawKey);
      await legacyStorage.write(storageKey, legacyBase64);

      expect(legacyStorage.hasData(storageKey), isTrue);
      expect(await mockSecureStorage.read(key: storageKey), isNull);

      // Trigger key retrieval (which must execute transparent migration)
      final retrievedKey = await MediaCryptoService.instance.getOrCreateDeviceKey();

      // 1. Returned key matches original legacy key
      expect(retrievedKey, equals(legacyRawKey));

      // 2. Key now securely persisted in FlutterSecureStorage
      final secureVal = await mockSecureStorage.read(key: storageKey);
      expect(secureVal, equals(legacyBase64));

      // 3. Key purged and deleted from unencrypted GetStorage
      expect(legacyStorage.hasData(storageKey), isFalse);
    });

    test('subsequent calls read directly from FlutterSecureStorage', () async {
      final initialKey = await MediaCryptoService.instance.getOrCreateDeviceKey();

      // Clear in-memory cache to force re-reading from storage
      MediaCryptoService.instance.resetCachedKey();

      final reloadedKey = await MediaCryptoService.instance.getOrCreateDeviceKey();
      expect(reloadedKey, equals(initialKey));
      expect(legacyStorage.hasData(storageKey), isFalse);
    });
  });

  group('TW-SEC-08: SSL Pinning Peer Certificate & Payment Endpoints Conjunction', () {
    late _MockSslPinningAdapter mockAdapter;

    setUp(() {
      mockAdapter = _MockSslPinningAdapter();
      SslPinningManager.instance.setAdapterForTesting(mockAdapter);
    });

    tearDown(SslPinningManager.instance.resetAdapter);

    test('validatePaymentEndpoints strictly enforces conjunction (&&) in production', () async {
      // Case 1: api.cashfree.com is valid, but payments.cashfree.com is failing / intercepted
      mockAdapter.hostResponses['api.cashfree.com'] = true;
      mockAdapter.hostResponses['payments.cashfree.com'] = false;
      mockAdapter.hostResponses['sandbox.cashfree.com'] = true; // sandbox valid, must NOT bypass production

      final result1 = await SslPinningManager.instance.validatePaymentEndpoints();
      expect(result1, isFalse, reason: 'Production payment validation must fail if payments.cashfree.com is not verified');

      // Case 2: api.cashfree.com is failing, but payments.cashfree.com is valid
      mockAdapter.hostResponses['api.cashfree.com'] = false;
      mockAdapter.hostResponses['payments.cashfree.com'] = true;

      final result2 = await SslPinningManager.instance.validatePaymentEndpoints();
      expect(result2, isFalse, reason: 'Production payment validation must fail if api.cashfree.com is not verified');

      // Case 3: Both production endpoints pass verification
      mockAdapter.hostResponses['api.cashfree.com'] = true;
      mockAdapter.hostResponses['payments.cashfree.com'] = true;

      final result3 = await SslPinningManager.instance.validatePaymentEndpoints();
      expect(result3, isTrue, reason: 'Production payment validation must pass only when BOTH endpoints pass');
    });

    test('validatePaymentEndpoints checks sandbox endpoint only when explicitly configured', () async {
      mockAdapter.hostResponses['api.cashfree.com'] = false;
      mockAdapter.hostResponses['payments.cashfree.com'] = false;
      mockAdapter.hostResponses['sandbox.cashfree.com'] = true;

      // When isSandbox = true, it validates sandbox.cashfree.com
      final sandboxResult = await SslPinningManager.instance.validatePaymentEndpoints(isSandbox: true);
      expect(sandboxResult, isTrue);

      // When isSandbox = false, the valid sandbox endpoint does NOT allow production bypass
      final prodResult = await SslPinningManager.instance.validatePaymentEndpoints();
      expect(prodResult, isFalse);
    });

    test('peer certificate fingerprint verification strictly verifies against trusted set', () {
      // Simulate untrusted certificate DER bytes (e.g. from an intercepting proxy)
      final untrustedDer = Uint8List.fromList([0x30, 0x82, 0x01, 0x0a, 0x02, 0x82]);
      final untrustedFingerprint = sha256.convert(untrustedDer).toString().toLowerCase();

      expect(
        SslPinningAdapterIo.trustedCertFingerprints.contains(untrustedFingerprint),
        isFalse,
        reason: 'Untrusted certificate fingerprint must never match trustedCertFingerprints',
      );

      // Authoritative DigiCert Root fingerprint matches trusted set
      const trustedDigiCert = '4348a0e9444c78cb265e058d5e8344b1b2dd7fa40b3a40fec78032ec02624974';
      expect(
        SslPinningAdapterIo.trustedCertFingerprints.contains(trustedDigiCert),
        isTrue,
      );
    });
  });

  group('TW-SEC-09: Biometric & Device Credential Security Fail-Closed Hardening', () {
    setUp(() {
      Get.reset();
      BiometricSecurityService.enableNativeAuth = false;
      BiometricSecurityService.mockAuthenticationResult = null;
    });

    tearDown(() {
      BiometricSecurityService.enableNativeAuth = true;
      BiometricSecurityService.mockAuthenticationResult = null;
    });

    test('authenticateForHighValueAction fails closed when native auth is unavailable', () async {
      final service = BiometricSecurityService.to;

      // Without fallbackAuth and without mock override, it MUST fail closed (false)
      final success = await service.authenticateForHighValueAction(
        reason: 'Confirm withdrawal',
        showFriendlyWarningOnFailure: false,
      );

      expect(success, isFalse, reason: 'Must fail closed; never allow compatibility pass-through');
    });

    test('authenticateForHighValueAction executes secondary fallbackAuth if provided', () async {
      final service = BiometricSecurityService.to;
      var fallbackCalled = false;

      final success = await service.authenticateForHighValueAction(
        reason: 'Confirm bank account update',
        showFriendlyWarningOnFailure: false,
        fallbackAuth: () async {
          fallbackCalled = true;
          return true;
        },
      );

      expect(fallbackCalled, isTrue);
      expect(success, isTrue);
    });

    test('authenticateForHighValueAction fails closed when secondary fallbackAuth fails or throws', () async {
      final service = BiometricSecurityService.to;

      // Fallback returns false
      final result1 = await service.authenticateForHighValueAction(
        reason: 'Confirm payout',
        showFriendlyWarningOnFailure: false,
        fallbackAuth: () async => false,
      );
      expect(result1, isFalse);

      // Fallback throws exception
      final result2 = await service.authenticateForHighValueAction(
        reason: 'Confirm payout',
        showFriendlyWarningOnFailure: false,
        fallbackAuth: () async => throw StateError('Secondary verification failed'),
      );
      expect(result2, isFalse);
    });

    test('isDeviceSupported and canCheckBiometrics fail closed when native auth is disabled', () async {
      final service = BiometricSecurityService.to;

      expect(await service.isDeviceSupported(), isFalse);
      expect(await service.canCheckBiometrics(), isFalse);
    });
  });
}
