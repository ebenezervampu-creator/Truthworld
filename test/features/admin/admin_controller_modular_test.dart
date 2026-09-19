import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';

import '../../test_helpers/mock_firebase.dart';

class MockAdminController extends AdminController {
  bool refreshCalled = false;

  @override
  Future<void> refreshAllData() async {
    refreshCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('AdminRolesConfig & Tab Permissions Tests', () {
    test('Role constants and owner configurations are properly loaded', () {
      expect(AdminRolesConfig.allRoleNames.length, 8);
      expect(AdminRolesConfig.allRoleNames, contains('Super Admin'));
      expect(AdminRolesConfig.allRoleNames, contains('Content Moderator'));
      expect(AdminRolesConfig.allRoleNames, contains('Trust & Safety Reviewer'));

      expect(AdminRolesConfig.authorizedOwnerEmails, isNotEmpty);
      expect(AdminRolesConfig.ownerEmail, isNotEmpty);
    });

    test('isTabAllowed rejects non-admin users immediately', () {
      final allowed = AdminRolesConfig.isTabAllowed(
        tabId: 'videos',
        isAdmin: false,
        isPrimaryOwner: false,
        currentAdminEmail: 'user@test.com',
        currentAdminRole: 'Content Moderator',
        currentAdminRoles: ['Content Moderator'],
      );
      expect(allowed, isFalse);
    });

    test('Super Admin has access to all standard tabs', () {
      final allowedTabs = AdminRolesConfig.getAllowedTabs(
        isPrimaryOwner: false,
        currentAdminEmail: 'super@test.com',
        currentAdminRole: 'Super Admin',
        currentAdminRoles: ['Super Admin'],
      );

      expect(allowedTabs, contains('dashboard'));
      expect(allowedTabs, contains('videos'));
      expect(allowedTabs, contains('users'));
      expect(allowedTabs, contains('team'));
      expect(allowedTabs, contains('security'));
      expect(allowedTabs, contains('analytics'));
    });

    test('Content Moderator only has access to moderation queues', () {
      final allowedTabs = AdminRolesConfig.getAllowedTabs(
        isPrimaryOwner: false,
        currentAdminEmail: 'mod@test.com',
        currentAdminRole: 'Content Moderator',
        currentAdminRoles: ['Content Moderator'],
      );

      expect(allowedTabs, contains('dashboard'));
      expect(allowedTabs, contains('videos'));
      expect(allowedTabs, contains('topics'));
      expect(allowedTabs, contains('images'));
      expect(allowedTabs, contains('channels'));

      // Should NOT have access to sensitive tabs
      expect(allowedTabs.contains('team'), isFalse);
      expect(allowedTabs.contains('security'), isFalse);
      expect(allowedTabs.contains('users'), isFalse);
      expect(allowedTabs.contains('ads'), isFalse);
    });

    test('Language requests tab is strictly restricted to primary owner', () {
      final modAllowed = AdminRolesConfig.isTabAllowed(
        tabId: 'language_requests',
        isAdmin: true,
        isPrimaryOwner: false,
        currentAdminEmail: 'super@test.com',
        currentAdminRole: 'Super Admin',
        currentAdminRoles: ['Super Admin'],
      );
      expect(modAllowed, isFalse);

      final ownerAllowed = AdminRolesConfig.isTabAllowed(
        tabId: 'language_requests',
        isAdmin: true,
        isPrimaryOwner: true,
        currentAdminEmail: AdminRolesConfig.ownerEmail,
        currentAdminRole: 'Super Admin',
        currentAdminRoles: ['Super Admin'],
      );
      expect(ownerAllowed, isTrue);
    });

    test('Help tab is universally allowed for all logged-in administrators', () {
      final allowed = AdminRolesConfig.isTabAllowed(
        tabId: 'help',
        isAdmin: true,
        isPrimaryOwner: false,
        currentAdminEmail: 'custom@test.com',
        currentAdminRole: 'Custom Reviewer',
        currentAdminRoles: ['Custom Reviewer'],
      );
      expect(allowed, isTrue);
    });
  });

  group('AdminModerationModesMixin Tests', () {
    test('Moderation mode observables default to false and can be updated', () {
      final controller = MockAdminController();

      expect(controller.rxBypassVideos.value, isFalse);
      expect(controller.rxBypassAds.value, isFalse);
      expect(controller.rxBypassChannelBanners.value, isFalse);

      controller.rxBypassVideos.value = true;
      controller.rxBypassAds.value = true;

      expect(controller.rxBypassVideos.value, isTrue);
      expect(controller.rxBypassAds.value, isTrue);
    });

    test('applyModerationModes correctly parses Firestore document fields', () {
      final controller = MockAdminController();

      controller.applyModerationModes({
        'videos': true,
        'ads': true,
        'thumbnails': true,
        'channelBanner': true,
        'avatar': false,
        'community': true,
        'topics': true,
        'playlists': false,
      });

      expect(controller.rxBypassVideos.value, isTrue);
      expect(controller.rxBypassAds.value, isTrue);
      expect(controller.rxBypassVideoThumbnails.value, isTrue);
      expect(controller.rxBypassChannelBanners.value, isTrue);
      expect(controller.rxBypassChannelAvatars.value, isFalse);
      expect(controller.rxBypassCommunityPosts.value, isTrue);
      expect(controller.rxBypassTopicThumbnails.value, isTrue);
      expect(controller.rxBypassPlaylistThumbnails.value, isFalse);
    });
  });

  group('AdminQueueCombiner Tests', () {
    test('combineImagesAndPosts excludes topics and categorizes items correctly', () {
      final rawFlagged = [
        {'id': 'img_1', 'category': 'Channel Banner', 'createdAt': '2026-01-01T10:00:00Z'},
        {'id': 'img_2', 'category': 'topic_header', 'path': 'topics/health.png'}, // should be excluded
      ];

      final rawVerification = [
        {'id': 'ver_1', 'category': 'Channel Avatar', 'createdAt': '2026-01-02T10:00:00Z'},
      ];

      final rawCommunity = [
        {'id': 'comm_1', 'content': 'Hello world', 'createdAt': '2026-01-03T10:00:00Z'},
      ];

      final rawPlaylists = [
        {'id': 'pl_1', 'thumbnailUrl': 'https://example.com/thumb.jpg', 'createdAt': '2026-01-04T10:00:00Z'},
      ];

      final combined = AdminQueueCombiner.combineImagesAndPosts(
        rawFlaggedImages: rawFlagged,
        rawVerificationQueue: rawVerification,
        rawCommunityPosts: rawCommunity,
        rawPlaylistThumbnails: rawPlaylists,
      );

      expect(combined.length, 4);
      expect(combined.any((item) => item['id'] == 'img_2'), isFalse); // excluded topic item
      expect(combined.first['id'], 'pl_1'); // newest sorted first
    });

    test('combineReports includes synthetic reports from flagged videos', () {
      final rawReports = [
        {'id': 'rep_1', 'reason': 'Spam', 'createdAt': '2026-01-01T10:00:00Z'},
      ];

      final videos = [
        {
          'id': 'vid_flagged_1',
          'channelId': 'ch_1',
          'isReported': true,
          'reportReason': 'Hate Speech',
          'createdAt': '2026-01-02T10:00:00Z',
        },
        {
          'id': 'vid_normal_2',
          'isReported': false,
        },
      ];

      final combined = AdminQueueCombiner.combineReports(
        rawReportsDocs: rawReports,
        rawVideoReportsDocs: [],
        rawVideoReportsAltDocs: [],
        videos: videos,
      );

      expect(combined.length, 2);
      expect(combined.any((r) => r['id'] == 'reported_video_vid_flagged_1'), isTrue);
      expect(combined.any((r) => r['id'] == 'reported_video_vid_normal_2'), isFalse);
    });

    test('combineAuditLogs merges rejected images and admin actions into audit records', () {
      final rejectedImages = [
        {
          'id': 'rej_1',
          'action': 'Quarantine NSFW',
          'adminEmail': 'mod@truthworld.com',
          'rejectedAt': '2026-01-01T12:00:00Z',
        }
      ];

      final actionLogs = [
        {
          'id': 'act_1',
          'action': 'ban_user',
          'adminEmail': 'admin@truthworld.com',
          'createdAt': '2026-01-02T12:00:00Z',
        }
      ];

      final combined = AdminQueueCombiner.combineAuditLogs(
        rawRejectedImageLogs: rejectedImages,
        rawActionLogs: actionLogs,
      );

      expect(combined.length, 2);
      expect(combined.first['action'], 'BAN USER');
      expect(combined.first['logType'], 'admin_action');
      expect(combined.last['displayType'], 'Image Quarantine');
    });

    test('parseTimestamp handles Timestamp, ISO string, int, and fallbacks', () {
      final ts = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
      expect(AdminQueueCombiner.parseTimestamp(ts).millisecondsSinceEpoch, 1700000000000);

      const iso = '2026-05-10T14:30:00Z';
      expect(AdminQueueCombiner.parseTimestamp(iso).year, 2026);

      expect(AdminQueueCombiner.parseTimestamp(1700000000000).millisecondsSinceEpoch, 1700000000000);
      expect(AdminQueueCombiner.parseTimestamp(null), DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('AdminQueueBuffer & SubscriptionsManager Tests', () {
    test('AdminQueueBuffer manages raw buffers and combines reactivity', () {
      final buffer = AdminQueueBuffer();
      final images = <Map<String, dynamic>>[].obs;
      final pendingImages = 0.obs;
      final totalImages = 0.obs;

      buffer.combineImagesAndPosts(
        images: images,
        pendingImages: pendingImages,
        totalImages: totalImages,
        isImagePostPending: (item) => item['status'] == 'pending',
        communityList: [
          {'id': 'c1', 'status': 'pending', 'createdAt': '2026-01-01T00:00:00Z'}
        ],
      );

      expect(images.length, 1);
      expect(pendingImages.value, 1);
      expect(totalImages.value, 1);
    });

    test('AdminSubscriptionsManager lifecycle stops cleanly without error', () {
      final manager = AdminSubscriptionsManager();
      expect(manager.hasActiveSubscriptions, isFalse);

      manager.stopSubscriptions(
        stopAdminMembersSubscription: () {},
        stopLanguageRequestsSubscription: () {},
        stopAppealsSubscription: () {},
      );

      expect(manager.hasActiveSubscriptions, isFalse);
    });
  });

  group('AdminController Coordinator Tests', () {
    test('clearSelectedItems resets all selected models to null', () {
      final controller = MockAdminController();

      controller.selectedVideo.value = {'id': 'v1'};
      controller.selectedImage.value = {'id': 'i1'};
      controller.selectedChannel.value = {'id': 'c1'};
      controller.selectedReport.value = {'id': 'r1'};
      controller.selectedTopic.value = {'id': 't1'};
      controller.selectedAd.value = {'id': 'a1'};

      controller.clearSelectedItems();

      expect(controller.selectedVideo.value, isNull);
      expect(controller.selectedImage.value, isNull);
      expect(controller.selectedChannel.value, isNull);
      expect(controller.selectedReport.value, isNull);
      expect(controller.selectedTopic.value, isNull);
      expect(controller.selectedAd.value, isNull);
    });

    test('isTabAllowed delegates to AdminRolesConfig properly', () {
      final controller = MockAdminController();
      controller.isAdmin.value = true;
      controller.currentAdminRole.value = 'Super Admin';
      controller.currentAdminRoles.assignAll(['Super Admin']);

      expect(controller.isTabAllowed('videos'), isTrue);
      expect(controller.isTabAllowed('security'), isTrue);
      expect(controller.isTabAllowed('help'), isTrue);

      final allowedTabs = controller.getAllowedTabs();
      expect(allowedTabs, contains('videos'));
      expect(allowedTabs, contains('team'));
    });
  });
}
