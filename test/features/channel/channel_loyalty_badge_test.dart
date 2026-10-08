import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

void main() {
  group('ChannelLoyaltyBadge & YouTube-Style Tenure Progression', () {
    test('contains all 10 standard YouTube tenure milestones', () {
      expect(ChannelLoyaltyBadge.allMilestones.length, equals(10));

      const milestones = ChannelLoyaltyBadge.allMilestones;
      expect(milestones[0].milestone, equals(ChannelLoyaltyMilestone.newMember));
      expect(milestones[0].monthsRequired, equals(0));
      expect(milestones[0].label, equals('New member'));
      expect(milestones[0].color, equals(const Color(0xFF10B981)));

      expect(milestones[1].milestone, equals(ChannelLoyaltyMilestone.threeMonths));
      expect(milestones[1].monthsRequired, equals(3));
      expect(milestones[1].label, equals('3 months'));
      expect(milestones[1].color, equals(const Color(0xFF0284C7)));

      expect(milestones[2].milestone, equals(ChannelLoyaltyMilestone.sixMonths));
      expect(milestones[2].monthsRequired, equals(6));
      expect(milestones[2].label, equals('6 months'));
      expect(milestones[2].color, equals(const Color(0xFF8B5CF6)));

      expect(milestones[3].milestone, equals(ChannelLoyaltyMilestone.oneYear));
      expect(milestones[3].monthsRequired, equals(12));
      expect(milestones[3].label, equals('1 year'));
      expect(milestones[3].color, equals(const Color(0xFFEC4899)));

      expect(milestones[4].milestone, equals(ChannelLoyaltyMilestone.twoYears));
      expect(milestones[4].monthsRequired, equals(24));
      expect(milestones[4].label, equals('2 years'));
      expect(milestones[4].color, equals(const Color(0xFFF59E0B)));

      expect(milestones[5].milestone, equals(ChannelLoyaltyMilestone.threeYears));
      expect(milestones[5].monthsRequired, equals(36));
      expect(milestones[5].label, equals('3 years'));
      expect(milestones[5].color, equals(const Color(0xFFEAB308)));

      expect(milestones[6].milestone, equals(ChannelLoyaltyMilestone.fourYears));
      expect(milestones[6].monthsRequired, equals(48));
      expect(milestones[6].label, equals('4 years'));
      expect(milestones[6].color, equals(const Color(0xFF14B8A6)));

      expect(milestones[7].milestone, equals(ChannelLoyaltyMilestone.fiveYears));
      expect(milestones[7].monthsRequired, equals(60));
      expect(milestones[7].label, equals('5 years'));
      expect(milestones[7].color, equals(const Color(0xFF3B82F6)));

      expect(milestones[8].milestone, equals(ChannelLoyaltyMilestone.sevenYears));
      expect(milestones[8].monthsRequired, equals(84));
      expect(milestones[8].label, equals('7 years'));
      expect(milestones[8].color, equals(const Color(0xFF06B6D4)));

      expect(milestones[9].milestone, equals(ChannelLoyaltyMilestone.tenYears));
      expect(milestones[9].monthsRequired, equals(120));
      expect(milestones[9].label, equals('10 years'));
      expect(milestones[9].color, equals(const Color(0xFFE11D48)));
    });

    test('correctly determines milestone from months', () {
      expect(ChannelLoyaltyBadge.milestoneFromMonths(0), equals(ChannelLoyaltyMilestone.newMember));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(1), equals(ChannelLoyaltyMilestone.newMember));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(2), equals(ChannelLoyaltyMilestone.newMember));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(3), equals(ChannelLoyaltyMilestone.threeMonths));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(5), equals(ChannelLoyaltyMilestone.threeMonths));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(6), equals(ChannelLoyaltyMilestone.sixMonths));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(11), equals(ChannelLoyaltyMilestone.sixMonths));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(12), equals(ChannelLoyaltyMilestone.oneYear));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(23), equals(ChannelLoyaltyMilestone.oneYear));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(24), equals(ChannelLoyaltyMilestone.twoYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(35), equals(ChannelLoyaltyMilestone.twoYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(36), equals(ChannelLoyaltyMilestone.threeYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(47), equals(ChannelLoyaltyMilestone.threeYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(48), equals(ChannelLoyaltyMilestone.fourYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(59), equals(ChannelLoyaltyMilestone.fourYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(60), equals(ChannelLoyaltyMilestone.fiveYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(83), equals(ChannelLoyaltyMilestone.fiveYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(84), equals(ChannelLoyaltyMilestone.sevenYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(119), equals(ChannelLoyaltyMilestone.sevenYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(120), equals(ChannelLoyaltyMilestone.tenYears));
      expect(ChannelLoyaltyBadge.milestoneFromMonths(150), equals(ChannelLoyaltyMilestone.tenYears));
    });

    test('calculates months tenure accurately from DateTime', () {
      final now = DateTime(2026, 9, 30);
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2026, 9), now), equals(0));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2026, 6, 30), now), equals(3));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2026, 3, 30), now), equals(6));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2025, 9, 30), now), equals(12));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2024, 9, 30), now), equals(24));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2023, 9, 30), now), equals(36));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2022, 9, 30), now), equals(48));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2021, 9, 30), now), equals(60));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2019, 9, 30), now), equals(84));
      expect(ChannelLoyaltyBadge.calculateMonths(DateTime(2016, 9, 30), now), equals(120));
    });

    test('generates user-friendly tooltip message', () {
      final badge = ChannelLoyaltyBadge.fromMilestone(ChannelLoyaltyMilestone.oneYear);
      expect(badge.tooltipText(), equals('Channel Member · 1 year'));
      expect(badge.tooltipText(tierName: 'Gold Patron'), equals('Gold Patron Member · 1 year'));
    });
  });

  group('Comment & Reply Channel Membership Resolution', () {
    test('non-member comment returns null loyaltyMilestone', () {
      final comment = Comment(
        id: 'c1',
        videoId: 'v1',
        userId: 'u1',
        userName: 'Alice',
        userProfilePicUrl: '',
        channelId: 'ch1',
        text: 'Hello world',
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      expect(comment.isMember, isFalse);
      expect(comment.loyaltyMilestone, isNull);
    });

    test('member comment resolves loyaltyMilestone according to tenure', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 370));
      final comment = Comment(
        id: 'c2',
        videoId: 'v1',
        userId: 'u2',
        userName: 'Bob',
        userProfilePicUrl: '',
        channelId: 'ch2',
        text: 'Proud member!',
        likeCount: 5,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
        isMember: true,
        memberSince: Timestamp.fromDate(oneYearAgo),
        memberTierName: 'VIP Supporter',
      );

      expect(comment.isMember, isTrue);
      expect(comment.loyaltyMilestone, equals(ChannelLoyaltyMilestone.oneYear));
      expect(comment.memberTierName, equals('VIP Supporter'));

      final map = comment.toMap();
      expect(map['isMember'], isTrue);
      expect(map['memberTierName'], equals('VIP Supporter'));
      expect(map['memberSince'], isNotNull);
    });

    test('reply resolves member loyaltyMilestone', () {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 95));
      final reply = Reply(
        id: 'r1',
        commentId: 'c1',
        videoId: 'v1',
        userId: 'u3',
        userName: 'Charlie',
        userProfilePicUrl: '',
        channelId: 'ch3',
        text: 'Thanks creator!',
        likeCount: 2,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
        isMember: true,
        memberSince: Timestamp.fromDate(threeMonthsAgo),
        memberTierName: 'Fan Club',
      );

      expect(reply.isMember, isTrue);
      expect(reply.loyaltyMilestone, equals(ChannelLoyaltyMilestone.threeMonths));

      final map = reply.toMap();
      expect(map['isMember'], isTrue);
      expect(map['memberTierName'], equals('Fan Club'));
    });
  });

  group('ChannelLoyaltyBadgeWidget Rendering', () {
    testWidgets('renders badge icon and label in non-compact mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelLoyaltyBadgeWidget(
              milestone: ChannelLoyaltyMilestone.threeMonths,
              tierName: 'Silver VIP',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('3 months'), findsOneWidget);
    });

    testWidgets('renders only icon in compact mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelLoyaltyBadgeWidget(
              milestone: ChannelLoyaltyMilestone.oneYear,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
      expect(find.text('1 year'), findsNothing);
    });
  });
}
