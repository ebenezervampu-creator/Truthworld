import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/pipeline/pipeline_components.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createHarness(Widget child) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  final sampleVideo = Video.fromMap({
    'title': 'Investigative Fact Check',
    'channelId': 'chan_test_1',
    'channelName': 'TruthWorld Studio',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'status': 'ready',
    'description': 'Verified factual content by community moderators.',
    'transcriptionUrl': 'https://example.com/transcript.json',
    'factCheckUrl': 'https://example.com/factcheck.pdf',
    'subtitles': {'en': 'https://example.com/en.srt', 'te': 'https://example.com/te.srt'},
    'audioTracks': {'hi': 'https://example.com/hi.mp3'},
    'resolutions': {'1080p': 'https://example.com/1080.mp4'},
  });

  group('Pipeline Color and Icon Helpers Tests', () {
    test('getSafetyColor and getSafetyIcon resolve correctly for all statuses', () {
      expect(getSafetyColor('APPROVED'), AppColors.success);
      expect(getSafetyIcon('APPROVED'), Icons.check_circle_outline_rounded);

      expect(getSafetyColor('REJECTED'), AppColors.error);
      expect(getSafetyIcon('REJECTED'), Icons.cancel_outlined);

      expect(getSafetyColor('MANUAL_REVIEW'), AppColors.info);
      expect(getSafetyIcon('MANUAL_REVIEW'), Icons.hourglass_top_rounded);

      expect(getSafetyColor('ERROR'), AppColors.warning);
      expect(getSafetyIcon('ERROR'), Icons.warning_amber_rounded);

      expect(getSafetyColor('PENDING'), AppColors.warning);
      expect(getSafetyIcon('PENDING'), Icons.hourglass_empty_rounded);
    });

    test('getIntentColor resolves intent strings into semantic theme colors', () {
      expect(getIntentColor('news_reporting'), AppColors.info);
      expect(getIntentColor('educational'), AppColors.success);
      expect(getIntentColor('commentary'), AppColors.brand);
      expect(getIntentColor('entertainment'), AppColors.textSecondary);
      expect(getIntentColor('promotional'), AppColors.warning);
      expect(getIntentColor('instructional_harmful'), AppColors.error);
      expect(getIntentColor('unknown_intent'), AppColors.textTertiary);
    });

    test('getRiskColor resolves risk levels into appropriate severity colors', () {
      expect(getRiskColor('safe'), AppColors.success);
      expect(getRiskColor('low'), AppColors.success);
      expect(getRiskColor('medium'), AppColors.warning);
      expect(getRiskColor('high'), AppColors.error);
      expect(getRiskColor('critical'), AppColors.error);
      expect(getRiskColor('unspecified'), AppColors.textTertiary);
    });
  });

  group('Pipeline Modular Components Widget Tests', () {
    testWidgets('PipelineModerationPanel renders processing state with spinner', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const PipelineModerationPanel(status: 'PROCESSING'),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing content (topic, intent, risk)...'), findsOneWidget);
    });

    testWidgets('PipelineModerationPanel renders approved state with chips and summary', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const PipelineModerationPanel(
            status: 'APPROVED',
            topic: 'public_health',
            intent: 'educational',
            riskLevel: 'safe',
            summary: 'Clear educational overview of factual medical data.',
            processingTimeMs: 1500,
          ),
        ),
      );

      expect(find.text('Content approved — complies with Community Guidelines'), findsOneWidget);
      expect(find.text('Topic: public health'), findsOneWidget);
      expect(find.text('Intent: educational'), findsOneWidget);
      expect(find.text('Risk: SAFE'), findsOneWidget);
      expect(find.text('Clear educational overview of factual medical data.'), findsOneWidget);
      expect(find.text('1.5s'), findsOneWidget);
    });

    testWidgets('PipelineModerationPanel renders rejected state with violation categories', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const PipelineModerationPanel(
            status: 'REJECTED',
            reason: 'Violates misleading content guidelines',
            categories: ['medical_misinformation', 'harmful_advice'],
          ),
        ),
      );

      expect(find.text('Content rejected — policy violation detected'), findsOneWidget);
      expect(find.text('Violates misleading content guidelines'), findsOneWidget);
      expect(find.text('MEDICAL MISINFORMATION'), findsOneWidget);
      expect(find.text('HARMFUL ADVICE'), findsOneWidget);
    });

    testWidgets('PipelineModerationPanel renders manual review state with guidance box', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const PipelineModerationPanel(
            status: 'MANUAL_REVIEW',
            reason: 'Requires editorial evaluation',
          ),
        ),
      );

      expect(find.text('Pending manual review — awaiting admin decision'), findsOneWidget);
      expect(find.text('Requires editorial evaluation'), findsOneWidget);
      expect(
        find.textContaining('Our AI detected this content discusses a sensitive topic'),
        findsOneWidget,
      );
    });

    testWidgets('PipelineResolutionChips renders adaptive variants correctly', (tester) async {
      final variants = {
        '1080p': {'status': 'completed'},
        '720p': {'status': 'processing'},
        '480p': {'status': 'failed'},
        '360p': {'status': 'pending'},
      };

      await tester.pumpWidget(
        createHarness(
          PipelineResolutionChips(variants: variants),
        ),
      );

      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('720p'), findsOneWidget);
      expect(find.text('480p'), findsOneWidget);
      expect(find.text('360p'), findsOneWidget);
      expect(find.text('240p'), findsOneWidget);
      expect(find.text('144p'), findsOneWidget);
    });

    testWidgets('PipelineTimelineStages renders stage labels and statuses', (tester) async {
      final stages = {
        'upload': {'status': 'completed', 'progress': 100},
        'validation': {'status': 'completed', 'progress': 100},
        'transcription': {'status': 'running', 'progress': 65},
        'credibility': {'status': 'pending'},
      };

      await tester.pumpWidget(
        createHarness(
          PipelineTimelineStages(stages: stages, video: sampleVideo),
        ),
      );

      expect(find.text('Upload Source'), findsOneWidget);
      expect(find.text('Safety & Format Check'), findsOneWidget);
      expect(find.text('Transcription (Verification System)'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('Factcheck (Verify)'), findsOneWidget);
    });

    testWidgets('PipelineArtifactLinksPanel renders direct download and viewer buttons', (tester) async {
      await tester.pumpWidget(
        createHarness(
          PipelineArtifactLinksPanel(video: sampleVideo),
        ),
      );

      expect(find.text('Transcript JSON'), findsOneWidget);
      expect(find.text('Fact-Check Report'), findsOneWidget);
      expect(find.text('SRT/VTT (EN)'), findsOneWidget);
      expect(find.text('SRT/VTT (TE)'), findsOneWidget);
      expect(find.text('Audio (HI)'), findsOneWidget);
      expect(find.text('1080p Direct Link'), findsOneWidget);
    });

    testWidgets('PipelineGenerateAIButton renders full width trigger button', (tester) async {
      await tester.pumpWidget(
        createHarness(
          PipelineGenerateAIButton(video: sampleVideo),
        ),
      );

      expect(
        find.text('Generate / Add AI Features (Telugu, Hindi, Dubbing, Factcheck...)'),
        findsOneWidget,
      );
    });
  });
}
