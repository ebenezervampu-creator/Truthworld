import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import 'package:truthworld/features/content/presentation/controllers/copyright_complaint_controller.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/copyright_complaint_screen.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Group 1: Public & Informational Pages', () {
    testWidgets('1. AboutPage renders cleanly without error', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(tester, const AboutPage());
      expect(tester.takeException(), isNull);
      expect(find.text('About Truthworld'), findsOneWidget);
    });

    testWidgets('2. PrivacyPolicyScreen renders policy content and navigation',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(tester, PrivacyPolicyScreen());
      expect(tester.takeException(), isNull);
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('3. TermsAndConditionsPage renders legal clauses and agreement button',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(tester, TermsAndConditionsPage());
      expect(tester.takeException(), isNull);
      expect(find.byType(TermsAndConditionsPage), findsOneWidget);
    });

    testWidgets(
        '3b. TermsAndConditionsPage mobile agreement flow renders prompt without overflow and shows button with visible text',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        TermsAndConditionsPage(requireAgreement: true),
        physicalSize: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Please scroll to the bottom to accept Terms and Conditions'),
        findsOneWidget,
      );

      // Scroll to the bottom
      final scrollable = find.byType(SingleChildScrollView);
      for (var i = 0; i < 5; i++) {
        await tester.drag(scrollable, const Offset(0, -30000));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      expect(
        find.text('I Have Read & Accept Terms and Conditions'),
        findsOneWidget,
      );
    });

    testWidgets('4. CommunityGuidelinesPage renders guidelines and safety standards',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(tester, CommunityGuidelinesPage());
      expect(tester.takeException(), isNull);
      expect(find.byType(CommunityGuidelinesPage), findsOneWidget);
    });

    testWidgets(
        '4b. CommunityGuidelinesPage mobile agreement flow renders prompt without overflow and shows button with visible text',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        CommunityGuidelinesPage(requireAgreement: true),
        physicalSize: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Please scroll to the bottom to accept Community Guidelines'),
        findsOneWidget,
      );

      // Scroll to the bottom
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -30000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('I Have Read & Accept Community Guidelines'),
        findsOneWidget,
      );
    });

    testWidgets('5. CopyrightComplaintScreen renders DMCA submission form',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CopyrightComplaintScreen(),
        onBeforePump: () {
          Get.put<CopyrightComplaintController>(CopyrightComplaintController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Copyright Infringement Notice'), findsOneWidget);
    });

    testWidgets('6. SendFeedbackPage renders feedback form', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SendFeedbackPage(),
        onBeforePump: () {
          Get.put<SendFeedbackController>(SendFeedbackController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Feedback'), findsOneWidget);
    });
  });
}
