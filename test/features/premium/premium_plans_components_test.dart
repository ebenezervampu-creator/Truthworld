import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/premium_plans_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PremiumController controller;

  setUp(() {
    Get.reset();
    controller = Get.put(PremiumController());
  });

  tearDown(Get.reset);

  group('PremiumFeaturesGrid Tests', () {
    testWidgets('renders all feature items in grid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PremiumFeaturesGrid(isDesktop: true),
            ),
          ),
        ),
      );

      expect(find.text('All-Inclusive Benefits'), findsOneWidget);
      expect(find.text(r'Ad-Free Audio Mode ($0.50 / ₹40)'), findsOneWidget);
      expect(find.text(r'Ad-Free Video Playback ($2)'), findsOneWidget);
      expect(find.text(r'Every Video Fact-Checked ($3)'), findsOneWidget);
      expect(find.text(r'4K Ultra HD Streaming ($2 & $3)'), findsOneWidget);
      expect(find.text(r'Offline Downloads ($2 & $3)'), findsOneWidget);
      expect(find.text(r'Background Play & PiP ($2 & $3)'), findsOneWidget);
      expect(find.text(r'Multilingual AI Dubbing ($2 & $3)'), findsOneWidget);
    });

    testWidgets('renders column layout on mobile', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PremiumFeaturesGrid(),
            ),
          ),
        ),
      );

      expect(find.text('All-Inclusive Benefits'), findsOneWidget);
      expect(find.text(r'Ad-Free Audio Mode ($0.50 / ₹40)'), findsOneWidget);
    });
  });

  group('PremiumHeroSection Tests', () {
    testWidgets('renders trial CTA for non-premium user', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumHeroSection(
              isPremium: false,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Truthworld'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('Try 7 Days Free'), findsOneWidget);
      expect(find.textContaining('7 days free'), findsOneWidget);
    });

    testWidgets('renders active member badge for premium user', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumHeroSection(
              isPremium: true,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Active Member'), findsOneWidget);
      expect(find.text('Try 7 Days Free'), findsNothing);
    });
  });

  group('PremiumPlanCard and PremiumPlansList Tests', () {
    testWidgets('renders plan options and updates selected plan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumPlansList(controller: controller),
          ),
        ),
      );

      expect(find.text(r'$0.50 Audio Premium Plan'), findsOneWidget);
      expect(find.text(r'$2 TruthWorld Premium Plan'), findsOneWidget);
      expect(find.text(r'$3 Premium + Fact-Checked Plan'), findsOneWidget);

      // Default selected is individual_monthly
      expect(controller.selectedPlanId.value, equals('individual_monthly'));

      // Tap audio plan
      await tester.tap(find.text(r'$0.50 Audio Premium Plan'));
      await tester.pumpAndSettle();

      expect(controller.selectedPlanId.value, equals('audio_monthly'));
    });
  });

  group('PremiumCheckoutButton Tests', () {
    testWidgets('renders dynamic price label for selected plan with Auto Pay', (tester) async {
      controller.selectedPlanId.value = '4k_factchecked_monthly';
      controller.isAutoPay.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumCheckoutButton(controller: controller),
          ),
        ),
      );

      expect(find.text('Auto Pay'), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
      expect(find.text('Pay ₹249 with Auto Pay'), findsOneWidget);

      // Toggle auto pay off
      controller.toggleAutoPay(false);
      await tester.pumpAndSettle();

      expect(find.text('ONE-TIME'), findsOneWidget);
      expect(find.text('Pay ₹249 (One-Time)'), findsOneWidget);
    });
  });

  group('PremiumComparisonSection Tests', () {
    testWidgets('renders table and comparison rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PremiumComparisonSection(),
            ),
          ),
        ),
      );

      expect(find.text('Compare Free vs Premium'), findsOneWidget);
      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Ad-Free Audio Mode'), findsOneWidget);
      expect(find.text('Ad-Free Video Playback'), findsOneWidget);
      expect(find.text('Offline Downloads'), findsOneWidget);
    });
  });

  group('PremiumFaqSection Tests', () {
    testWidgets('renders FAQ questions in expansion tiles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PremiumFaqSection(),
            ),
          ),
        ),
      );

      expect(find.text('Frequently Asked Questions'), findsOneWidget);
      expect(find.text('What are the Truthworld Premium plans?'), findsOneWidget);
      expect(find.text(r'What is included in the $3 Premium + Fact-Checked Plan?'), findsOneWidget);
    });
  });

  group('PremiumInfoRow Tests', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumInfoRow(
              label: 'Billing Cycle',
              value: 'Monthly Renewal',
            ),
          ),
        ),
      );

      expect(find.text('Billing Cycle'), findsOneWidget);
      expect(find.text('Monthly Renewal'), findsOneWidget);
    });
  });

  group('PremiumPlansScreen Full Coordinator Tests', () {
    testWidgets('renders mobile layout cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PremiumPlansScreen(),
        ),
      );

      expect(find.text('Truthworld Premium'), findsWidgets);
      expect(find.text(r'Ad-Free Audio ($0.50 / ₹40), Video ($2) & Fact-Checked ($3)'), findsOneWidget);
    });

    testWidgets('renders Choose the plan that fits for you before All-Inclusive Benefits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PremiumPlansScreen(),
        ),
      );

      final planHeaderFinder = find.text('Choose the plan that fits for you');
      final benefitsHeaderFinder = find.text('All-Inclusive Benefits');

      expect(planHeaderFinder, findsOneWidget);
      expect(benefitsHeaderFinder, findsOneWidget);

      final planHeaderY = tester.getTopLeft(planHeaderFinder).dy;
      final benefitsHeaderY = tester.getTopLeft(benefitsHeaderFinder).dy;

      expect(planHeaderY, lessThan(benefitsHeaderY));
    });
  });

  group('PremiumDesktopSidebar Tests', () {
    testWidgets('renders membership overview and does not render quick shortcuts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumDesktopSidebar(controller: controller),
          ),
        ),
      );

      expect(find.text('MEMBERSHIP OVERVIEW'), findsOneWidget);
      expect(find.text('QUICK SHORTCUTS'), findsNothing);
      expect(find.text('Watch History'), findsNothing);
      expect(find.text('My Videos'), findsNothing);
      expect(find.text('Offline Downloads'), findsNothing);
    });
  });
}
