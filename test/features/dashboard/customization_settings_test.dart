import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Channel Customization Settings - Visibility & Like/Dislike Counts', () {
    test('Channel.fromMap accurately parses visibility and like/dislike counts', () {
      final data = <String, dynamic>{
        'name': 'Truth Channel',
        'visibility': 'Unlisted',
        'showLikeCount': false,
        'showDislikeCount': false,
      };

      final channel = Channel.fromMap(data, 'channel-1');

      expect(channel.visibility, 'Unlisted');
      expect(channel.showLikeCount, false);
      expect(channel.showDislikeCount, false);
    });

    test('Channel.fromMap falls back correctly when fields are missing', () {
      final dataPublic = <String, dynamic>{
        'name': 'Public Default',
        'isPublic': true,
      };

      final channelPublic = Channel.fromMap(dataPublic, 'channel-pub');
      expect(channelPublic.visibility, 'Public');
      expect(channelPublic.showLikeCount, true);
      expect(channelPublic.showDislikeCount, true);

      final dataPrivate = <String, dynamic>{
        'name': 'Private Fallback',
        'isPublic': false,
      };

      final channelPrivate = Channel.fromMap(dataPrivate, 'channel-priv');
      expect(channelPrivate.visibility, 'Private');
      expect(channelPrivate.showLikeCount, true);
      expect(channelPrivate.showDislikeCount, true);
    });

    test('Channel.toMap serializes visibility and counts accurately', () {
      final channel = Channel(
        id: 'channel-test',
        name: 'Test Channel',
        nameLowercase: 'test channel',
        handle: '@testchannel',
        handleLowercase: '@testchannel',
        description: 'Testing channel settings',
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        ownerId: 'owner-123',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        visibility: 'Unlisted',
        showLikeCount: false,
        showDislikeCount: false,
      );

      final map = channel.toMap();
      expect(map['visibility'], 'Unlisted');
      expect(map['isPublic'], false);
      expect(map['showLikeCount'], false);
      expect(map['showDislikeCount'], false);
    });

    test('Channel.copyWith updates visibility, showLikeCount, and showDislikeCount', () {
      final original = Channel.fromMap({
        'name': 'Original Channel',
        'visibility': 'Public',
        'showLikeCount': true,
        'showDislikeCount': true,
      }, 'orig-1');

      final updated = original.copyWith(
        visibility: 'Private',
        showLikeCount: false,
        showDislikeCount: false,
      );

      expect(updated.visibility, 'Private');
      expect(updated.showLikeCount, false);
      expect(updated.showDislikeCount, false);
    });

    test('CustomizationController manages visibility and sets isPublic synchronously', () {
      final controller = CustomizationController(
        channelId: 'test-ch-id',
        ownerId: 'test-owner-id',
      );

      expect(controller.visibility.value, 'Public');
      expect(controller.isPublic.value, true);
      expect(controller.showLikeCount.value, true);
      expect(controller.showDislikeCount.value, true);

      controller.setVisibility('Unlisted');
      expect(controller.visibility.value, 'Unlisted');
      expect(controller.isPublic.value, false);

      controller.setVisibility('Private');
      expect(controller.visibility.value, 'Private');
      expect(controller.isPublic.value, false);

      controller.setVisibility('Public');
      expect(controller.visibility.value, 'Public');
      expect(controller.isPublic.value, true);

      controller.showLikeCount.value = false;
      controller.showDislikeCount.value = false;
      expect(controller.showLikeCount.value, false);
      expect(controller.showDislikeCount.value, false);

      controller.onClose();
    });
  });
}
