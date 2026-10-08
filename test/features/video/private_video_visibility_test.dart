import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('Private Video Visibility Policy Tests', () {
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

    test('isPrivate identifies private and private_draft correctly regardless of case', () {
      expect(VideoVisibilityPolicy.isPrivate(publicVideo), isFalse);
      expect(VideoVisibilityPolicy.isPrivate(privateVideo), isTrue);
      expect(VideoVisibilityPolicy.isPrivate(privateDraftVideo), isTrue);
      expect(privateVideo.isPrivate, isTrue);
      expect(publicVideo.isPrivate, isFalse);
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

    test('isVisibleForFeed strictly rejects private videos even for owners', () {
      // Public feeds should NEVER feature private videos
      expect(VideoVisibilityPolicy.isVisibleForFeed(publicVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForFeed(privateVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForFeed(privateDraftVideo), isFalse);
    });

    test('isVisibleForSearch strictly rejects private videos', () {
      expect(VideoVisibilityPolicy.isVisibleForSearch(publicVideo), isTrue);
      expect(VideoVisibilityPolicy.isVisibleForSearch(privateVideo), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForSearch(privateDraftVideo), isFalse);
    });

    test('isMapValid rejects maps with visibility == private or private_draft', () {
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

      expect(VideoVisibilityPolicy.isMapValid(pubMap), isTrue);
      expect(VideoVisibilityPolicy.isMapValid(privMap), isFalse);
      expect(VideoVisibilityPolicy.isMapValid(privDraftMap), isFalse);
    });

    test('SearchResult.isValid rejects private video search results', () {
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

      expect(pubResult.isValid, isTrue);
      expect(privResult.isValid, isFalse);
      expect(privResult.isPrivate, isTrue);
      expect(pubResult.isPrivate, isFalse);
    });
  });
}
