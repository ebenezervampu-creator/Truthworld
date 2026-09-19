import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truthworld/core/network/app_http_client.dart';

void main() {
  group('AppHttpClient Tests', () {
    tearDown(() {
      AppHttpClient.instance.client = null;
    });

    test('retains singleton instance and default headers', () {
      expect(AppHttpClient.instance, isNotNull);
      expect(
        AppHttpClient.defaultKeepAliveHeaders['Connection'],
        equals('keep-alive'),
      );
    });

    test('dispatches GET request with keep-alive headers through injected client', () async {
      var capturedKeepAlive = false;

      final mockClient = MockClient((request) async {
        if (request.headers['Connection'] == 'keep-alive') {
          capturedKeepAlive = true;
        }
        return http.Response('{"status":"ok"}', 200);
      });

      AppHttpClient.instance.client = mockClient;

      final response = await AppHttpClient.get(
        Uri.parse('https://example.com/test'),
      );

      expect(response.statusCode, equals(200));
      expect(response.body, equals('{"status":"ok"}'));
      expect(capturedKeepAlive, isTrue);
    });

    test('dispatches POST request through injected client', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.body, equals('hello world'));
        return http.Response('created', 201);
      });

      AppHttpClient.instance.client = mockClient;

      final response = await AppHttpClient.post(
        Uri.parse('https://example.com/api'),
        body: 'hello world',
      );

      expect(response.statusCode, equals(201));
      expect(response.body, equals('created'));
    });

    test('dispatches HEAD request through injected client', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('HEAD'));
        return http.Response('', 200, headers: {'content-length': '1024'});
      });

      AppHttpClient.instance.client = mockClient;

      final response = await AppHttpClient.head(
        Uri.parse('https://example.com/media.mp4'),
      );

      expect(response.statusCode, equals(200));
      expect(response.headers['content-length'], equals('1024'));
    });
  });
}
