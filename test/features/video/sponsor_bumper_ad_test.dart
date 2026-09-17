import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Sponsor Pre-Roll Bumper Tests', () {
    test('PlaybackAd correctly holds isSponsorBumper flag', () {
      const bumperAd = PlaybackAd(
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

      const standardMidrollAd = PlaybackAd(
        videoUrl: 'https://example.com/midroll.mp4',
        title: 'Brand Midroll',
        description: 'Midroll Ad',
        clickUrl: 'https://example.com',
        skippable: true,
        duration: Duration(seconds: 15),
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

    test('PlaybackAd correctly holds subtitles and audioTracks', () {
      const adWithAI = PlaybackAd(
        videoUrl: 'https://example.com/video.mp4',
        title: 'Dubbed Video Ad',
        description: 'Multi-lingual video ad',
        clickUrl: 'https://example.com',
        skippable: true,
        duration: Duration(seconds: 15),
        subtitles: {
          'en': 'WEBVTT\n\n00:00:01.000 --> 00:00:05.000\nHello World\n',
          'te': 'WEBVTT\n\n00:00:01.000 --> 00:00:05.000\nనమస్కారం ప్రపంచం\n',
        },
        audioTracks: {
          'te': 'https://example.com/te.mp3',
          'hi': 'https://example.com/hi.mp3',
        },
      );

      expect(adWithAI.subtitles, isNotNull);
      expect(adWithAI.subtitles?['te'], contains('నమస్కారం'));
      expect(adWithAI.audioTracks?['te'], equals('https://example.com/te.mp3'));
      expect(adWithAI.audioTracks?['hi'], equals('https://example.com/hi.mp3'));
    });

    test('AdItem audience targeting serialization and broad match validation', () {
      const broadAd = AdItem(
        id: 'ad_broad',
        userId: 'user_1',
        title: 'Broad Ad',
        description: 'Reaches everyone',
        advertiser: 'Global Corp',
        imageUrl: '',
        ctaText: 'Learn More',
        ctaTarget: 'https://example.com',
        gradientColors: [Colors.black, Colors.white],
        targetAgeGroups: ['All Ages'],
        targetGenders: ['All Genders'],
        targetLocations: ['Worldwide'],
      );

      final map = broadAd.toMap();
      expect(map['targetAgeGroups'], equals(['All Ages']));
      expect(map['targetGenders'], equals(['All Genders']));
      expect(map['targetLocations'], equals(['Worldwide']));

      final reconstituted = AdItem.fromMap(map);
      expect(reconstituted.targetAgeGroups, equals(['All Ages']));
      expect(reconstituted.targetGenders, equals(['All Genders']));
      expect(reconstituted.targetLocations, equals(['Worldwide']));

      final service = AdService();
      expect(service.matchesUserTargeting(broadAd), isTrue);
    });

    test('AdItem budgetProgress safely handles zero total budget', () {
      const zeroBudgetAd = AdItem(
        id: 'ad_zero',
        userId: 'user_1',
        title: 'Zero Budget',
        description: 'Test',
        advertiser: 'Tester',
        imageUrl: '',
        ctaText: 'Test',
        ctaTarget: 'https://example.com',
        gradientColors: [Colors.black, Colors.white],
        budgetAmount: 0.0,
      );

      expect(zeroBudgetAd.budgetProgress, equals(0.0));
      expect(zeroBudgetAd.remaining, equals(0.0));
    });

    test('Safe numeric coercion tests for double and int', () {
      final data = <String, Object?>{
        'intVal': 500,
        'doubleVal': 750.50,
        'nullVal': null,
      };

      final parsedDouble1 = (data['intVal'] as num?)?.toDouble() ?? 0.0;
      final parsedDouble2 = (data['doubleVal'] as num?)?.toDouble() ?? 0.0;
      final parsedDoubleNull = (data['nullVal'] as num?)?.toDouble() ?? 0.0;

      expect(parsedDouble1, equals(500.0));
      expect(parsedDouble2, equals(750.50));
      expect(parsedDoubleNull, equals(0.0));

      final parsedInt1 = (data['doubleVal'] as num?)?.toInt() ?? 0;
      final parsedInt2 = (data['intVal'] as num?)?.toInt() ?? 0;
      final parsedIntNull = (data['nullVal'] as num?)?.toInt() ?? 0;

      expect(parsedInt1, equals(750));
      expect(parsedInt2, equals(500));
      expect(parsedIntNull, equals(0));
    });
  });
}
