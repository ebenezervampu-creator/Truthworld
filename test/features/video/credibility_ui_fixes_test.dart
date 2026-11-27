import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/services/ai_credibility_chat_service.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_models_helper.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';

void main() {
  group('Millisecond timestamp resolution (6000ms -> 00:06, never 1:40:00)', () {
    test('VideoAnalysisHelpers handles explicit ms, numeric ms >= 1000, and seconds safely', () {
      expect(VideoAnalysisHelpers.normalizeTimestampToMs(6000), 6000);
      expect(
        FormatUtils.formatDuration(
          Duration(milliseconds: VideoAnalysisHelpers.normalizeTimestampToMs(6000)),
        ),
        '00:06',
      );
      expect(
        VideoAnalysisHelpers.resolveClaimTimestampMs({'startMs': 6000, 'start': 6000}),
        6000,
      );
      expect(
        VideoAnalysisHelpers.resolveClaimTimestampMs({'startMs': 500}),
        500,
      );
      expect(
        VideoAnalysisHelpers.resolveClaimTimestampMs({'startSeconds': 6}),
        6000,
      );
      expect(
        VideoAnalysisHelpers.normalizeTimestampToMs('01:40'),
        100000,
      );
    });

    test('FactCheckModelsHelper matches millisecond normalization and ClaimResult.fromMap avoids 1:40:00', () {
      expect(normalizeTimestampToMs(6000), 6000);
      expect(
        getClaimStartSeconds({'startMs': 6000, 'start': 6000}),
        closeTo(6.0, 0.001),
      );
      expect(
        getClaimStartSeconds({'start': 6000}),
        closeTo(6.0, 0.001),
      );

      final parsedClaim = ClaimResult.fromMap({
        'claim': 'Apollo 11 rocket launched in 1969.',
        'status': 'verified_true',
        'start': 6000,
        'end': 12000,
      });
      expect(parsedClaim.start, closeTo(6.0, 0.001));
      expect(parsedClaim.end, closeTo(12.0, 0.001));
    });
  });

  group('ccTLD domain inference, Verified Source prevention & Favicon resolution', () {
    const redirectUrl =
        'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQEexample123';

    test('SourceUrlSanitizer extracts spacecentre.nz & co.uk instead of Verified Source while skipping filenames', () {
      expect(
        SourceUrlSanitizer.resolveDisplayDomain(
          redirectUrl,
          title: 'Moon landing evidence | Space Centre New Zealand - spacecentre.nz',
          explicitDomain: 'vertexaisearch.cloud.google.com',
          publisher: 'Google',
        ),
        'spacecentre.nz',
      );
      expect(
        SourceUrlSanitizer.resolveDisplayDomain(
          redirectUrl,
          title: 'Apollo 11 mission debrief (bbc.co.uk)',
        ),
        'bbc.co.uk',
      );
      expect(
        SourceUrlSanitizer.resolveDisplayDomain(
          redirectUrl,
          title: 'Download diagram photo.png or manual.pdf',
        ),
        'Verified Source',
      );
    });

    test('SourceAvatarService skips Google/Vertex hosts and resolves spacecentre.nz favicon', () {
      final avatar = SourceAvatarService.resolveAvatarUrl(
        domain: 'vertexaisearch.cloud.google.com',
        url: redirectUrl,
        publisher: 'Google',
        title: 'Lunar impact dust analysis - spacecentre.nz',
      );
      expect(avatar, contains('domain=spacecentre.nz'));
      expect(avatar, isNot(contains('vertexaisearch')));
      expect(avatar, isNot(contains('domain=google.com')));
    });
  });

  group('AiCredibilityChatService AppCheck headers & non-corporate heuristic synthesis', () {
    test('buildStreamRequestHeaders attaches X-Firebase-AppCheck when token is loaded', () async {
      final headers = await AiCredibilityChatService.buildStreamRequestHeaders(
        authToken: 'firebase-id-token-123',
        appCheckTokenLoader: () async => 'appcheck-token-xyz',
      );
      expect(headers['Authorization'], 'Bearer firebase-id-token-123');
      expect(headers['X-Firebase-AppCheck'], 'appcheck-token-xyz');
      expect(headers['Accept'], 'text/event-stream');
    });

    test('buildLocalHeuristicResponse omits corporate/financial boilerplate and reports real claim ledger counts', () {
      final svc = AiCredibilityChatService.instance;
      final msgWithClaims = svc.buildLocalHeuristicResponse(
        videoId: '11111111-1111-4111-8111-111111111111',
        scope: 'video',
        userQuery: 'moon Landing is really happened?',
        videoTitle: 'Moon Landing Dark reality',
        cachedClaims: [
          {'claim': 'Apollo 11 landed on the moon in 1969.', 'status': 'verified_true'},
          {'claim': 'No blast crater appeared beneath the module.', 'status': 'false_claim'},
          {'claim': 'Optical glare anomaly claim.', 'status': 'disputed'},
          {'claim': 'Telemetry tape archive location.', 'status': 'unproven'},
        ],
        cachedSources: [
          {'title': 'NASA Archive', 'url': 'https://www.nasa.gov/mission/apollo-11/'},
        ],
      );

      expect(msgWithClaims.text, contains('1 Verified'));
      expect(msgWithClaims.text, contains('1 Caution'));
      expect(msgWithClaims.text, contains('1 False'));
      expect(msgWithClaims.text, contains('1 No evidence yet'));
      expect(msgWithClaims.text, contains('Apollo 11 landed on the moon'));
      expect(msgWithClaims.text, isNot(contains('Forward-looking financial forecasts')));
      expect(msgWithClaims.text, isNot(contains('corporate milestones')));
      expect(msgWithClaims.text, isNot(contains('official company filings')));
      expect(msgWithClaims.text, isNot(contains('independent market data')));

      final msgEmpty = svc.buildLocalHeuristicResponse(
        videoId: '11111111-1111-4111-8111-111111111111',
        scope: 'video',
        userQuery: 'Did the moon landing really happen?',
        videoTitle: 'Moon Landing Dark reality',
        cachedClaims: const [],
        cachedSources: const [],
      );
      expect(msgEmpty.text, contains('temporarily unavailable'));
      expect(msgEmpty.text, isNot(contains('Forward-looking financial forecasts')));
      expect(msgEmpty.text, isNot(contains('0 verified assertions')));
    });
  });
}
