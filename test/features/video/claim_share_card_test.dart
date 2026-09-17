import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_share_card.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  group('ClaimShareCard', () {
    late Video sampleVideo;
    late ClaimVerdictInfo sampleVerdict;

    setUp(() {
      sampleVideo = Video(
        id: 'vid_test_101',
        title: 'Exposing Global Climate Policy Claims',
        description: 'An investigative report into recent environmental statements.',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_456',
        channelId: 'chan_789',
        channelName: 'GlobalTruth',
        category: 'News & Politics',
        tags: ['climate', 'news'],
      );

      sampleVerdict = const ClaimVerdictInfo(
        type: ClaimVerdictType.falseClaim,
        label: 'FALSE CLAIM',
        color: AppColors.error,
        icon: Icons.cancel_rounded,
        category: 'False',
        summaryTakeaway: 'This statement is contradicted by documented atmospheric observations.',
        confidenceText: 'High (94%)',
        confidenceVal: 0.94,
      );
    });

    testWidgets('renders all required elements with correct typography and colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClaimShareCard(
                video: sampleVideo,
                claimText: 'Global sea ice extent reached an unprecedented all-time peak last month.',
                verdict: sampleVerdict,
                primarySourceDomain: 'climate.nasa.gov',
              ),
            ),
          ),
        ),
      );

      // Verify Video Title is rendered
      expect(find.text('Exposing Global Climate Policy Claims'), findsOneWidget);

      // Verify Claim text is rendered
      expect(
        find.text('Global sea ice extent reached an unprecedented all-time peak last month.'),
        findsOneWidget,
      );

      // Verify Verdict label is rendered
      expect(find.text('FALSE CLAIM'), findsOneWidget);

      // Verify Summary Takeaway is rendered
      expect(
        find.text('This statement is contradicted by documented atmospheric observations.'),
        findsOneWidget,
      );

      // Verify Confidence text is rendered
      expect(find.text('Confidence: High (94%)'), findsOneWidget);

      // Verify Primary Source Domain is rendered
      expect(find.text('climate.nasa.gov'), findsOneWidget);

      // Verify Footer branding is rendered
      expect(find.text('Verified by TruthWorld'), findsOneWidget);

      // Verify all icons are strictly Colors.white
      final iconWidgets = tester.widgetList<Icon>(find.byType(Icon));
      for (final icon in iconWidgets) {
        expect(
          icon.color == Colors.white ||
              icon.color == Colors.white.withValues(alpha: 0.15),
          isTrue,
          reason: 'Icon color must be Colors.white or white alpha: ${icon.color}',
        );
      }
    });

    testWidgets('renders gracefully when confidence and primary source domain are absent', (tester) async {
      const minimalVerdict = ClaimVerdictInfo(
        type: ClaimVerdictType.verifiedTrue,
        label: 'VERIFIED TRUE',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        category: 'Verified',
        summaryTakeaway: 'Corroborated by independent institutional archives.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClaimShareCard(
                video: sampleVideo,
                claimText: 'Solar panel deployment grew 30% year over year.',
                verdict: minimalVerdict,
              ),
            ),
          ),
        ),
      );

      expect(find.text('VERIFIED TRUE'), findsOneWidget);
      expect(find.text('Corroborated by independent institutional archives.'), findsOneWidget);
      expect(find.textContaining('Confidence:'), findsNothing);
      expect(find.text('Verified by TruthWorld'), findsOneWidget);
    });
  });
}
