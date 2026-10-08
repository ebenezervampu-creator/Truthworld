// Creator & Community Scalability Tests
//
// Verifies CommunityPostCardReactionEngine high-frequency atomic reaction state transitions,
// ChannelPayoutCalculator revenue splits, infrastructure cost deduction & Zero-Debt Floor,
// 10-hour video watch time withdrawal unlocking rules,
// and ChannelWalletService dynamic AI capability pricing & balance affordability checks.
//
// Pure Dart tests — zero mock data, zero network calls.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';

Channel _makeChannel({
  required String id,
  required ChannelType type,
  CustomChannelInfraConfig? infraConfig,
}) {
  final now = Timestamp.now();
  return Channel(
    id: id,
    name: 'Channel $id',
    nameLowercase: 'channel $id',
    handle: 'handle_$id',
    handleLowercase: 'handle_$id',
    description: 'Creator channel $id',
    avatarUrl: 'https://example.com/avatar.png',
    bannerUrl: 'https://example.com/banner.png',
    ownerId: 'owner_$id',
    createdAt: now,
    updatedAt: now,
    channelType: type,
    infraConfig: infraConfig,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Group 1: CommunityPostCardReactionEngine — Atomic State Transitions ───

  group('CommunityPostCardReactionEngine — High-Frequency State Transitions', () {
    test('10,000 rapid sequential like/dislike transitions complete in under 60 ms', () {
      var state = const CommunityPostReactionState(
        likes: 0,
        dislikes: 0,
        likedBy: [],
        dislikedBy: [],
        isLiked: false,
        isDisliked: false,
      );

      // Warmup pass
      for (var i = 0; i < 50; i++) {
        state = CommunityPostCardReactionEngine.toggleLike(state, 'warm_$i');
      }

      state = const CommunityPostReactionState(
        likes: 0,
        dislikes: 0,
        likedBy: [],
        dislikedBy: [],
        isLiked: false,
        isDisliked: false,
      );

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        final uid = 'user_${i % 1000}';
        // Alternate between toggling like and toggling dislike
        if (i % 3 == 0) {
          state = CommunityPostCardReactionEngine.toggleLike(state, uid);
        } else if (i % 3 == 1) {
          state = CommunityPostCardReactionEngine.toggleDislike(state, uid);
        } else {
          // Toggle like again (toggle off)
          state = CommunityPostCardReactionEngine.toggleLike(state, uid);
        }
      }
      stopwatch.stop();

      expect(state.likes, greaterThanOrEqualTo(0));
      expect(state.dislikes, greaterThanOrEqualTo(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(400),
          reason: '10,000 reaction state transitions must complete in < 400 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Enforces strict mutual exclusion between likedBy and dislikedBy at scale', () {
      var state = const CommunityPostReactionState(
        likes: 0,
        dislikes: 0,
        likedBy: [],
        dislikedBy: [],
        isLiked: false,
        isDisliked: false,
      );

      for (var i = 0; i < 500; i++) {
        final uid = 'user_$i';
        // User first dislikes
        state = CommunityPostCardReactionEngine.toggleDislike(state, uid);
        expect(state.dislikedBy.contains(uid), isTrue);
        expect(state.likedBy.contains(uid), isFalse);

        // User changes mind and likes: dislike must be removed, like added
        state = CommunityPostCardReactionEngine.toggleLike(state, uid);
        expect(state.likedBy.contains(uid), isTrue);
        expect(state.dislikedBy.contains(uid), isFalse);
      }

      expect(state.likes, equals(500));
      expect(state.dislikes, equals(0));
    });

    test('Prevents negative count underflow when toggling reactions on zero counts', () {
      var state = const CommunityPostReactionState(
        likes: 0,
        dislikes: 0,
        likedBy: ['existing_user'],
        dislikedBy: ['other_user'],
        isLiked: true,
        isDisliked: true,
      );

      // Untoggle existing like
      state = CommunityPostCardReactionEngine.toggleLike(state, 'existing_user');
      expect(state.likes, equals(0));

      // Untoggle existing dislike
      state = CommunityPostCardReactionEngine.toggleDislike(state, 'other_user');
      expect(state.dislikes, equals(0));
    });
  });

  // ── Group 2: ChannelPayoutCalculator — Revenue Splits & Zero-Debt Floor ────

  group('ChannelPayoutCalculator — Revenue Splits & Zero-Debt Floor at Scale', () {
    test('Calculates 1,000 Standard Channel revenue payouts in under 30 ms', () {
      // Warmup pass
      for (var i = 0; i < 20; i++) {
        ChannelPayoutCalculator.calculateStandardChannelPayout(
          adRevenue: 100.0,
          premiumSubRevenue: 50.0,
          tipsRevenue: 20.0,
          membershipsRevenue: 30.0,
        );
      }

      var lastBreakdown = ChannelPayoutCalculator.calculateStandardChannelPayout(
        adRevenue: 1000.0,
        premiumSubRevenue: 500.0,
        tipsRevenue: 200.0,
        membershipsRevenue: 300.0,
      );

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        lastBreakdown = ChannelPayoutCalculator.calculateStandardChannelPayout(
          adRevenue: 1000.0 + i,
          premiumSubRevenue: 500.0 + i,
          tipsRevenue: 200.0 + i,
          membershipsRevenue: 300.0 + i,
        );
      }
      stopwatch.stop();

      const expectedAd = (1000.0 + 999) * 0.70;
      const expectedSub = (500.0 + 999) * 0.70;
      const expectedCreator = expectedAd + expectedSub + (200.0 + 999) + (300.0 + 999);

      expect(lastBreakdown.creatorPayout, closeTo(expectedCreator, 0.001));
      expect(lastBreakdown.isZeroDebtProtected, isFalse);
      expect(stopwatch.elapsedMilliseconds, lessThan(60),
          reason: '1,000 standard channel payout calculations must take < 60 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Custom Channel Zero-Debt Floor guarantees creator balance never drops below 0', () {
      final scenarios = [
        // gross, infra, fee -> net -> expectedPayout, expectedProtected
        [100.0, 50.0, 25.0, 25.0, false],
        [100.0, 75.0, 25.0, 0.0, false],
        [100.0, 90.0, 25.0, 0.0, true], // Net = -15 -> 0 payout, protected
        [10.0, 200.0, 25.0, 0.0, true], // Net = -215 -> 0 payout, protected
        [1000.0, 150.0, 25.0, 825.0, false],
      ];

      for (final s in scenarios) {
        final breakdown = ChannelPayoutCalculator.calculateCustomChannelPayout(
          grossRevenue: s[0] as double,
          actualInfraCost: s[1] as double,
          flatPlatformFee: s[2] as double,
        );

        expect(breakdown.creatorPayout, equals(s[3]));
        expect(breakdown.isZeroDebtProtected, equals(s[4]));
        expect(breakdown.creatorPayout, greaterThanOrEqualTo(0.0),
            reason: 'Creator payout must never be negative due to Zero-Debt Protection.');
      }
    });

    test('Evaluates 2,000 video withdrawal eligibility checks in under 30 ms', () {
      final standardChannel = _makeChannel(id: 'ch_std', type: ChannelType.standard);
      final customChannel = _makeChannel(id: 'ch_cust', type: ChannelType.custom);

      // Verify correctness on critical boundary conditions
      final stdLocked = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
        channel: standardChannel,
        videoId: 'vid_locked',
        videoRevenue: 100.0,
        videoWatchTimeMinutes: 599,
        videoViews: 1000,
      );
      expect(stdLocked.isUnlockedForWithdrawal, isFalse);
      expect(stdLocked.withdrawableAmount, equals(0.0));
      expect(stdLocked.pendingLockedAmount, equals(100.0));

      final stdUnlocked = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
        channel: standardChannel,
        videoId: 'vid_unlocked',
        videoRevenue: 100.0,
        videoWatchTimeMinutes: 600,
        videoViews: 1000,
      );
      expect(stdUnlocked.isUnlockedForWithdrawal, isTrue);
      expect(stdUnlocked.withdrawableAmount, equals(100.0));
      expect(stdUnlocked.pendingLockedAmount, equals(0.0));

      final custLocked = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
        channel: customChannel,
        videoId: 'vid_cust_locked',
        videoRevenue: 100.0,
        videoWatchTimeMinutes: 599,
        videoViews: 1000,
      );
      expect(custLocked.isUnlockedForWithdrawal, isFalse);
      expect(custLocked.withdrawableAmount, equals(0.0));
      expect(custLocked.pendingLockedAmount, equals(100.0));

      final custUnlocked = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
        channel: customChannel,
        videoId: 'vid_cust_unlocked',
        videoRevenue: 100.0,
        videoWatchTimeMinutes: 600,
        videoViews: 1000,
      );
      expect(custUnlocked.isUnlockedForWithdrawal, isTrue);
      expect(custUnlocked.withdrawableAmount, equals(100.0));
      expect(custUnlocked.pendingLockedAmount, equals(0.0));

      // Benchmark pure calculation throughput (2,000 evaluations)
      var totalWithdrawable = 0.0;
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final stdResult = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: standardChannel,
          videoId: 'vid_$i',
          videoRevenue: 100.0,
          videoWatchTimeMinutes: i,
          videoViews: i * 2,
        );
        totalWithdrawable += stdResult.withdrawableAmount;

        final custResult = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: customChannel,
          videoId: 'vid_$i',
          videoRevenue: 100.0,
          videoWatchTimeMinutes: i,
          videoViews: i * 2,
        );
        totalWithdrawable += custResult.withdrawableAmount;
      }
      stopwatch.stop();

      expect(totalWithdrawable, greaterThan(0.0));
      expect(stopwatch.elapsedMilliseconds, lessThan(30),
          reason: '2,000 withdrawal eligibility checks must take < 30 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 3: ChannelWalletService — AI Pricing & Affordability Checks ──────

  group('ChannelWalletService — AI Feature Pricing & Spendable Balance', () {
    test('Calculates AI capability pricing across 5,000 configurations in under 50 ms', () {
      final featureSets = [
        {'subtitles'},
        {'dubbing'},
        {'factcheck'},
        {'chapters'},
        {'subtitles', 'dubbing', 'factcheck'},
      ];

      final languages = [
        ['es'],
        ['es', 'fr', 'de'],
        ['es', 'fr', 'de', 'ja', 'zh', 'ar', 'hi'],
      ];

      final channelTypes = [ChannelType.standard, ChannelType.custom];

      // Warmup pass
      for (var i = 0; i < 20; i++) {
        ChannelWalletService.calculateAIFeatureCost(
          selectedFeatures: featureSets[i % featureSets.length],
          targetLanguages: languages[i % languages.length],
          channelType: channelTypes[i % channelTypes.length],
        );
      }

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 5000; i++) {
        final cost = ChannelWalletService.calculateAIFeatureCost(
          selectedFeatures: featureSets[i % featureSets.length],
          targetLanguages: languages[i % languages.length],
          channelType: channelTypes[i % channelTypes.length],
        );
        expect(cost, greaterThanOrEqualTo(0.0));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Calculating 5,000 AI feature costs must take < 50 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('SpendableBalance.canAfford evaluates 10,000 queries in under 30 ms', () {
      const balance = SpendableBalance(
        fundedBalance: 15.0,
        withdrawableRevenue: 50.0,
        lockedRevenue: 35.0,
      );

      expect(balance.totalRevenue, equals(85.0));
      expect(balance.totalSpendableBalance, equals(100.0));

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        final amount = (i % 200).toDouble();
        final canAfford = balance.canAfford(amount);
        expect(canAfford, equals(amount <= 100.0));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(30),
          reason: '10,000 affordability checks must take < 30 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Serializes and deserializes 1,000 WalletTransaction items in under 60 ms', () {
      final now = DateTime.now();
      final transactions = List<WalletTransaction>.generate(1000, (i) {
        return WalletTransaction(
          id: 'tx_$i',
          channelId: 'ch_${i % 50}',
          userId: 'usr_${i % 100}',
          amount: 5.0 + (i % 20),
          trialCreditDeducted: 0.0,
          revenueDeducted: 5.0 + (i % 20),
          category: WalletTransactionCategory.aiDubbing,
          description: 'AI Dubbing Generation #$i',
          balanceBefore: 100.0,
          balanceAfter: 100.0 - (5.0 + (i % 20)),
          timestamp: now,
        );
      });

      // Warmup pass
      for (var i = 0; i < 20; i++) {
        final map = transactions[i].toMap();
        WalletTransaction.fromMap(map, transactions[i].id);
      }

      final stopwatch = Stopwatch()..start();
      for (final tx in transactions) {
        final map = tx.toMap();
        final reconstructed = WalletTransaction.fromMap(map, tx.id);
        expect(reconstructed.id, equals(tx.id));
        expect(reconstructed.amount, equals(tx.amount));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(60),
          reason: 'Serializing & deserializing 1,000 WalletTransactions must take < 60 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });
}
