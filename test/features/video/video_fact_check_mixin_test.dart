import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/mixins/video_fact_check_mixin.dart';

class TestFactCheckController extends GetxController with VideoFactCheckMixin {
  TestFactCheckController(this._video);

  final Video _video;

  @override
  Video get video => _video;

  @override
  final RxMap<String, dynamic> factCheckData = <String, dynamic>{}.obs;

  @override
  final RxBool isLoadingFactCheck = false.obs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Video dummyVideo;

  setUp(() {
    Get.reset();
    dummyVideo = Video(
      id: 'test_vid_456',
      title: 'Test Space Strategy',
      description: 'Space exploration strategy video',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'owner_1',
      channelId: 'ch_1',
      channelName: 'ISRO Updates',
      category: 'Science',
      tags: const ['space', 'isro'],
      factCheckUrl: 'https://storage.googleapis.com/factchecks/test_vid_456.json',
      trustScore: 78.0,
      uiReport: UIReport.fromMap({
        'narrative': 'Fallback narrative from video document',
        'conclusion': 'Reliable content',
      }),
    );
  });

  tearDown(() {
    AppHttpClient.instance.client = null;
    VideoMediaService.credibilityCache.clear();
  });

  test('loadFactCheckData populates data on 200 OK response', () async {
    AppHttpClient.instance.client = MockClient((request) async {
      return http.Response(
        '{"trustScore": 92.0, "trustLabel": "VERIFIED", "summary": "Highly accurate"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final controller = TestFactCheckController(dummyVideo);
    expect(controller.factCheckData.isEmpty, isTrue);
    expect(controller.hasAttemptedFactCheck.value, isFalse);

    await controller.loadFactCheckData();

    expect(controller.factCheckData.isNotEmpty, isTrue);
    expect(controller.factCheckData['trustScore'], 92.0);
    expect(controller.hasAttemptedFactCheck.value, isTrue);
    expect(controller.hasFactCheckError.value, isFalse);
    expect(controller.isLoadingFactCheck.value, isFalse);
  });

  test('loadFactCheckData handles HTTP error and falls back to credibility cache or uiReport', () async {
    AppHttpClient.instance.client = MockClient((request) async {
      return http.Response('Not Found', 404);
    });

    // Seed credibility cache
    VideoMediaService.credibilityCache[dummyVideo.id] = const VideoMediaCredibility(
      trustScore: 84.0,
      trustLabel: 'HIGH_TRUST',
      summary: 'Cached credibility fallback',
    );

    final controller = TestFactCheckController(dummyVideo);

    await controller.loadFactCheckData();

    // Should gracefully fall back without throwing an unhandled exception
    expect(controller.factCheckData.isNotEmpty, isTrue);
    expect(controller.factCheckData['trustScore'], 84.0);
    expect(controller.hasAttemptedFactCheck.value, isTrue);
    expect(controller.hasFactCheckError.value, isFalse);
    expect(controller.isLoadingFactCheck.value, isFalse);
  });

  test('loadFactCheckData deduplicates repeated calls for the same URL', () async {
    var requestCount = 0;
    AppHttpClient.instance.client = MockClient((request) async {
      requestCount++;
      return http.Response('Internal Error', 500);
    });

    final videoWithoutFallback = Video(
      id: 'no_fallback_vid',
      title: 'No Fallback Video',
      description: 'Video without fallback credibility data',
      thumbnailUrl: '',
      ownerId: 'owner_2',
      channelId: 'ch_2',
      channelName: 'Channel 2',
      category: 'General',
      tags: const [],
      factCheckUrl: 'https://example.com/missing.json',
    );

    final controller = TestFactCheckController(videoWithoutFallback);

    await controller.loadFactCheckData();
    expect(requestCount, equals(1));
    expect(controller.hasAttemptedFactCheck.value, isTrue);
    expect(controller.hasFactCheckError.value, isTrue);

    // Second call without force should be a no-op
    await controller.loadFactCheckData();
    expect(requestCount, equals(1), reason: 'Should not re-fetch without force');

    // Force call should retry
    await controller.loadFactCheckData(null, true);
    expect(requestCount, equals(2), reason: 'Should retry when force is true');
  });
}
