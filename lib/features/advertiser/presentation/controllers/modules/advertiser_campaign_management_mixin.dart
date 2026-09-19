import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

mixin AdvertiserCampaignManagementMixin {
  // 1. Audience Presets
  final RxList<Map<String, dynamic>> audiencePresets = <Map<String, dynamic>>[
    {
      'id': 'aud_1',
      'name': 'Tech & Innovation Enthusiasts',
      'ageMin': 18,
      'ageMax': 35,
      'genders': ['All'],
      'locations': ['India', 'United States', 'UAE'],
      'interests': [
        'Technology',
        'AI & Machine Learning',
        'Startups',
        'Coding',
      ],
      'estimatedReach': '4.2M Viewers',
    },
    {
      'id': 'aud_2',
      'name': 'Digital Creators & Video Editors',
      'ageMin': 20,
      'ageMax': 45,
      'genders': ['All'],
      'locations': ['India', 'United Kingdom', 'Canada'],
      'interests': ['Video Production', 'Content Creation', 'Audio Editing'],
      'estimatedReach': '1.8M Viewers',
    },
    {
      'id': 'aud_3',
      'name': 'Gaming & Livestream Fans',
      'ageMin': 16,
      'ageMax': 28,
      'genders': ['All'],
      'locations': ['India', 'Southeast Asia', 'Brazil'],
      'interests': ['Esports', 'Live Streaming', 'Gaming Reviews'],
      'estimatedReach': '6.5M Viewers',
    },
  ].obs;

  void createAudiencePreset(Map<String, dynamic> preset) {
    audiencePresets.insert(0, preset);
    AppSnackbar.show(
      'Audience Preset Created',
      'Targeting preset "${preset['name']}" is ready to apply to ad campaigns.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void deleteAudiencePreset(String id) {
    audiencePresets.removeWhere((p) => p['id'] == id);
    AppSnackbar.show(
      'Preset Removed',
      'Audience preset deleted.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  // 2. Creator Sponsorships
  final RxString selectedSponsorshipCategory = 'All'.obs;
  final RxList<Map<String, dynamic>> creatorsList = <Map<String, dynamic>>[
    {
      'id': 'cr_1',
      'name': 'TechVerse Daily',
      'handle': '@techversedaily',
      'category': 'Technology',
      'subscribers': '1.2M',
      'subscribersCount': 1200000,
      'avgViews': '280K',
      'engagement': '8.4%',
      'avatarColor': 0xFF3B82F6,
      'bio': 'Deep dives into futuristic AI, gadgets, and software tools.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 5000.0},
        {'type': 'Pinned Comment Link', 'price': 1500.0},
        {'type': 'Full Video Collaboration', 'price': 25000.0},
      ],
    },
    {
      'id': 'cr_2',
      'name': 'PixelCoders',
      'handle': '@pixelcoders',
      'category': 'Education',
      'subscribers': '680K',
      'subscribersCount': 680000,
      'avgViews': '95K',
      'engagement': '9.1%',
      'avatarColor': 0xFF10B981,
      'bio':
          'Software development tutorials, Flutter, Python and web engineering.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 3000.0},
        {'type': 'Pinned Comment Link', 'price': 1000.0},
      ],
    },
    {
      'id': 'cr_3',
      'name': 'Apex Gaming Realm',
      'handle': '@apexgaming',
      'category': 'Gaming',
      'subscribers': '2.4M',
      'subscribersCount': 2400000,
      'avgViews': '520K',
      'engagement': '12.3%',
      'avatarColor': 0xFFEF4444,
      'bio': 'Daily competitive gaming streams, tournaments, and reviews.',
      'packages': [
        {'type': 'Live Stream Shoutout', 'price': 4000.0},
        {'type': 'Banner Placement', 'price': 2500.0},
      ],
    },
    {
      'id': 'cr_4',
      'name': 'Global Chronicle',
      'handle': '@globalchronicle',
      'category': 'News & Media',
      'subscribers': '950K',
      'subscribersCount': 950000,
      'avgViews': '180K',
      'engagement': '7.2%',
      'avatarColor': 0xFFF59E0B,
      'bio': 'Unbiased geopolitical analysis and tech policy breakdowns.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 3500.0},
        {'type': 'Pinned Comment Link', 'price': 1200.0},
      ],
    },
    {
      'id': 'cr_5',
      'name': 'Creative Frame',
      'handle': '@creativeframe',
      'category': 'Lifestyle',
      'subscribers': '420K',
      'subscribersCount': 420000,
      'avgViews': '65K',
      'engagement': '8.8%',
      'avatarColor': 0xFF8B5CF6,
      'bio':
          'Filmmaking tips, camera gear, color grading, and creative storytelling.',
      'packages': [
        {'type': '15s Mid-roll Sponsor', 'price': 2000.0},
        {'type': 'Pinned Comment Link', 'price': 800.0},
      ],
    },
  ].obs;

  final RxList<Map<String, dynamic>> sponsorshipProposals =
      <Map<String, dynamic>>[
        {
          'id': 'prop_1',
          'creatorId': 'cr_1',
          'creatorName': 'TechVerse Daily',
          'campaignTitle': 'Truthworld Next Generation',
          'format': '15s Mid-roll Sponsor',
          'offeredAmount': 5000.0,
          'date': '05 Sep 2026',
          'status': 'Accepted',
          'deliverableUrl':
              'https://truthworld.org/watch?v=techverse_ai_future',
        },
        {
          'id': 'prop_2',
          'creatorId': 'cr_2',
          'creatorName': 'PixelCoders',
          'campaignTitle': 'Truthworld Creator Program',
          'format': 'Pinned Comment Link',
          'offeredAmount': 1000.0,
          'date': 'Yesterday',
          'status': 'Under Review',
          'deliverableUrl': '',
        },
      ].obs;

  void sendSponsorshipProposal(Map<String, dynamic> proposal) {
    sponsorshipProposals.insert(0, proposal);
    AppSnackbar.show(
      'Proposal Sent',
      'Sponsorship proposal dispatched to ${proposal['creatorName']}.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void cancelProposal(String id) {
    sponsorshipProposals.removeWhere((p) => p['id'] == id);
    AppSnackbar.show(
      'Proposal Cancelled',
      'Sponsorship proposal was retracted.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  // 3. Creative Assets
  final RxString selectedAssetCategory = 'All'.obs;
  final RxList<Map<String, dynamic>> creativeAssetsList =
      <Map<String, dynamic>>[
        {
          'id': 'asset_1',
          'title': 'Truthworld Next Gen 15s Bumper',
          'type': 'Video',
          'resolution': '1920x1080',
          'duration': '00:15',
          'format': 'MP4',
          'size': '14.8 MB',
          'url':
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
          'date': '01 Sep 2026',
          'campaignUsage': 2,
        },
        {
          'id': 'asset_2',
          'title': 'High-Conversion Feed Banner',
          'type': 'Banner',
          'resolution': '1200x628',
          'duration': 'Static',
          'format': 'PNG',
          'size': '1.2 MB',
          'url': 'https://picsum.photos/1200/628',
          'date': '28 Aug 2026',
          'campaignUsage': 3,
        },
        {
          'id': 'asset_3',
          'title': 'Truthworld Official Brandmark Vector',
          'type': 'Logo',
          'resolution': '512x512',
          'duration': 'Static',
          'format': 'SVG',
          'size': '140 KB',
          'url': 'https://picsum.photos/512/512',
          'date': '15 Aug 2026',
          'campaignUsage': 5,
        },
        {
          'id': 'asset_4',
          'title': 'Mobile Feed Square Promo',
          'type': 'Banner',
          'resolution': '1080x1080',
          'duration': 'Static',
          'format': 'WEBP',
          'size': '680 KB',
          'url': 'https://picsum.photos/1080/1080',
          'date': '10 Aug 2026',
          'campaignUsage': 1,
        },
      ].obs;

  void addCreativeAsset(Map<String, dynamic> asset) {
    creativeAssetsList.insert(0, asset);
    AppSnackbar.show(
      'Asset Uploaded',
      'Creative asset "${asset['title']}" saved to library.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void deleteCreativeAsset(String id) {
    creativeAssetsList.removeWhere((a) => a['id'] == id);
    AppSnackbar.show(
      'Asset Deleted',
      'Creative asset removed from your media library.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  // 4. A/B Testing & Optimization
  final RxList<Map<String, dynamic>> abExperimentsList = <Map<String, dynamic>>[
    {
      'id': 'exp_1',
      'title': 'Call-To-Action Copy Test',
      'campaign': 'Truthworld Next Generation',
      'variable': 'CTA Button',
      'status': 'Running',
      'trafficSplit': '50% / 50%',
      'startDate': '01 Sep 2026',
      'variantA': {
        'label': 'Variant A (Control)',
        'value': 'Learn More',
        'impressions': 12400,
        'clicks': 480,
        'ctr': 3.87,
        'conversions': 86,
      },
      'variantB': {
        'label': 'Variant B (Challenger)',
        'value': 'Get Started Free',
        'impressions': 12350,
        'clicks': 675,
        'ctr': 5.46,
        'conversions': 134,
      },
      'winner': 'Variant B (+41% higher CTR)',
      'confidence': '97.2% Statistical Confidence',
    },
    {
      'id': 'exp_2',
      'title': 'Headline Benefit vs Curiosity',
      'campaign': 'Truthworld Video Platform',
      'variable': 'Headline',
      'status': 'Concluded',
      'trafficSplit': '50% / 50%',
      'startDate': '20 Aug 2026',
      'variantA': {
        'label': 'Variant A (Benefit)',
        'value': 'Experience Uncensored Truth & Knowledge',
        'impressions': 25000,
        'clicks': 1120,
        'ctr': 4.48,
        'conversions': 240,
      },
      'variantB': {
        'label': 'Variant B (Curiosity)',
        'value': 'The Video Platform Big Tech Didnt Want Built',
        'impressions': 25000,
        'clicks': 1480,
        'ctr': 5.92,
        'conversions': 355,
      },
      'winner': 'Variant B (+32% higher CTR)',
      'confidence': '99.1% Statistical Confidence',
    },
  ].obs;

  void createAbExperiment(Map<String, dynamic> experiment) {
    abExperimentsList.insert(0, experiment);
    AppSnackbar.show(
      'A/B Test Launched',
      'Experiment "${experiment['title']}" is now splitting campaign traffic.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void declareExperimentWinner(String experimentId, String winningVariant) {
    final idx = abExperimentsList.indexWhere((e) => e['id'] == experimentId);
    if (idx != -1) {
      abExperimentsList[idx]['status'] = 'Concluded';
      abExperimentsList.refresh();
      AppSnackbar.show(
        'Winner Applied',
        '$winningVariant has been declared the winner and set as default.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    }
  }

  // 5. Brand Profile & Settings
  final RxString brandName = 'Truthworld'.obs;
  final RxString brandTagline = 'Truthworld Change the World'.obs;
  final RxString brandWebsite = 'https://truthworld.org'.obs;
  final RxString brandEmail = 'support@truthworld.org'.obs;
  final RxString brandCategory = 'Technology & Media'.obs;
  final RxBool isBrandVerified = true.obs;

  final RxBool lowBudgetAlert = true.obs;
  final RxBool dailyPerformanceDigest = true.obs;
  final RxBool campaignStatusNotifications = true.obs;
  final RxBool sponsorshipAlerts = true.obs;

  final RxString conversionApiKey = 'tw_live_ak_98a7b6c5d4e3f210a'.obs;

  final RxList<Map<String, dynamic>> teamMembers = <Map<String, dynamic>>[
    {
      'name': 'Ebenezer Vampu',
      'email': 'ebenezer@truthworld.org',
      'role': 'Owner (Full Access)',
      'status': 'Active',
    },
    {
      'name': 'Sarah Jenkins',
      'email': 'sarah.growth@truthworld.org',
      'role': 'Campaign Manager',
      'status': 'Active',
    },
    {
      'name': 'Alex Rivera',
      'email': 'finance@truthworld.org',
      'role': 'Billing Analyst',
      'status': 'Active',
    },
  ].obs;

  void saveBrandSettings({
    required String name,
    required String tagline,
    required String website,
    required String email,
    required String category,
  }) {
    brandName.value = name;
    brandTagline.value = tagline;
    brandWebsite.value = website;
    brandEmail.value = email;
    brandCategory.value = category;
    AppSnackbar.show(
      'Profile Saved',
      'Advertiser brand profile updated successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void inviteTeamMember(String name, String email, String role) {
    teamMembers.add({
      'name': name,
      'email': email,
      'role': role,
      'status': 'Invited',
    });
    AppSnackbar.show(
      'Invitation Sent',
      'An invitation to join Advertiser Studio was sent to $email.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void removeTeamMember(String email) {
    teamMembers.removeWhere((m) => m['email'] == email);
    AppSnackbar.show(
      'Member Removed',
      'User $email was removed from team access.',
      backgroundColor: AppColors.info,
      colorText: AppColors.textPrimary,
    );
  }

  void regenerateApiKey() {
    conversionApiKey.value =
        'tw_live_ak_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    AppSnackbar.show(
      'API Key Regenerated',
      'New conversion tracking key generated.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }
}
