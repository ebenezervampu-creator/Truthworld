import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/components/ui/share/cards/share_claim_card.dart';
import 'package:truthworld/components/ui/share/share_preview_cards.dart';

void main() {
  group('ShareClaimCard Widget Tests', () {
    testWidgets('renders claim text, video context, verdict badge and footer correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareClaimCard(
              title: 'Hyderabad is a rapidly growing city in southern India.',
              claimText: 'Hyderabad is a rapidly growing city in southern India.',
              videoTitle: 'Exploring Telangana Development',
              verdictLabel: 'VERIFIED TRUE',
              verdictColor: const Color(0xFF10B981),
              verdictIcon: Icons.check_circle_rounded,
              summaryTakeaway: 'Census data and urban development indices confirm rapid expansion.',
              confidenceText: 'High (98%)',
              sourceDomain: 'telangana.gov.in',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify claim text is rendered
      expect(
        find.textContaining('Hyderabad is a rapidly growing city'),
        findsOneWidget,
      );

      // Verify video context
      expect(find.text('Exploring Telangana Development'), findsOneWidget);

      // Verify [FACT CHECK] and verdict badge
      expect(find.text('FACT CHECK'), findsOneWidget);
      expect(find.text('VERIFIED TRUE'), findsOneWidget);

      // Verify takeaway, confidence, and source domain
      expect(
        find.textContaining('Census data and urban development indices'),
        findsOneWidget,
      );
      expect(find.text('Confidence: High (98%)'), findsOneWidget);
      expect(find.text('telangana.gov.in'), findsOneWidget);

      // Verify Truthworld Fact Check footer
      expect(find.text('Truthworld Fact Check'), findsOneWidget);
    });

    testWidgets('SharePreviewCard renders ShareClaimCard when contentType is claim',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePreviewCard(
              contentType: 'claim',
              title: 'Sample claim',
              claimText: 'The moon landing was staged in a Hollywood studio.',
              videoTitle: 'Moon Hoax Documentary',
              verdictLabel: 'FALSE CLAIM',
              verdictColor: const Color(0xFFEF4444),
              verdictIcon: Icons.cancel_rounded,
              summaryTakeaway: 'Extensive physical evidence and telemetry thoroughly refute this myth.',
              confidenceText: 'High (99%)',
              sourceDomain: 'nasa.gov',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShareClaimCard), findsOneWidget);
      expect(find.text('FALSE CLAIM'), findsOneWidget);
      expect(find.text('Moon Hoax Documentary'), findsOneWidget);
      expect(find.text('nasa.gov'), findsOneWidget);
    });
  });
}
