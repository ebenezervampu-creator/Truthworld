import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Sponsor Pre-Roll Bumper Tests', () {
    test('MockAd correctly holds isSponsorBumper flag', () {
      const bumperAd = MockAd(
        videoUrl: 'https://example.com/bumper.mp4',
        title: 'This video is brought to you by Brand',
        description: 'Official Video Sponsor Bumper (5s Intro)',
        clickUrl: 'https://example.com',
        skippable: false,
        duration: Duration(seconds: 5),
        isSponsorBumper: true,
      );

      expect(bumperAd.isSponsorBumper, isTrue);
      expect(bumperAd.skippable, isFalse);
      expect(bumperAd.duration.inSeconds, equals(5));

      const standardMidrollAd = MockAd(
        videoUrl: 'https://example.com/midroll.mp4',
        title: 'Brand Midroll',
        description: 'Midroll Ad',
        clickUrl: 'https://example.com',
        skippable: true,
        duration: Duration(seconds: 15),
        isSponsorBumper: false,
      );

      expect(standardMidrollAd.isSponsorBumper, isFalse);
    });

    test('AdItem generates sponsorBumperText correctly', () {
      const adItem = AdItem(
        id: 'ad-123',
        userId: 'user-1',
        title: 'Super Brand',
        description: 'Brand Description',
        advertiser: 'Acme Corp',
        imageUrl: '',
        ctaText: 'Visit Acme',
        ctaTarget: 'https://acme.com',
        gradientColors: [Colors.blue, Colors.purple],
        adType: 'video_sponsor',
      );

      expect(
        adItem.sponsorBumperText,
        equals('This video is brought to you by Acme Corp'),
      );
    });
  });
}
