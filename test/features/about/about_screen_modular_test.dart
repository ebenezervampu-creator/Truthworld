import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createWidgetUnderTest(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('AboutScreen Modular Presentation & Controller Tests', () {
    test('AboutController initializes animations and cleans up on close', () {
      final controller = AboutController();
      controller.onInit();

      expect(controller.fadeAnimation, isNotNull);
      expect(controller.slideAnimation, isNotNull);
      expect(controller.scaleAnimation, isNotNull);
      expect(controller.fadeAnimationController.isAnimating || controller.fadeAnimationController.isCompleted, isTrue);

      expect(controller.onClose, returnsNormally);
    });

    testWidgets('AboutModernAppBar renders title, logo and action buttons', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            appBar: AboutModernAppBar(),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('About Truthworld'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('AboutHeroSection renders badge, headline, and action buttons', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutHeroSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('TRUTH-FIRST VIDEO PLATFORM • VERIFIED MEDIA INFRASTRUCTURE'), findsOneWidget);
      expect(find.text('The Next Generation of\nTrusted Video Publishing'), findsOneWidget);
      expect(find.text('Start Creating'), findsOneWidget);
      expect(find.text('Upload Verified Video'), findsOneWidget);
    });

    testWidgets('AboutPlatformPillarsSection renders 3 core pillars with white icons', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutPlatformPillarsSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Core Platform Pillars'), findsOneWidget);
      expect(find.text('Content Validation Layer'), findsOneWidget);
      expect(find.text('AI Multilingual Dubbing'), findsOneWidget);
      expect(find.text('Creator-First Economics'), findsOneWidget);

      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
      expect(find.byIcon(Icons.g_translate_rounded), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on_outlined), findsOneWidget);
    });

    testWidgets('AboutVerificationPipelineSection renders 4 verification steps', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutVerificationPipelineSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('How Content Verification Works'), findsOneWidget);
      expect(find.text('Upload & Automated Claim Extraction'), findsOneWidget);
      expect(find.text('Creator Source & Citation Attribution'), findsOneWidget);
      expect(find.text('Cross-Verification & Consistency Check'), findsOneWidget);
      expect(find.text('Public Credibility Scorecard'), findsOneWidget);
    });

    testWidgets('AboutMonetizationSection renders 100% and 75% creator share cards', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutMonetizationSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Creator-First Monetization'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Net Ad Revenue to Creators'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Subscription Revenue to Creators'), findsOneWidget);
    });

    testWidgets('AboutLeadershipSection renders executive founder profile and competency tags', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutLeadershipSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Executive Leadership'), findsOneWidget);
      expect(find.text('Vampu Ebenezer'), findsOneWidget);
      expect(find.text('Founder, Director & Lead Platform Architect'), findsOneWidget);
      expect(find.text('AI Verification Architecture'), findsOneWidget);
      expect(find.text('Cloud-Native Infrastructure'), findsOneWidget);
    });

    testWidgets('AboutCorporateAndGrievanceSection renders CIN, MCA info and grievance officer', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutCorporateAndGrievanceSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Corporate & Legal Information'), findsOneWidget);
      expect(find.text('TOWERVSP SERVICES (OPC) PRIVATE LIMITED'), findsOneWidget);
      expect(find.text('U63111TS2025OPC207488'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('hello@truthworld.in'), findsWidgets);
    });

    testWidgets('AboutCTASection renders movement invitation banner and button', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const AboutCTASection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
          ),
        ),
      );

      expect(find.text('Join the Truthworld Movement'), findsOneWidget);
      expect(find.text('Start Creating Verified Content'), findsOneWidget);
    });

    testWidgets('AboutFooterSection renders statutory corporate footer and links', (tester) async {
      var launchedUrl = '';
      var sentEmail = '';
      var phoned = '';

      await tester.pumpWidget(
        createWidgetUnderTest(
          AboutFooterSection(
            isDesktop: true,
            isTablet: false,
            isMobile: false,
            onLaunchUrl: (url) => launchedUrl = url,
            onSendEmail: (email) => sentEmail = email,
            onCallPhone: (num) => phoned = num,
          ),
        ),
      );

      expect(find.text('TOWERVSP SERVICES (OPC) PRIVATE LIMITED'), findsOneWidget);

      await tester.tap(find.text('hello@truthworld.in'));
      expect(sentEmail, 'hello@truthworld.in');

      await tester.tap(find.text('LinkedIn'));
      expect(launchedUrl, contains('linkedin.com'));

      await tester.tap(find.text('+91 9390617877'));
      expect(phoned, '+919390617877');
    });

    testWidgets('AboutPage renders fully in declarative standard and dashboard modes', (tester) async {
      // 1. Standard mode (with app bar)
      await tester.pumpWidget(
        const GetMaterialApp(
          home: AboutPage(),
        ),
      );
      await tester.pump();

      expect(find.text('About Truthworld'), findsOneWidget);
      expect(find.text('The Next Generation of\nTrusted Video Publishing'), findsOneWidget);
      expect(find.text('Core Platform Pillars'), findsOneWidget);

      // 2. Dashboard mode (app bar hidden)
      await tester.pumpWidget(
        const GetMaterialApp(
          home: AboutPage(isDashboard: true),
        ),
      );
      await tester.pump();

      expect(find.text('About Truthworld'), findsNothing);
      expect(find.text('The Next Generation of\nTrusted Video Publishing'), findsOneWidget);
    });
  });
}
