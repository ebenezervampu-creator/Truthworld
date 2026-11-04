import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('Private, Members-Only & Subscribers-Only Video Visibility Policy Tests', () {
    final publicVideo = Video.fromMap({
      'title': 'Public Truth Document',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'channel_owner_123',
      'channelId': 'channel_123',
      'visibility': 'public',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_pub');

    final privateVideo = Video.fromMap({
      'title': 'Confidential Channel Video',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'channel_owner_123',
      'channelId': 'channel_123',
      'visibility': 'private',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_priv');

    final privateDraftVideo = Video.fromMap({
      'title': 'WIP Channel Video',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'channel_owner_123',
      'channelId': 'channel_123',
      'visibility': 'Private_Draft',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_priv_draft');

    final unlistedVideo = Video.fromMap({
      'title': 'Unlisted Video Link Only',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'channel_owner_123',
      'channelId': 'channel_123',
      'visibility': 'unlisted',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_unlisted');

    final membersOnlyVideo = Video.fromMap({
      'title': 'Exclusive Member Behind-The-Scenes',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'channel_owner_123',
      'channelId': 'channel_123',
      'visibility': 'members_only',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_members');

    final subscribersOnlyVideo = Video.fromMap({
      'title': 'Special Subscriber Q&A',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'channel_owner_123',
      'channelId': 'channel_123',
      'visibility': 'subscribers_only',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_subscribers');

    test('isPrivate identifies private and private_draft correctly regardless of case', () {
      expect(VideoVisibilityPolicy.isPrivate(publicVideo), isFalse);
      expect(VideoVisibilityPolicy.isPrivate(privateVideo), isTrue);
      expect(VideoVisibilityPolicy.isPrivate(privateDraftVideo), isTrue);
      expect(privateVideo.isPrivate, isTrue);
      expect(publicVideo.isPrivate, isFalse);
    });

    test('isMembersOnly and isSubscribersOnly identify visibility correctly', () {
      expect(VideoVisibilityPolicy.isMembersOnly(membersOnlyVideo), isTrue);
      expect(membersOnlyVideo.isMembersOnly, isTrue);
      expect(VideoVisibilityPolicy.isMembersOnly(publicVideo), isFalse);
      expect(publicVideo.isMembersOnly, isFalse);

      expect(VideoVisibilityPolicy.isSubscribersOnly(subscribersOnlyVideo), isTrue);
      expect(subscribersOnlyVideo.isSubscribersOnly, isTrue);
      expect(VideoVisibilityPolicy.isSubscribersOnly(publicVideo), isFalse);
      expect(publicVideo.isSubscribersOnly, isFalse);
    });

    test('isOwner recognizes channel owner by UID or channel ID', () {
      expect(
        VideoVisibilityPolicy.isOwner(privateVideo, viewerUid: 'channel_owner_123'),
        isTrue,
        reason: 'Viewer matching ownerId must be recognized as owner',
      );
      expect(
        VideoVisibilityPolicy.isOwner(privateVideo, viewerChannelId: 'channel_123'),
        isTrue,
        reason: 'Viewer matching channelId must be recognized as owner',
      );
      expect(
        VideoVisibilityPolicy.isOwner(privateVideo, viewerUid: 'stranger_456', viewerChannelId: 'other_channel'),
        isFalse,
        reason: 'Unrelated viewer must NOT be recognized as owner',
      );
      expect(
        VideoVisibilityPolicy.isOwner(privateVideo),
        isFalse,
        reason: 'Unauthenticated viewer must NOT be recognized as owner',
      );
    });

    test('canViewVideo allows ONLY channel owner when video is private', () {
      // Owner viewing private video
      expect(
        VideoVisibilityPolicy.canViewVideo(privateVideo, viewerUid: 'channel_owner_123'),
        isTrue,
        reason: 'Owner must be able to view their own private video',
      );

      // Non-owner viewing private video
      expect(
        VideoVisibilityPolicy.canViewVideo(privateVideo, viewerUid: 'visitor_999'),
        isFalse,
        reason: 'Visitor must NOT be able to view a private video',
      );

      // Public video viewable by anyone
      expect(
        VideoVisibilityPolicy.canViewVideo(publicVideo, viewerUid: 'visitor_999'),
        isTrue,
      );
    });

    test('canWatchVideo enforces playback gating rules correctly', () {
      // 1. Owner can watch everything
      expect(VideoVisibilityPolicy.canWatchVideo(privateVideo, isOwner: true), isTrue);
      expect(VideoVisibilityPolicy.canWatchVideo(membersOnlyVideo, isOwner: true), isTrue);
      expect(VideoVisibilityPolicy.canWatchVideo(subscribersOnlyVideo, isOwner: true), isTrue);
      expect(VideoVisibilityPolicy.canWatchVideo(publicVideo, isOwner: true), isTrue);

      // 2. Private video: blocked for non-owners even if member or subscriber
      expect(VideoVisibilityPolicy.canWatchVideo(privateVideo, isMember: true), isFalse);
      expect(VideoVisibilityPolicy.canWatchVideo(privateVideo, isSubscriber: true), isFalse);
      expect(VideoVisibilityPolicy.canWatchVideo(privateVideo), isFalse);

      // 3. Members-only video: watchable ONLY by members or owner
      expect(VideoVisibilityPolicy.canWatchVideo(membersOnlyVideo, isMember: true), isTrue);
      expect(VideoVisibilityPolicy.canWatchVideo(membersOnlyVideo), isFalse);
      expect(VideoVisibilityPolicy.canWatchVideo(membersOnlyVideo, isSubscriber: true), isFalse);

      // 4. Subscribers-only video: watchable ONLY by subscribers or owner
      expect(VideoVisibilityPolicy.canWatchVideo(subscribersOnlyVideo, isSubscriber: true), isTrue);
      expect(VideoVisibilityPolicy.canWatchVideo(subscribersOnlyVideo), isFalse);

      // 5. Public video: watchable by any viewer
      expect(VideoVisibilityPolicy.canWatchVideo(publicVideo), isTrue);
    });

    test('isVisibleForFeed allows public, members-only, and subscribers-only videos, but strictly rejects private and unlisted', () {
      expect(VideoVisibilityPolicy.isVisibleForFeed(publicVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForFeed(membersOnlyVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForFeed(subscribersOnlyVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForFeed(privateVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForFeed(privateDraftVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForFeed(unlistedVideo), isFalse);
    });

    test('isVisibleForSearch allows public, members-only, and subscribers-only videos, but strictly rejects private and unlisted', () {
      expect(VideoVisibilityPolicy.isVisibleForSearch(publicVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForSearch(membersOnlyVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForSearch(subscribersOnlyVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForSearch(privateVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForSearch(privateDraftVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForSearch(unlistedVideo), isFalse);
    });

    test('isVisibleForChannel allows private and unlisted videos ONLY for channel owner', () {
      // Non-owner viewing channel
      expect(VideoVisibilityPolicy.isVisibleForChannel(publicVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(membersOnlyVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(subscribersOnlyVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(privateVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForChannel(privateDraftVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForChannel(unlistedVideo), isFalse);

      // Channel Owner viewing their own channel
      expect(VideoVisibilityPolicy.isVisibleForChannel(publicVideo, isChannelOwner: true), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(membersOnlyVideo, isChannelOwner: true), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(subscribersOnlyVideo, isChannelOwner: true), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(privateVideo, isChannelOwner: true), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForChannel(unlistedVideo, isChannelOwner: true), isTrue);
    });

    test('isMapValid rejects maps with visibility == private or unlisted, but accepts public, members, subscribers', () {
      final pubMap = {
        'title': 'Public Insight',
        'status': 'ready',
        'visibility': 'public',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
        'isApproved': true,
      };
      final privMap = {
        'title': 'Private Insight',
        'status': 'ready',
        'visibility': 'private',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
        'isApproved': true,
      };
      final privDraftMap = {
        'title': 'Private Draft',
        'status': 'ready',
        'visibility': 'private_draft',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
        'isApproved': true,
      };
      final unlistedMap = {
        'title': 'Unlisted Insight',
        'status': 'ready',
        'visibility': 'unlisted',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
        'isApproved': true,
      };
      final membersMap = {
        'title': 'Members Insight',
        'status': 'ready',
        'visibility': 'members_only',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
        'isApproved': true,
      };
      final subscribersMap = {
        'title': 'Subscribers Insight',
        'status': 'ready',
        'visibility': 'subscribers_only',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
        'isApproved': true,
      };

      expect(VideoVisibilityPolicy.isMapValid(pubMap), isTrue);
      expect(VideoVisibilityPolicy.isMapValid(membersMap), isTrue);
      expect(VideoVisibilityPolicy.isMapValid(subscribersMap), isTrue);
      expect(VideoVisibilityPolicy.isMapValid(privMap), isFalse);
      expect(VideoVisibilityPolicy.isMapValid(privDraftMap), isFalse);
      expect(VideoVisibilityPolicy.isMapValid(unlistedMap), isFalse);
    });

    test('SearchResult.isValid handles visibility correctly for discoverable and hidden videos', () {
      final pubResult = SearchResult(
        id: 'vid_1',
        title: 'Exposing Global Fact Checking',
        thumbnail: 'https://example.com/thumb.jpg',
        views: 100,
        channelName: 'Truth Channel',
        channelImage: 'https://example.com/avatar.jpg',
        createdAt: Timestamp.now(),
      );

      final privResult = SearchResult(
        id: 'vid_2',
        title: 'Secret Channel Video',
        thumbnail: 'https://example.com/thumb.jpg',
        views: 5,
        channelName: 'Truth Channel',
        channelImage: 'https://example.com/avatar.jpg',
        createdAt: Timestamp.now(),
        visibility: 'private',
      );

      final unlistedResult = SearchResult(
        id: 'vid_3',
        title: 'Unlisted Channel Video',
        thumbnail: 'https://example.com/thumb.jpg',
        views: 9,
        channelName: 'Truth Channel',
        channelImage: 'https://example.com/avatar.jpg',
        createdAt: Timestamp.now(),
        visibility: 'unlisted',
      );

      final membersResult = SearchResult(
        id: 'vid_4',
        title: 'Members Channel Video',
        thumbnail: 'https://example.com/thumb.jpg',
        views: 50,
        channelName: 'Truth Channel',
        channelImage: 'https://example.com/avatar.jpg',
        createdAt: Timestamp.now(),
        visibility: 'members_only',
      );

      final subscribersResult = SearchResult(
        id: 'vid_5',
        title: 'Subscribers Channel Video',
        thumbnail: 'https://example.com/thumb.jpg',
        views: 35,
        channelName: 'Truth Channel',
        channelImage: 'https://example.com/avatar.jpg',
        createdAt: Timestamp.now(),
        visibility: 'subscribers_only',
      );

      expect(pubResult.isValid, isTrue);
      expect(privResult.isValid, isFalse);
      expect(unlistedResult.isValid, isFalse);
      expect(membersResult.isValid, isTrue);
      expect(subscribersResult.isValid, isTrue);

      expect(privResult.isPrivate, isTrue);
      expect(unlistedResult.isUnlisted, isTrue);
      expect(membersResult.isMembersOnly, isTrue);
      expect(subscribersResult.isSubscribersOnly, isTrue);
    });

    test('isUnlisted and isPublic identify video visibility correctly', () {
      expect(VideoVisibilityPolicy.isUnlisted(unlistedVideo), isTrue);
      expect(unlistedVideo.isUnlisted, isTrue);
      expect(VideoVisibilityPolicy.isUnlisted(publicVideo), isFalse);
      expect(publicVideo.isUnlisted, isFalse);
      expect(VideoVisibilityPolicy.isPublic(publicVideo), isTrue);
      expect(publicVideo.isPublic, isTrue);
      expect(VideoVisibilityPolicy.isPublic(unlistedVideo), isFalse);
      expect(unlistedVideo.isPublic, isFalse);
    });

    test('canViewVideo allows viewing unlisted video via direct link', () {
      expect(VideoVisibilityPolicy.canViewVideo(unlistedVideo), isTrue);
    });
  });
}
