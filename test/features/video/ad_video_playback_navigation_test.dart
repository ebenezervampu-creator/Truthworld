import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('AdItem Video Playback & Navigation Tests', () {
    test('hasVideo returns true when videoUrl is set', () {
      const adWithVideoUrl = AdItem(
        id: 'ad_1',
        userId: 'user_1',
        title: 'Video Ad',
        description: 'Testing video ad',
        advertiser: 'Acme Corp',
        imageUrl: 'https://example.com/thumb.jpg',
        ctaText: 'Visit',
        ctaTarget: 'https://acme.com',
        gradientColors: [Colors.blue, Colors.purple],
        videoUrl: 'https://example.com/ad_stream.mp4',
      );

      expect(adWithVideoUrl.hasVideo, isTrue);
      expect(adWithVideoUrl.effectiveVideoUrl, 'https://example.com/ad_stream.mp4');
    });

    test('hasVideo returns true when resolutions contains video URLs', () {
      const adWithResolutions = AdItem(
        id: 'ad_2',
        userId: 'user_1',
        title: 'Resolution Ad',
        description: 'Testing resolution ad',
        advertiser: 'Acme Corp',
        imageUrl: 'https://example.com/thumb.jpg',
        ctaText: 'Visit',
        ctaTarget: 'https://acme.com',
        gradientColors: [Colors.blue, Colors.purple],
        resolutions: [
          {'label': '720p', 'url': 'https://example.com/720p.mp4', 'width': 1280, 'height': 720, 'bitrate': 2500000},
        ],
      );

      expect(adWithResolutions.hasVideo, isTrue);
      expect(adWithResolutions.effectiveVideoUrl, 'https://example.com/720p.mp4');
    });

    test('hasVideo returns true when videoId is set', () {
      const adWithVideoId = AdItem(
        id: 'ad_3',
        userId: 'user_1',
        title: 'Preset Ad',
        description: 'Testing preset video id ad',
        advertiser: 'Acme Corp',
        imageUrl: 'https://example.com/thumb.jpg',
        ctaText: 'Visit',
        ctaTarget: 'https://acme.com',
        gradientColors: [Colors.blue, Colors.purple],
        videoId: 'existing_video_id_123',
      );

      expect(adWithVideoId.hasVideo, isTrue);
    });

    test('hasVideo returns false for image banner ads without video', () {
      const imageAd = AdItem(
        id: 'ad_image',
        userId: 'user_1',
        title: 'Image Banner Ad',
        description: 'Testing image ad',
        advertiser: 'Acme Corp',
        imageUrl: 'https://example.com/banner.jpg',
        ctaText: 'Shop Now',
        ctaTarget: 'https://acme.com/shop',
        gradientColors: [Colors.blue, Colors.purple],
      );

      expect(imageAd.hasVideo, isFalse);
      expect(imageAd.effectiveVideoUrl, isNull);
    });

    test('toVideo correctly maps AdItem to a valid playable Video model', () {
      const ad = AdItem(
        id: 'ad_convert_1',
        userId: 'advertiser_user_99',
        title: 'Amazing Product',
        description: 'Discover the future today',
        advertiser: 'FutureTech Inc',
        imageUrl: 'https://example.com/future.jpg',
        ctaText: 'Learn More',
        ctaTarget: 'https://futuretech.io',
        gradientColors: [Colors.black, Colors.grey],
        videoUrl: 'https://example.com/future_ad.mp4',
      );

      final video = ad.toVideo();

      expect(video.id, 'ad_convert_1');
      expect(video.title, 'Amazing Product');
      expect(video.description, 'Discover the future today');
      expect(video.channelName, 'FutureTech Inc');
      expect(video.videoUrl, 'https://example.com/future_ad.mp4');
      expect(video.originalUrl, 'https://example.com/future_ad.mp4');
      expect(video.thumbnailUrl, 'https://example.com/future.jpg');
      expect(video.status, VideoStatus.ready);
      expect(video.visibility, 'public');
      expect(video.geminiApproved, isTrue);
      expect(video.isApproved, isTrue);
      expect(video.adaptiveResolutions, isNotEmpty);
    });

    test('toVideo adopts videoId if present on AdItem', () {
      const adWithPreset = AdItem(
        id: 'camp_777',
        userId: 'user_456',
        title: 'Channel Promo',
        description: 'Watch our full documentary',
        advertiser: 'Truth Docs',
        imageUrl: 'https://example.com/doc.jpg',
        ctaText: 'Watch',
        ctaTarget: 'https://truthdocs.com',
        gradientColors: [Colors.red, Colors.orange],
        videoId: 'doc_video_888',
        videoUrl: 'https://example.com/doc.mp4',
      );

      final video = adWithPreset.toVideo();

      expect(video.id, 'doc_video_888');
      expect(video.channelName, 'Truth Docs');
      expect(video.videoUrl, 'https://example.com/doc.mp4');
    });
  });
}
