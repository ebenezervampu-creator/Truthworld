import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/repositories/video_report_repository.dart';

class _FakeHttpsCallableResult implements HttpsCallableResult<dynamic> {
  _FakeHttpsCallableResult(this.data);

  @override
  final dynamic data;
}

class _FakeHttpsCallable extends Fake implements HttpsCallable {
  _FakeHttpsCallable(this.onCall);

  final Future<HttpsCallableResult<dynamic>> Function(dynamic parameters) onCall;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final res = await onCall(parameters);
    return res as HttpsCallableResult<T>;
  }
}

class _FakeFirebaseFunctions extends Fake implements FirebaseFunctions {
  String? lastCallableName;
  dynamic lastParameters;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    lastCallableName = name;
    return _FakeHttpsCallable((parameters) async {
      lastParameters = parameters;
      return _FakeHttpsCallableResult({'success': true, 'reportCount': 1, 'isBlocked': false});
    });
  }
}

void main() {
  group('VideoReportRepository', () {
    test('validateReportDetails rejects profanity', () async {
      final repo = VideoReportRepository(functions: _FakeFirebaseFunctions());
      final result = await repo.validateReportDetails('This is fuck terrible');
      expect(result.isValid, isFalse);
    });

    test('validateReportDetails accepts clean details', () async {
      final repo = VideoReportRepository(functions: _FakeFirebaseFunctions());
      final result = await repo.validateReportDetails('Misleading thumbnail and spam link');
      expect(result.isValid, isTrue);
    });

    test('addReport calls submitVideoReport callable with sanitized payload', () async {
      final fakeFunctions = _FakeFirebaseFunctions();
      final repo = VideoReportRepository(functions: fakeFunctions);

      await repo.addReport(
        videoId: 'vid_12345',
        reporterId: 'user_abc',
        reportType: 'spam',
        details: '  Repeated spam promotion  ',
      );

      expect(fakeFunctions.lastCallableName, 'submitVideoReport');
      expect(fakeFunctions.lastParameters, {
        'videoId': 'vid_12345',
        'reportType': 'spam',
        'details': 'Repeated spam promotion',
      });
    });
  });
}
