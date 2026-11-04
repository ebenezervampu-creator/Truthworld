import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/controllers/moderation/admin_moderation_barrel.dart';

import '../../test_helpers/mock_firebase.dart';

class TestAdminController extends AdminController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('AdminModerationPredicates Unit Tests', () {
    test('Video predicates correctly identify video states', () {
      final pendingVideo1 = {
        'id': 'v1',
        'status': 'pending',
        'moderation': {'status': 'pending'},
      };
      final pendingVideo2 = {
        'id': 'v2',
        'moderation': {
          'violationCategories': ['timeout_passthrough'],
        },
      };
      final approvedVideo = {
        'id': 'v3',
        'status': 'published',
        'isApproved': true,
        'moderation': {'status': 'approved'},
      };
      final rejectedVideo = {
        'id': 'v4',
        'status': 'rejected',
        'moderation': {'status': 'rejected'},
      };

      expect(AdminModerationPredicates.isVideoPending(pendingVideo1), isTrue);
      expect(AdminModerationPredicates.isVideoPending(pendingVideo2), isTrue);
      expect(AdminModerationPredicates.isVideoApproved(pendingVideo1), isFalse);

      expect(AdminModerationPredicates.isVideoApproved(approvedVideo), isTrue);
      expect(AdminModerationPredicates.isVideoPending(approvedVideo), isFalse);
      expect(AdminModerationPredicates.isVideoRejected(approvedVideo), isFalse);

      expect(AdminModerationPredicates.isVideoRejected(rejectedVideo), isTrue);
      expect(AdminModerationPredicates.isVideoPending(rejectedVideo), isFalse);
      expect(AdminModerationPredicates.isVideoApproved(rejectedVideo), isFalse);
    });

    test('Channel predicates correctly identify channel states', () {
      final pendingChannel = {
        'id': 'c1',
        'status': 'underReview',
        'isVerified': false,
      };
      final activeChannel = {
        'id': 'c2',
        'status': 'active',
        'isVerified': true,
        'geminiApproved': true,
      };
      final rejectedChannel = {
        'id': 'c3',
        'status': 'verificationRejected',
      };

      expect(
        AdminModerationPredicates.isChannelPending(pendingChannel),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isChannelApproved(pendingChannel),
        isFalse,
      );

      expect(AdminModerationPredicates.isChannelActive(activeChannel), isTrue);
      expect(
        AdminModerationPredicates.isChannelApproved(activeChannel),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isChannelPending(activeChannel),
        isFalse,
      );

      expect(
        AdminModerationPredicates.isChannelRejected(rejectedChannel),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isChannelPending(rejectedChannel),
        isFalse,
      );

      final heldChannel = {
        'id': 'c4',
        'status': 'onHold',
      };
      final heldChannelAlt = {
        'id': 'c5',
        'status': 'hold',
      };

      expect(AdminModerationPredicates.isChannelOnHold(heldChannel), isTrue);
      expect(AdminModerationPredicates.isChannelOnHold(heldChannelAlt), isTrue);
      expect(AdminModerationPredicates.isChannelPending(heldChannel), isFalse);
      expect(AdminModerationPredicates.isChannelActive(heldChannel), isFalse);
      expect(AdminModerationPredicates.isChannelRejected(heldChannel), isFalse);
      expect(AdminModerationPredicates.isChannelOnHold(activeChannel), isFalse);
      expect(AdminModerationPredicates.isChannelOnHold(pendingChannel), isFalse);
      expect(AdminModerationPredicates.isChannelOnHold(rejectedChannel), isFalse);
    });

    test('Topic predicates correctly identify topic states', () {
      final pendingTopic = {
        'id': 't1',
        'status': 'pending',
        'geminiApproved': false,
      };
      final approvedTopic = {
        'id': 't2',
        'status': 'active',
        'isApproved': true,
        'geminiApproved': true,
      };
      final rejectedTopic = {
        'id': 't3',
        'status': 'verification_rejected',
      };

      expect(AdminModerationPredicates.isTopicPending(pendingTopic), isTrue);
      expect(AdminModerationPredicates.isTopicApproved(pendingTopic), isFalse);

      expect(AdminModerationPredicates.isTopicApproved(approvedTopic), isTrue);
      expect(AdminModerationPredicates.isTopicPending(approvedTopic), isFalse);

      expect(AdminModerationPredicates.isTopicRejected(rejectedTopic), isTrue);
      expect(AdminModerationPredicates.isTopicPending(rejectedTopic), isFalse);
    });

    test('Image predicates correctly identify image states', () {
      final pendingImage = {
        'id': 'img1',
        'status': 'PENDING_REVIEW',
        'moderation': {'status': 'PENDING'},
      };
      final approvedImage = {
        'id': 'img2',
        'status': 'APPROVED',
        'isApproved': true,
      };
      final rejectedImage = {
        'id': 'img3',
        'status': 'REJECTED',
        'moderation': {'status': 'REJECTED'},
      };

      expect(
        AdminModerationPredicates.isImagePostPending(pendingImage),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isImagePostApproved(pendingImage),
        isFalse,
      );

      expect(
        AdminModerationPredicates.isImagePostApproved(approvedImage),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isImagePostPending(approvedImage),
        isFalse,
      );

      expect(
        AdminModerationPredicates.isImagePostRejected(rejectedImage),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isImagePostPending(rejectedImage),
        isFalse,
      );
    });

    test('Report predicates correctly identify report states', () {
      final pendingReport = {
        'id': 'rep1',
        'status': 'pending',
        'isResolved': false,
      };
      final resolvedReport = {
        'id': 'rep2',
        'status': 'resolved',
        'isResolved': true,
      };

      expect(
        AdminModerationPredicates.isReportPending(pendingReport),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isReportResolved(pendingReport),
        isFalse,
      );

      expect(
        AdminModerationPredicates.isReportResolved(resolvedReport),
        isTrue,
      );
      expect(
        AdminModerationPredicates.isReportPending(resolvedReport),
        isFalse,
      );
    });
  });

  group('AdminModerationFilters Unit Tests', () {
    final testVideos = [
      {
        'id': 'v1',
        'title': 'AI Technology Review',
        'category': 'Technology',
        'userId': 'u100',
        'status': 'pending',
      },
      {
        'id': 'v2',
        'title': 'World Travel Guide',
        'category': 'Travel',
        'userId': 'u200',
        'status': 'published',
        'isApproved': true,
      },
      {
        'id': 'v3',
        'title': 'Cooking Secrets',
        'category': 'Food',
        'userId': 'u300',
        'status': 'rejected',
        'moderation': {'status': 'rejected'},
      },
    ];

    test('filterVideos filters by status tab', () {
      final pending = AdminModerationFilters.filterVideos(
        videos: testVideos,
        searchQuery: '',
        filterCategory: '',
        videoFilterTab: 'pending',
      );
      expect(pending.length, equals(1));
      expect(pending.first['id'], equals('v1'));

      final approved = AdminModerationFilters.filterVideos(
        videos: testVideos,
        searchQuery: '',
        filterCategory: '',
        videoFilterTab: 'approved',
      );
      expect(approved.length, equals(1));
      expect(approved.first['id'], equals('v2'));

      final rejected = AdminModerationFilters.filterVideos(
        videos: testVideos,
        searchQuery: '',
        filterCategory: '',
        videoFilterTab: 'rejected',
      );
      expect(rejected.length, equals(1));
      expect(rejected.first['id'], equals('v3'));
    });

    test('filterVideos filters by category and search query', () {
      final tech = AdminModerationFilters.filterVideos(
        videos: testVideos,
        searchQuery: '',
        filterCategory: 'Technology',
        videoFilterTab: 'all',
      );
      expect(tech.length, equals(1));
      expect(tech.first['category'], equals('Technology'));

      final search = AdminModerationFilters.filterVideos(
        videos: testVideos,
        searchQuery: 'Travel',
        filterCategory: '',
        videoFilterTab: 'all',
      );
      expect(search.length, equals(1));
      expect(search.first['title'], contains('Travel'));
    });

    test('filterChannels filters by tab and query', () {
      final testChannels = [
        {
          'id': 'c1',
          'name': 'Science Daily',
          'handle': '@sciencedaily',
          'status': 'pending',
          'isVerified': false,
        },
        {
          'id': 'c2',
          'name': 'History Buffs',
          'handle': '@history',
          'status': 'active',
          'isVerified': true,
        },
        {
          'id': 'c3',
          'name': 'Nature Explorer',
          'handle': '@nature',
          'status': 'onHold',
          'isVerified': false,
        },
      ];

      final filteredPending = AdminModerationFilters.filterChannels(
        channels: testChannels,
        searchQuery: '',
        channelFilterTab: 'pending',
      );
      expect(filteredPending.length, equals(1));
      expect(filteredPending.first['id'], equals('c1'));

      final filteredHold = AdminModerationFilters.filterChannels(
        channels: testChannels,
        searchQuery: '',
        channelFilterTab: 'hold',
      );
      expect(filteredHold.length, equals(1));
      expect(filteredHold.first['id'], equals('c3'));

      final filteredQuery = AdminModerationFilters.filterChannels(
        channels: testChannels,
        searchQuery: 'history',
        channelFilterTab: 'all',
      );
      expect(filteredQuery.length, equals(1));
      expect(filteredQuery.first['name'], equals('History Buffs'));
    });
  });

  group('AdminContentModerationMixin Selection Tests', () {
    late TestAdminController controller;

    setUp(() {
      controller = TestAdminController();
      Get.put<AdminController>(controller);
    });

    test('toggleItemSelection, selectAllItems and clearSelection work correctly', () {
      expect(controller.selectedItemIds.isEmpty, isTrue);

      controller.toggleItemSelection('item1');
      expect(controller.selectedItemIds.contains('item1'), isTrue);
      expect(controller.selectedItemIds.length, equals(1));

      controller.toggleItemSelection('item1');
      expect(controller.selectedItemIds.contains('item1'), isFalse);
      expect(controller.selectedItemIds.isEmpty, isTrue);

      controller.selectAllItems([
        {'id': 'item1'},
        {'id': 'item2'},
        {'id': 'item3'},
      ]);
      expect(controller.selectedItemIds.length, equals(3));
      expect(controller.selectedItemIds.contains('item2'), isTrue);

      controller.clearSelection();
      expect(controller.selectedItemIds.isEmpty, isTrue);
    });

    test('filteredVideos getter on mixin uses AdminModerationFilters correctly', () {
      controller.videos.assignAll([
        {
          'id': 'v1',
          'title': 'Flutter 101',
          'category': 'Dev',
          'status': 'pending',
        },
        {
          'id': 'v2',
          'title': 'Dart 101',
          'category': 'Dev',
          'status': 'published',
          'isApproved': true,
        },
      ]);

      controller.videoFilterTab.value = 'all';
      controller.searchQuery.value = 'Dart';
      expect(controller.filteredVideos.length, equals(1));
      expect(controller.filteredVideos.first['id'], equals('v2'));
    });
  });
}
