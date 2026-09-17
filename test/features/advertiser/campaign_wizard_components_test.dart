import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/widgets.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Campaign Wizard Extracted Components Tests', () {
    testWidgets('CampaignWizardStepTab renders title and icon correctly', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CampaignWizardStepTab(
                  stepIndex: 1,
                  title: 'Format & Objective',
                  icon: Icons.grid_view_rounded,
                  currentStep: 1,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Format & Objective'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      await tester.tap(find.text('Format & Objective'));
      expect(tapped, isTrue);
    });

    testWidgets('CampaignWizardStepTab shows check icon when step is completed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CampaignWizardStepTab(
                  stepIndex: 1,
                  title: 'Format & Objective',
                  icon: Icons.grid_view_rounded,
                  currentStep: 2,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('CampaignWizardAudienceBadge renders label and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CampaignWizardAudienceBadge(
              icon: Icons.public_rounded,
              label: 'Worldwide',
            ),
          ),
        ),
      );

      expect(find.text('Worldwide'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    });

    testWidgets('CampaignWizardAudienceSectionCard renders title, subtitle, and toggles content', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignWizardAudienceSectionCard(
              title: 'Audience Age Groups',
              subtitle: 'Select specific age brackets',
              icon: Icons.calendar_today_rounded,
              isAllSelected: false,
              allSelectedLabel: 'All Ages',
              onToggleAll: (val) => toggled = val,
              content: const Text('Age Chips Content'),
            ),
          ),
        ),
      );

      expect(find.text('Audience Age Groups'), findsOneWidget);
      expect(find.text('Select specific age brackets'), findsOneWidget);
      expect(find.text('All Ages'), findsOneWidget);
      expect(find.text('Age Chips Content'), findsOneWidget);

      await tester.tap(find.text('All Ages'));
      expect(toggled, isTrue);
    });

    testWidgets('CampaignWizardAudienceSectionCard FilterChip has dark text and checkmark when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignWizardAudienceSectionCard(
              title: 'Gender Demographics',
              subtitle: 'Target viewers based on user-specified gender identity',
              icon: Icons.wc_rounded,
              isAllSelected: true,
              allSelectedLabel: 'All Genders (Recommended)',
              onToggleAll: (_) {},
              content: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      final chipWidget = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chipWidget.selected, isTrue);
      expect(chipWidget.checkmarkColor, Colors.black);
      final textWidget = tester.widget<Text>(find.text('All Genders (Recommended)'));
      expect(textWidget.style?.color, Colors.black);
    });

    testWidgets('CampaignWizardFormatOption renders label, popular badge, and handles tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignWizardFormatOption(
              label: 'Video Sponsor Ads',
              value: 'video_sponsor',
              isSelected: true,
              icon: Icons.stars_rounded,
              isPopular: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Video Sponsor Ads'), findsOneWidget);
      expect(find.text('POPULAR (4-in-1)'), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);

      await tester.tap(find.text('Video Sponsor Ads'));
      expect(tapped, isTrue);
    });

    testWidgets('CampaignWizardBudgetOption renders tier details and cost', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignWizardBudgetOption(
              tierName: 'Growth Booster',
              cost: '₹5,000',
              subtitle: 'Estimated 35,000 impressions',
              value: 'growth',
              isSelected: true,
              onTap: () => selected = true,
            ),
          ),
        ),
      );

      expect(find.text('Growth Booster'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
      expect(find.text('Estimated 35,000 impressions'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      await tester.tap(find.text('Growth Booster'));
      expect(selected, isTrue);
    });

    testWidgets('CampaignRejectionBanner displays when campaign is rejected', (tester) async {
      const rejectedCampaign = AdItem(
        id: 'camp_1',
        advertiser: 'Acme Corp',
        gradientColors: [Colors.purple, Colors.pink],
        userId: 'user_1',
        title: 'Test Ad',
        description: 'Test Desc',
        imageUrl: '',
        ctaText: 'Learn More',
        ctaTarget: 'https://example.com',
        status: 'verification_rejected',
        moderationReason: 'Contains unverified claims.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CampaignRejectionBanner(existingCampaign: rejectedCampaign),
          ),
        ),
      );

      expect(find.text('Campaign Rejected - Action Required'), findsOneWidget);
      expect(find.text('Contains unverified claims.'), findsOneWidget);
    });

    testWidgets('CampaignRejectionBanner shrinks when not rejected', (tester) async {
      const approvedCampaign = AdItem(
        id: 'camp_2',
        advertiser: 'Acme Corp',
        gradientColors: [Colors.purple, Colors.pink],
        userId: 'user_1',
        title: 'Test Ad',
        description: 'Test Desc',
        imageUrl: '',
        ctaText: 'Learn More',
        ctaTarget: 'https://example.com',
        status: 'approved',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CampaignRejectionBanner(existingCampaign: approvedCampaign),
          ),
        ),
      );

      expect(find.text('Campaign Rejected - Action Required'), findsNothing);
    });

    testWidgets('CampaignWizardFormatStep renders format options properly', (tester) async {
      final adFormat = 'video_sponsor'.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CampaignWizardFormatStep(
                existingCampaign: null,
                adFormat: adFormat,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Campaign Placement & Format'), findsOneWidget);
      expect(find.text('Video Sponsor Ads'), findsOneWidget);
      expect(find.text('Skippable Video'), findsOneWidget);
      expect(find.text('Combined 4-in-1 Video Sponsor Suite (POPULAR)'), findsOneWidget);

      await tester.tap(find.text('Skippable Video'));
      await tester.pump();
      expect(adFormat.value, 'skippable');
      expect(find.text('Combined 4-in-1 Video Sponsor Suite (POPULAR)'), findsNothing);
    });

    testWidgets('CampaignWizard stepper chips in LayoutBuilder updates with Obx without GetX misuse errors', (tester) async {
      final currentStep = 1.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 640;
                return Obx(() {
                  final step = currentStep.value;
                  final tabs = [
                    CampaignWizardStepTab(
                      stepIndex: 1,
                      title: '1. Format & Objective',
                      icon: Icons.grid_view_rounded,
                      currentStep: step,
                      onTap: () => currentStep.value = 1,
                      isExpanded: !isCompact,
                    ),
                    const SizedBox(width: 8),
                    CampaignWizardStepTab(
                      stepIndex: 2,
                      title: '2. Creatives & Media',
                      icon: Icons.video_file_rounded,
                      currentStep: step,
                      onTap: () => currentStep.value = 2,
                      isExpanded: !isCompact,
                    ),
                  ];

                  if (isCompact) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: tabs),
                    );
                  }

                  return Row(children: tabs);
                });
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1. Format & Objective'), findsOneWidget);
      expect(find.text('2. Creatives & Media'), findsOneWidget);

      currentStep.value = 2;
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
