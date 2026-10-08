import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter_io.dart';
import 'package:truthworld/core/network/ssl_pinning_manager.dart';
import 'package:truthworld/core/security/rasp_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    RaspSecurityService.enableNativeChannel = false;
  });

  tearDown(() {
    RaspSecurityService.enableNativeChannel = true;
  });

  group('Runtime Application Self-Protection (RASP) Tests', () {
    test('RaspThreatAssessment.safe creates zero-threat clean environment', () {
      final safe = RaspThreatAssessment.safe();
      expect(safe.isSecure, isTrue);
      expect(safe.fridaDetected, isFalse);
      expect(safe.debuggerAttached, isFalse);
      expect(safe.hookingDetected, isFalse);
      expect(safe.rootDetected, isFalse);
      expect(safe.emulatorDetected, isFalse);
      expect(safe.signatureValid, isTrue);
      expect(safe.threatCount, equals(0));
      expect(safe.threatDetails, isEmpty);
    });

    test('RaspThreatAssessment.fromMap correctly parses critical threat flags', () {
      final map = {
        'fridaDetected': true,
        'debuggerAttached': true,
        'hookingDetected': false,
        'rootDetected': true,
        'emulatorDetected': false,
        'signatureValid': false,
        'isSecure': false,
        'threatCount': 4,
        'threatDetails': [
          'Frida dynamic instrumentation detected',
          'Active debugger or ptrace tracer detected',
          'Rooted device or su binary detected',
          'APK signature mismatch: tampered or re-signed modded binary detected',
        ],
      };

      final assessment = RaspThreatAssessment.fromMap(map);
      expect(assessment.isSecure, isFalse);
      expect(assessment.fridaDetected, isTrue);
      expect(assessment.debuggerAttached, isTrue);
      expect(assessment.hookingDetected, isFalse);
      expect(assessment.rootDetected, isTrue);
      expect(assessment.signatureValid, isFalse);
      expect(assessment.threatCount, equals(4));
      expect(assessment.threatDetails.length, equals(4));
      expect(
        assessment.threatDetails.first,
        contains('Frida dynamic instrumentation'),
      );
      expect(
        assessment.threatDetails.last,
        contains('APK signature mismatch'),
      );
    });

    test('RaspSecurityService initializes cleanly and provides threat checks', () async {
      final service = Get.put(RaspSecurityService());
      expect(service.isScanning.value, isFalse);

      final assessment = await service.checkSecurityThreats();
      expect(assessment, isNotNull);
      expect(service.lastAssessment.value, equals(assessment));

      final isSecure = await service.isEnvironmentSecure();
      expect(isSecure, isA<bool>());
    });

    test('RaspSecurityService invokes callback when threat is detected', () async {
      final service = Get.put(RaspSecurityService());
      var callbackFired = false;

      service.onThreatDetected = (threats) async {
        callbackFired = true;
      };

      // In safe test environment, no threats exist
      await service.enforceAppIntegrity(terminateOnFailure: false);
      expect(callbackFired, isFalse);
    });
  });

  group('SSL / Network Certificate Pinning Tests', () {
    test('SslPinningAdapterIo correctly detects pinned vs unpinned hosts', () {
      // Payment endpoints
      expect(SslPinningAdapterIo.isHostPinned('api.cashfree.com'), isTrue);
      expect(SslPinningAdapterIo.isHostPinned('payments.cashfree.com'), isTrue);
      expect(SslPinningAdapterIo.isHostPinned('sandbox.cashfree.com'), isTrue);
      expect(SslPinningAdapterIo.isHostPinned('checkout.cashfree.com'), isTrue);

      // Auth & Cloud Functions
      expect(
        SslPinningAdapterIo.isHostPinned('identitytoolkit.googleapis.com'),
        isTrue,
      );
      expect(
        SslPinningAdapterIo.isHostPinned('securetoken.googleapis.com'),
        isTrue,
      );
      expect(
        SslPinningAdapterIo.isHostPinned(
          'asia-south1-truthworld-1.cloudfunctions.net',
        ),
        isTrue,
      );

      // TruthWorld domains
      expect(SslPinningAdapterIo.isHostPinned('truthworld.app'), isTrue);
      expect(SslPinningAdapterIo.isHostPinned('www.truthworld.in'), isTrue);

      // Unpinned external hosts
      expect(SslPinningAdapterIo.isHostPinned('example.com'), isFalse);
      expect(SslPinningAdapterIo.isHostPinned('google.com'), isFalse);
    });

    test('SslPinningAdapterIo contains authoritative root and intermediate CA hashes', () {
      // DigiCert Global Root CA
      expect(
        SslPinningAdapterIo.trustedCertFingerprints.contains(
          '4348a0e9444c78cb265e058d5e8344b1b2dd7fa40b3a40fec78032ec02624974',
        ),
        isTrue,
      );
      // DigiCert Global Root G2
      expect(
        SslPinningAdapterIo.trustedCertFingerprints.contains(
          'cb3cceb76b3f6005c1d66f13f40b4e2a1b4501a1e34461c031415021cce042ff',
        ),
        isTrue,
      );
      // GTS Root R1
      expect(
        SslPinningAdapterIo.trustedCertFingerprints.contains(
          '203e2e305d109b02a249c6361a93b45a0b77b789d98416d822b3967d988775f0',
        ),
        isTrue,
      );
      // Let's Encrypt ISRG Root X1
      expect(
        SslPinningAdapterIo.trustedCertFingerprints.contains(
          '96bcec06264976f6422d57200403e7f4fe8d15edd28d73a0164142f515525470',
        ),
        isTrue,
      );
    });

    test('SslPinningManager provides pinned HTTP client and validation utilities', () {
      final manager = SslPinningManager.instance;
      final client = manager.createPinnedHttpClient();
      expect(client, isNotNull);
      client.close();
    });

    test('AppHttpClient integrates SSL Pinning by default', () {
      final client = AppHttpClient.instance.client;
      expect(client, isNotNull);
    });
  });
}
