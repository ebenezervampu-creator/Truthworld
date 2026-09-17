import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import 'package:truthworld/features/content/presentation/controllers/copyright_complaint_controller.dart';
import 'package:truthworld/features/feedback/presentation/bindings/feedback_binding.dart';
import 'package:truthworld/features/feedback/presentation/controllers/feedback_controller.dart';
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart';
import 'package:truthworld/features/landing/presentation/bindings/landing_binding.dart';
import 'package:truthworld/features/landing/presentation/controllers/landing_controller.dart';
import 'package:truthworld/features/premium/presentation/bindings/premium_binding.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put<AuthService>(AuthService());
  });

  tearDown(Get.reset);

  group('Feature: Premium', () {
    test('PremiumController initializes with correct defaults', () {
      final controller = PremiumController();
      expect(controller.selectedPlanId.value, 'individual_monthly');
      expect(controller.rxIsLoading.value, isFalse);
      expect(controller.isSimulating.value, isFalse);
    });

    test('selectPlan updates selectedPlanId', () {
      final controller = PremiumController();
      controller.selectPlan('annual_pro');
      expect(controller.selectedPlanId.value, 'annual_pro');

      controller.selectPlan('creator_team');
      expect(controller.selectedPlanId.value, 'creator_team');
    });

    testWidgets('purchasePlan handles unauthenticated state gracefully',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      final controller = PremiumController();
      // User is not authenticated by default in mock AuthService
      await controller.purchasePlan('individual_monthly');
      await tester.pump();
      expect(controller.rxIsLoading.value, isFalse);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    test('cancelSimulated handles unauthenticated state safely', () async {
      final controller = PremiumController();
      await controller.cancelSimulated();
      expect(controller.isSimulating.value, isFalse);
    });

    test('PremiumBinding registers PremiumController in GetX', () {
      final binding = PremiumBinding();
      binding.dependencies();
      expect(Get.isPrepared<PremiumController>(), isTrue);
    });
  });

  group('Feature: Feedback', () {
    test('FeedbackController initializes with default state', () {
      final controller = FeedbackController();
      expect(controller.feedbackType.value, 'General');
      expect(controller.feedbackText.value, '');
      expect(controller.rating.value, 0);
      expect(controller.isSubmitting.value, isFalse);
      expect(controller.canSubmit, isFalse);
      expect(controller.hasRating, isFalse);
    });

    test('updateFeedbackText and canSubmit validation', () {
      final controller = FeedbackController();
      expect(controller.canSubmit, isFalse);

      controller.updateFeedbackText('   ');
      expect(controller.canSubmit, isFalse);

      controller.updateFeedbackText('This is valid feedback text');
      expect(controller.canSubmit, isTrue);
      expect(controller.feedbackText.value, 'This is valid feedback text');
    });

    test('setRating updates rating only for valid range (0-5)', () {
      final controller = FeedbackController();
      controller.setRating(4);
      expect(controller.rating.value, 4);
      expect(controller.hasRating, isTrue);

      controller.setRating(5);
      expect(controller.rating.value, 5);

      // Invalid ratings outside 0-5 are ignored
      controller.setRating(10);
      expect(controller.rating.value, 5);

      controller.setRating(-1);
      expect(controller.rating.value, 5);

      controller.setRating(0);
      expect(controller.rating.value, 0);
      expect(controller.hasRating, isFalse);
    });

    test('setFeedbackType updates feedback category', () {
      final controller = FeedbackController();
      controller.setFeedbackType('Bug Report');
      expect(controller.feedbackType.value, 'Bug Report');

      controller.setFeedbackType('Feature Request');
      expect(controller.feedbackType.value, 'Feature Request');
    });

    test('clearFeedback and reset restore initial state', () {
      final controller = FeedbackController();
      controller.updateFeedbackText('Some detailed feedback here');
      controller.setFeedbackType('Bug');
      controller.setRating(3);

      controller.clearFeedback();
      expect(controller.feedbackText.value, '');
      expect(controller.feedbackType.value, 'General');
      expect(controller.rating.value, 0);

      controller.updateFeedbackText('Another feedback');
      controller.reset();
      expect(controller.feedbackText.value, '');
    });

    test('submitFeedback validates minimum character length (<10)', () async {
      final controller = FeedbackController();
      controller.updateFeedbackText('Too short');
      await controller.submitFeedback(
        userId: 'user-123',
        userEmail: 'test@example.com',
      );
      expect(controller.errorMessage, 'Feedback must be at least 10 characters');
    });

    test('submitFeedback rejects unauthenticated/anonymous callers', () async {
      final controller = FeedbackController();
      controller.updateFeedbackText('Valid feedback text here');
      await controller.submitFeedback(
        userId: 'anonymous',
        userEmail: 'guest@example.com',
      );
      expect(controller.errorMessage, 'You must be signed in to submit feedback');
    });

    test('SendFeedbackController provides expected feedback options and requires auth on submit', () async {
      final controller = SendFeedbackController();
      expect(controller.feedbackTypes, containsAll([
        'Bug',
        'Feature Request',
        'General',
        'Other',
      ]));
      expect(controller.feedbackType.value, 'General');
      expect(controller.rating.value, 0);
      controller.feedbackController.text = 'Great app, keep it up!';
      // Guest submit returns early without submitting
      await controller.submitFeedback();
      expect(controller.isSubmitting.value, isFalse);
    });

    test('CopyrightComplaintController enforces authentication before submitting', () async {
      final controller = CopyrightComplaintController();
      controller.onInit();
      controller.nameController.text = 'Copyright Owner';
      controller.emailController.text = 'owner@example.com';
      await controller.submitComplaint();
      expect(controller.isSubmitting.value, isFalse);
      expect(controller.submittedComplaintId.value, isNull);
      controller.onClose();
    });

    test('FeedbackBinding initializes without exceptions', () {
      final binding = FeedbackBinding();
      expect(binding.dependencies, returnsNormally);
    });
  });

  group('Feature: Landing', () {
    test('LandingController initializes and closes cleanly', () {
      final controller = LandingController();
      expect(controller, isA<LandingController>());
      expect(controller.onClose, returnsNormally);
    });

    test('LandingBinding registers LandingController', () {
      final binding = LandingBinding();
      binding.dependencies();
      expect(Get.isPrepared<LandingController>(), isTrue);
    });
  });

  group('Feature: About', () {
    testWidgets('AboutPage renders core platform mission and pillars',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: AboutPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & core sections
      expect(find.text('About Truthworld'), findsOneWidget);
      expect(find.text('The Next Generation of\nTrusted Video Publishing'), findsOneWidget);
      expect(find.text('Core Platform Pillars'), findsOneWidget);
      expect(find.text('Content Validation Layer'), findsOneWidget);
      expect(find.text('AI Multilingual Dubbing'), findsOneWidget);
      expect(find.text('Creator-First Economics'), findsOneWidget);
      expect(find.text('How Content Verification Works'), findsOneWidget);
      expect(find.text('Creator-First Monetization'), findsOneWidget);
    });

    testWidgets('AboutPage in dashboard mode hides modern app bar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: AboutPage(isDashboard: true),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar title is not present in dashboard mode
      expect(find.text('About Truthworld'), findsNothing);
      // Hero headline is still present
      expect(find.text('The Next Generation of\nTrusted Video Publishing'), findsOneWidget);
    });
  });
}
