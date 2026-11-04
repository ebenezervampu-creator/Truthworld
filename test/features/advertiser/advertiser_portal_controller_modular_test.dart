import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
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

  group('AdvertiserPortalController Modular Tests', () {
    test('instantiates with proper default navigation and tabs', () {
      final controller = Get.put(AdvertiserPortalController());

      expect(controller.selectedIndex.value, 0);
      expect(controller.selectedMetric.value, 'spend');
      expect(controller.tabTitles.length, 10);
      expect(controller.tabTitles.first, 'Advertiser Dashboard');
      expect(controller.tabTitles.last, 'Brand Settings');
    });

    test('AdvertiserLanguagesMixin provides comprehensive language lookups', () {
      final controller = Get.put(AdvertiserPortalController());

      expect(controller.supportedLanguages.isNotEmpty, isTrue);
      expect(controller.supportedAudioLanguages.length, 78);
      expect(controller.getLanguageName('en'), 'English');
      expect(controller.getLanguageName('hi'), 'Hindi');
      expect(controller.getLanguageName('es'), 'Spanish');
      expect(controller.getLanguageName('unknown_code'), 'UNKNOWN_CODE');
    });

    test('AdvertiserSubtitlesMixin loads default cues and exports valid WEBVTT', () {
      final controller = Get.put(AdvertiserPortalController());
      const testAd = AdItem(
        id: 'ad_test_1',
        userId: 'user_test_1',
        title: 'Great Products',
        advertiser: 'Acme Corp',
        description: 'Best items in the world',
        imageUrl: 'https://example.com/image.jpg',
        ctaText: 'Shop Now',
        ctaTarget: 'https://example.com',
        gradientColors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        videoUrl: 'https://example.com/video.mp4',
        adType: 'video',
      );

      controller.loadCuesForAd(testAd, 'en');

      expect(controller.currentSubtitleCues.length, 3);
      expect(controller.currentSubtitleCues.first['text'], 'Welcome to Acme Corp!');
      expect(controller.currentSubtitleCues.last['text'], 'Click the link to Shop Now!');

      final vtt = controller.exportCuesToVtt();
      expect(vtt.startsWith('WEBVTT'), isTrue);
      expect(vtt.contains('Welcome to Acme Corp!'), isTrue);
    });

    test('AdvertiserCampaignManagementMixin manages audience presets', () {
      final controller = Get.put(AdvertiserPortalController());
      final initialCount = controller.audiencePresets.length;

      final newPreset = {
        'id': 'test_aud_99',
        'name': 'AI Researchers',
        'ageMin': 22,
        'ageMax': 50,
        'genders': ['All'],
        'locations': ['India', 'USA'],
        'interests': ['AI', 'Robotics'],
        'estimatedReach': '500K Viewers',
      };

      controller.createAudiencePreset(newPreset);
      expect(controller.audiencePresets.length, initialCount + 1);
      expect(controller.audiencePresets.first['name'], 'AI Researchers');

      controller.deleteAudiencePreset('test_aud_99');
      expect(controller.audiencePresets.length, initialCount);
    });

    test('AdvertiserCampaignManagementMixin manages creator sponsorships', () {
      final controller = Get.put(AdvertiserPortalController());
      final initialCount = controller.sponsorshipProposals.length;

      final proposal = {
        'id': 'prop_test_99',
        'creatorId': 'cr_1',
        'creatorName': 'TechVerse Daily',
        'campaignTitle': 'Truthworld Beta',
        'format': '15s Mid-roll Sponsor',
        'offeredAmount': 4000.0,
        'date': 'Today',
        'status': 'Pending',
        'deliverableUrl': '',
      };

      controller.sendSponsorshipProposal(proposal);
      expect(controller.sponsorshipProposals.length, initialCount + 1);
      expect(controller.sponsorshipProposals.first['id'], 'prop_test_99');

      controller.cancelProposal('prop_test_99');
      expect(controller.sponsorshipProposals.length, initialCount);
    });

    test('AdvertiserCampaignManagementMixin manages creative assets', () {
      final controller = Get.put(AdvertiserPortalController());
      final initialCount = controller.creativeAssetsList.length;

      final asset = {
        'id': 'asset_test_99',
        'title': 'Test Promotional Banner',
        'type': 'Banner',
        'resolution': '1920x1080',
        'duration': 'Static',
        'format': 'PNG',
        'size': '2.4 MB',
        'url': 'https://example.com/banner.png',
        'date': 'Today',
        'campaignUsage': 0,
      };

      controller.addCreativeAsset(asset);
      expect(controller.creativeAssetsList.length, initialCount + 1);
      expect(controller.creativeAssetsList.first['title'], 'Test Promotional Banner');

      controller.deleteCreativeAsset('asset_test_99');
      expect(controller.creativeAssetsList.length, initialCount);
    });

    test('AdvertiserCampaignManagementMixin manages brand settings and team members', () {
      final controller = Get.put(AdvertiserPortalController());

      controller.saveBrandSettings(
        name: 'TruthWorld Global',
        tagline: 'Truth Prevails',
        website: 'https://truthworld.org',
        email: 'contact@truthworld.org',
        category: 'Media & Technology',
      );

      expect(controller.brandName.value, 'TruthWorld Global');
      expect(controller.brandTagline.value, 'Truth Prevails');

      final initialTeamCount = controller.teamMembers.length;
      controller.inviteTeamMember('Test Member', 'test@truthworld.org', 'Editor');
      expect(controller.teamMembers.length, initialTeamCount + 1);

      controller.removeTeamMember('test@truthworld.org');
      expect(controller.teamMembers.length, initialTeamCount);

      final oldApiKey = controller.conversionApiKey.value;
      controller.regenerateApiKey();
      expect(controller.conversionApiKey.value, isNot(equals(oldApiKey)));
    });

    test('AdvertiserBillingMixin manages wallet and billing profile fields', () {
      final controller = Get.put(AdvertiserPortalController());

      expect(controller.walletBalance.value, 0.0);
      expect(controller.autoReloadThreshold.value, 200.0);
      expect(controller.autoReloadAmount.value, 2000.0);

      controller.saveBillingDetails(
        company: 'TruthWorld Media Pvt Ltd',
        gstin: '29ABCDE1234F1Z5',
        address: 'Bangalore, India',
        email: 'billing@truthworld.org',
      );

      expect(controller.billingCompanyName.value, 'TruthWorld Media Pvt Ltd');
      expect(controller.billingGstin.value, '29ABCDE1234F1Z5');
      expect(controller.billingAddress.value, 'Bangalore, India');
      expect(controller.billingEmail.value, 'billing@truthworld.org');
    });
  });
}
