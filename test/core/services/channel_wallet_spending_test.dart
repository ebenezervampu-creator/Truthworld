// ignore_for_file: subtype_of_sealed_class, unnecessary_lambdas

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

void main() {
  group('ChannelWalletService Unit Tests', () {
    test('Calculates AI feature costs accurately', () {
      // 1. Fact-checking only (100% Free)
      final costFactcheck = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'factcheck'},
        targetLanguages: ['en'],
      );
      expect(costFactcheck, equals(0.00));

      // 2. Subtitles only in 3 languages ($0.05/lang, min $0.05)
      final costSubtitles = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles'},
        targetLanguages: ['te', 'hi', 'en'],
      );
      expect(costSubtitles, equals(0.15));

      // 3. Dubbing only in 4 languages ($0.25/lang, min $0.75)
      final costDubbing = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'dubbing'},
        targetLanguages: ['te', 'hi', 'en', 'es'],
      );
      expect(costDubbing, equals(1.00));

      // 4. Chapters ($0.50) & Summary ($0.00 Free - automatically generated)
      final costSummaryOnly = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'summary'},
        targetLanguages: ['en'],
      );
      expect(costSummaryOnly, equals(0.00));

      final costSummary = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'summary', 'chapters'},
        targetLanguages: ['en'],
      );
      expect(costSummary, equals(0.50));

      // 5. Complete bundle: Subtitles, Dubbing, Factcheck, Chapters (3 languages)
      // Subtitles = $0.15, Dubbing = $0.75, Factcheck = $0.00 (Free), Chapters = $0.50 => $1.40
      final costBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'chapters', 'summary'},
        targetLanguages: ['te', 'hi', 'en'],
      );
      expect(costBundle, equals(1.40));
    });

    test('Calculates Tiered Dubbing Pricing for Standard vs Custom Channels', () {
      // Rates and helper methods verification (at-cost pass-through pricing with 0% platform profit)
      expect(ChannelWalletService.getDubbingRatePerLanguage(ChannelType.standard), equals(0.25));
      expect(ChannelWalletService.getDubbingMinCost(ChannelType.standard), equals(0.75));
      expect(ChannelWalletService.getDubbingCapCost(ChannelType.standard), equals(5.00));

      expect(ChannelWalletService.getDubbingRatePerLanguage(ChannelType.custom), equals(0.25));
      expect(ChannelWalletService.getDubbingMinCost(ChannelType.custom), equals(0.75));
      expect(ChannelWalletService.getDubbingCapCost(ChannelType.custom), equals(5.00));

      // 1 Language Dubbing
      // Standard: 1 * $0.25 = $0.25 -> clamped to min $0.75
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 1),
        equals(0.75),
      );
      // Custom: 1 * $0.25 = $0.25 -> clamped to min $0.75
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 1, channelType: ChannelType.custom),
        equals(0.75),
      );

      // 4 Languages Dubbing
      // Standard: 4 * $0.25 = $1.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 4),
        equals(1.00),
      );
      // Custom: 4 * $0.25 = $1.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 4, channelType: ChannelType.custom),
        equals(1.00),
      );

      // 30 Languages Dubbing (High-volume internationalization)
      // Standard: 30 * $0.25 = $7.50 -> clamped to cap $5.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 30),
        equals(5.00),
      );
      // Custom: 30 * $0.25 = $7.50 -> clamped to cap $5.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 30, channelType: ChannelType.custom),
        equals(5.00),
      );

      // Full AI Bundle Comparison: 3 languages (Subtitles + Dubbing + Factcheck + Summary)
      // Subtitles (3 * $0.05 = $0.15) + Factcheck ($0.00 Free) + Summary ($0.00 Free)
      // Dubbing: 3 * $0.25 = $0.75 => Total $0.90
      final standardBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'summary'},
        targetLanguages: ['te', 'hi', 'en'],
      );
      expect(standardBundle, equals(0.90));

      // Custom Bundle with At-Cost Pass-Through Pricing (0% platform markup):
      // Subtitles (3 * $0.05 = $0.15) + Summary ($0.00 Free)
      // Custom Dubbing (3 * $0.25) = $0.75
      // Custom Fact-Checking = $0.00 (100% Free for all channels)
      // Total = $0.90
      final customBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'summary'},
        targetLanguages: ['te', 'hi', 'en'],
        channelType: ChannelType.custom,
      );
      expect(customBundle, equals(0.90));
    });

    test('SpendableBalance combines rollover credit and revenue correctly', () {
      const balance = SpendableBalance(
        rolloverCredit: 10.0,
        withdrawableRevenue: 25.0,
        lockedRevenue: 15.0,
      );

      expect(balance.totalRevenue, equals(40.0));
      expect(balance.totalSpendableBalance, equals(50.0));
      expect(balance.canAfford(30.0), isTrue);
      expect(balance.canAfford(50.0), isTrue);
      expect(balance.canAfford(50.01), isFalse);
    });

    test('Storage top-up packs have accurate byte representations', () {
      expect(ChannelWalletService.storagePacks.length, equals(4));

      final pack25 = ChannelWalletService.storagePacks[0];
      expect(pack25.gigabytes, equals(25));
      expect(pack25.priceUSD, equals(2.50));
      expect(pack25.bytes, equals(25 * 1024 * 1024 * 1024));

      final pack50 = ChannelWalletService.storagePacks[1];
      expect(pack50.gigabytes, equals(50));
      expect(pack50.priceUSD, equals(5.00));
      expect(pack50.bytes, equals(50 * 1024 * 1024 * 1024));

      final pack100 = ChannelWalletService.storagePacks[2];
      expect(pack100.gigabytes, equals(100));
      expect(pack100.priceUSD, equals(10.00));
      expect(pack100.bytes, equals(100 * 1024 * 1024 * 1024));
    });

    test('Bandwidth top-up packs have accurate byte representations', () {
      expect(ChannelWalletService.bandwidthPacks.length, equals(4));

      final pack100 = ChannelWalletService.bandwidthPacks[0];
      expect(pack100.gigabytes, equals(100));
      expect(pack100.priceUSD, equals(3.00));
      expect(pack100.bytes, equals(100 * 1024 * 1024 * 1024));

      final pack1tb = ChannelWalletService.bandwidthPacks[3];
      expect(pack1tb.gigabytes, equals(1000));
      expect(pack1tb.priceUSD, equals(24.00));
      expect(pack1tb.bytes, equals(1000 * 1024 * 1024 * 1024));
    });

    test('SpendableBalance combines funded balance, rollover credit and revenue correctly', () {
      const balance = SpendableBalance(
        fundedBalance: 25.0,
        rolloverCredit: 10.0,
        withdrawableRevenue: 20.0,
        lockedRevenue: 15.0,
      );

      expect(balance.fundedBalance, equals(25.0));
      expect(balance.rolloverCredit, equals(10.0));
      expect(balance.trialCreditRemaining, equals(0.0));
      expect(balance.totalRevenue, equals(35.0));
      expect(balance.totalSpendableBalance, equals(70.0));
      expect(balance.canAfford(60.0), isTrue);
      expect(balance.canAfford(70.0), isTrue);
      expect(balance.canAfford(70.01), isFalse);
    });

    test('WalletTransaction serialization handles walletTopup and fundedDeducted cleanly', () {
      final tx = WalletTransaction(
        id: 'tx_topup_101',
        channelId: 'ch_creator_777',
        userId: 'user_888',
        amount: 25.0,
        trialCreditDeducted: 0.0,
        revenueDeducted: 0.0,
        category: WalletTransactionCategory.walletTopup,
        description: r'Wallet Deposit (+$25.00)',
        balanceBefore: 10.0,
        balanceAfter: 35.0,
        timestamp: DateTime(2026, 9, 19),
        metadata: {'amountUSD': 25.0},
      );

      final map = tx.toMap();
      expect(map['id'], equals('tx_topup_101'));
      expect(map['amount'], equals(25.0));
      expect(map['category'], equals('walletTopup'));
      expect(map['fundedDeducted'], equals(0.0));

      final fromMapTx = WalletTransaction.fromMap(map, 'tx_topup_101');
      expect(fromMapTx.id, equals('tx_topup_101'));
      expect(fromMapTx.amount, equals(25.0));
      expect(fromMapTx.category, equals(WalletTransactionCategory.walletTopup));
      expect(fromMapTx.description, equals(r'Wallet Deposit (+$25.00)'));
    });

    test('Channel model serializes and parses walletBalanceUSD properly', () {
      final channelMap = <String, dynamic>{
        'name': 'Tech Insights',
        'handle': '@techinsights',
        'walletBalanceUSD': 45.50,
        'channelType': 'standard',
      };

      final ch = Channel.fromMap(channelMap, 'ch_tech_1');
      expect(ch.walletBalanceUSD, equals(45.50));

      final exported = ch.toMap();
      expect(exported['walletBalanceUSD'], equals(45.50));
      expect(exported['walletBalance'], equals(45.50));
    });

    test('Flat price dubbing calculation based on video duration and channel type', () {
      // 1. Shorts & Clips (<= 60s)
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 30,
        ),
        equals(0.10),
      );
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 60,
          channelType: ChannelType.custom,
        ),
        equals(0.10),
      );

      // 2. Mini Video (61s - 300s / 1-5 min)
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 180,
        ),
        equals(0.25),
      );
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 300,
          channelType: ChannelType.custom,
        ),
        equals(0.25),
      );

      // 3. Standard Video (301s - 600s / 5-10 min)
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 450,
        ),
        equals(0.50),
      );
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 600,
          channelType: ChannelType.custom,
        ),
        equals(0.50),
      );

      // 4. Extended Video (601s - 1800s / 10-30 min)
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 1200,
        ),
        equals(1.25),
      );
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 1800,
          channelType: ChannelType.custom,
        ),
        equals(1.25),
      );

      // 5. Long-Form Video (1801s - 3600s / 30-60 min)
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 2400,
        ),
        equals(2.50),
      );
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 3600,
          channelType: ChannelType.custom,
        ),
        equals(2.50),
      );

      // 6. Beyond 60 minutes (> 3600s): increments per 30m block
      // 5400s = 90 min (1 extra block: $2.50 + $1.25 = $3.75 for both standard and custom at-cost)
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 5400,
        ),
        equals(3.75),
      );
      expect(
        ChannelWalletService.getFlatDubbingPricePerLanguage(
          durationSeconds: 5400,
          channelType: ChannelType.custom,
        ),
        equals(3.75),
      );
    });

    test('Dubbing duration tier metadata and label resolution', () {
      expect(ChannelWalletService.dubbingDurationTiers.length, equals(5));

      final shortsTier = ChannelWalletService.getDubbingDurationTier(45);
      expect(shortsTier.id, equals('tier_shorts'));
      expect(shortsTier.standardFlatRatePerLanguage, equals(0.10));
      expect(shortsTier.customFlatRatePerLanguage, equals(0.10));

      final miniTier = ChannelWalletService.getDubbingDurationTier(120);
      expect(miniTier.id, equals('tier_mini'));
      expect(miniTier.standardFlatRatePerLanguage, equals(0.25));

      final stdTier = ChannelWalletService.getDubbingDurationTier(480);
      expect(stdTier.id, equals('tier_standard'));
      expect(stdTier.standardFlatRatePerLanguage, equals(0.50));

      final extTier = ChannelWalletService.getDubbingDurationTier(1500);
      expect(extTier.id, equals('tier_extended'));
      expect(extTier.standardFlatRatePerLanguage, equals(1.25));

      final longTier = ChannelWalletService.getDubbingDurationTier(3200);
      expect(longTier.id, equals('tier_longform'));
      expect(longTier.standardFlatRatePerLanguage, equals(2.50));

      final beyondTier = ChannelWalletService.getDubbingDurationTier(7200);
      expect(beyondTier.id, equals('tier_longform'));
    });

    test('Total dubbing cost combines language count and duration tier correctly', () {
      // 1. Zero languages -> $0.00
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 0,
          durationSeconds: 300,
        ),
        equals(0.0),
      );

      // 2. 2 Languages for 45s Short Video
      // Standard: 2 * $0.10 = $0.20
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 2,
          durationSeconds: 45,
        ),
        equals(0.20),
      );
      // Custom: 2 * $0.10 = $0.20
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 2,
          durationSeconds: 45,
          channelType: ChannelType.custom,
        ),
        equals(0.20),
      );

      // 3. 3 Languages for 8-minute Standard Video (480s)
      // Standard: 3 * $0.50 = $1.50
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 3,
          durationSeconds: 480,
        ),
        equals(1.50),
      );
      // Custom: 3 * $0.50 = $1.50
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 3,
          durationSeconds: 480,
          channelType: ChannelType.custom,
        ),
        equals(1.50),
      );

      // 4. 4 Languages for 25-minute Extended Video (1500s)
      // Standard: 4 * $1.25 = $5.00
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 4,
          durationSeconds: 1500,
        ),
        equals(5.00),
      );
      // Custom: 4 * $1.25 = $5.00
      expect(
        ChannelWalletService.calculateDubbingCost(
          languageCount: 4,
          durationSeconds: 1500,
          channelType: ChannelType.custom,
        ),
        equals(5.00),
      );

      // 5. Total AI Bundle with Duration
      // Features: subtitles (2 langs @ $0.025 => $0.05), dubbing (2 langs @ $0.10 => $0.20), factcheck ($0.00 Free), summary ($0.00 Free)
      // Total = $0.05 + $0.20 + $0.00 + $0.00 = $0.25
      final totalShortBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'summary'},
        targetLanguages: ['te', 'hi'],
        durationSeconds: 50,
      );
      expect(totalShortBundle, equals(0.25));
    });

    test('Calculates Tiered Subtitle Pricing based on video duration and channel type', () {
      // Rates and duration tier verification
      expect(ChannelWalletService.subtitleDurationTiers.length, equals(4));

      // Tier 1: 2 to 5 mins (120s – 300s)
      final miniTier = ChannelWalletService.getSubtitleDurationTier(180);
      expect(miniTier.id, equals('sub_tier_mini'));
      expect(miniTier.standardFlatRatePerLanguage, equals(0.025));
      expect(miniTier.customFlatRatePerLanguage, equals(0.025));

      // Tier 2: 5 to 10 mins (301s – 600s)
      final stdTier = ChannelWalletService.getSubtitleDurationTier(480);
      expect(stdTier.id, equals('sub_tier_standard'));
      expect(stdTier.standardFlatRatePerLanguage, equals(0.05));
      expect(stdTier.customFlatRatePerLanguage, equals(0.05));

      // Tier 3: 10 to 30 mins (601s – 1800s)
      final extTier = ChannelWalletService.getSubtitleDurationTier(1200);
      expect(extTier.id, equals('sub_tier_extended'));
      expect(extTier.standardFlatRatePerLanguage, equals(0.10));
      expect(extTier.customFlatRatePerLanguage, equals(0.10));

      // Tier 4: 30 to 60 mins (1801s – 3600s)
      final longTier = ChannelWalletService.getSubtitleDurationTier(2400);
      expect(longTier.id, equals('sub_tier_longform'));
      expect(longTier.standardFlatRatePerLanguage, equals(0.20));
      expect(longTier.customFlatRatePerLanguage, equals(0.20));

      // Subtitle Cost Calculations:
      // 1. 2 to 5 mins (180s) - 5 languages
      // Standard: 5 * $0.025 = $0.125 -> rounded $0.13
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 180,
        ),
        equals(0.13),
      );
      // Custom: 5 * $0.025 = $0.125 -> rounded $0.13
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 180,
          channelType: ChannelType.custom,
        ),
        equals(0.13),
      );

      // 2. Standard Video (480s / 8 mins) - 5 languages
      // Standard: 5 * $0.05 = $0.25
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 480,
        ),
        equals(0.25),
      );
      // Custom: 5 * $0.05 = $0.25
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 480,
          channelType: ChannelType.custom,
        ),
        equals(0.25),
      );

      // 3. Extended Video (1200s / 20 mins) - 5 languages
      // Standard: 5 * $0.10 = $0.50
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 1200,
        ),
        equals(0.50),
      );
      // Custom: 5 * $0.10 = $0.50
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 1200,
          channelType: ChannelType.custom,
        ),
        equals(0.50),
      );

      // 4. Long-form Video (2400s / 40 mins) - 5 languages
      // Standard: 5 * $0.20 = $1.00
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 2400,
        ),
        equals(1.00),
      );
      // Custom: 5 * $0.20 = $1.00
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 5,
          durationSeconds: 2400,
          channelType: ChannelType.custom,
        ),
        equals(1.00),
      );

      // 5. Minimum clamp on 1 language (Min = $0.05 for all channels)
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 1,
          durationSeconds: 180,
        ),
        equals(0.05), // 1 * 0.025 = 0.025 -> clamped to min $0.05
      );
      expect(
        ChannelWalletService.calculateSubtitleCost(
          languageCount: 1,
          durationSeconds: 180,
          channelType: ChannelType.custom,
        ),
        equals(0.05), // 1 * 0.025 = 0.025 -> clamped to min $0.05
      );
    });

    test('Calculates Tiered AI Fact-Checking Pricing based on video duration and channel type', () {
      // 1. Tiers verification - 100% Free platform sponsored
      expect(ChannelWalletService.factCheckDurationTiers.length, equals(4));

      // Tier 1: Quick Analysis (<= 600s / 10 mins)
      final quickTier = ChannelWalletService.getFactCheckDurationTier(300);
      expect(quickTier.id, equals('fc_tier_mini'));
      expect(quickTier.standardFlatRate, equals(0.0));
      expect(quickTier.customFlatRate, equals(0.0));

      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 300),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 300,
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Tier 2: Standard Video (601s - 1800s / 10 to 30 mins)
      final standardTier = ChannelWalletService.getFactCheckDurationTier(1200);
      expect(standardTier.id, equals('fc_tier_standard'));
      expect(standardTier.standardFlatRate, equals(0.0));
      expect(standardTier.customFlatRate, equals(0.0));

      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 1200),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 1200,
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Tier 3: Extended Deep-Dive (1801s - 3600s / 30 to 60 mins)
      final extTier = ChannelWalletService.getFactCheckDurationTier(2400);
      expect(extTier.id, equals('fc_tier_extended'));
      expect(extTier.standardFlatRate, equals(0.0));
      expect(extTier.customFlatRate, equals(0.0));

      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 2400),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 2400,
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Tier 4: Feature-Length (> 3600s / 60+ mins)
      final featureTier = ChannelWalletService.getFactCheckDurationTier(4000);
      expect(featureTier.id, equals('fc_tier_feature'));
      expect(featureTier.standardFlatRate, equals(0.0));
      expect(featureTier.customFlatRate, equals(0.0));

      // 4200s (70 mins)
      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 4200),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 4200,
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Default when duration is 0 or omitted
      expect(ChannelWalletService.calculateFactCheckCost(), equals(0.0));
      expect(
        ChannelWalletService.calculateFactCheckCost(channelType: ChannelType.custom),
        equals(0.0),
      );

      // Full AIFeatureCost integration with Fact-Checking is 100% Free
      final stdCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'factcheck'},
        targetLanguages: ['en'],
        durationSeconds: 1200,
      );
      expect(stdCost, equals(0.0));

      final customCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'factcheck'},
        targetLanguages: ['en'],
        durationSeconds: 1200,
        channelType: ChannelType.custom,
      );
      expect(customCost, equals(0.0));
    });

    test('Verifies Channel Fact-Checking Monthly Pass Tiers', () {
      expect(ChannelWalletService.channelFactCheckPlans.length, equals(1));
      final freePlan = ChannelWalletService.channelFactCheckPlans[0];

      expect(freePlan.id, equals('fc_plan_free_standard'));
      expect(freePlan.priceUSD, equals(0.0));
      expect(freePlan.billingPeriod, equals('100% Free'));
    });

    test('Verifies Fact-Checking Depth Plans and Metadata', () {
      expect(ChannelWalletService.factCheckDepthPlans.length, equals(1));

      final fullGroundPlan = ChannelWalletService.getFactCheckDepthPlan('full_ground');
      expect(fullGroundPlan.id, equals('full_ground'));
      expect(fullGroundPlan.title, equals('Complete Ground-Truth Fact-Checking'));
      expect(fullGroundPlan.badgeLabel, equals('100% VERIFIED'));
      expect(fullGroundPlan.priceMultiplier, equals(0.0));

      // Legacy tiers and unknown tiers all safely resolve to unified full ground-truth plan
      final shortPlan = ChannelWalletService.getFactCheckDepthPlan('short');
      expect(shortPlan.id, equals('full_ground'));

      final standardPlan = ChannelWalletService.getFactCheckDepthPlan('standard');
      expect(standardPlan.id, equals('full_ground'));

      final fallbackPlan = ChannelWalletService.getFactCheckDepthPlan('unknown_tier');
      expect(fallbackPlan.id, equals('full_ground'));
    });

    test('Verifies Complete Ground-Truth Fact-Checking is 100% Free Across All Durations & Channels', () {
      // Tier 1: <= 10m
      expect(ChannelWalletService.getFlatFactCheckPrice(), equals(0.0));
      expect(
        ChannelWalletService.getFlatFactCheckPrice(channelType: ChannelType.custom),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 300, tierType: 'full_ground'),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 300,
          tierType: 'full_ground',
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Tier 2: 10 - 30m (1200s)
      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 1200, tierType: 'full_ground'),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 1200,
          tierType: 'full_ground',
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Tier 3: 30 - 60m (2400s)
      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 2400, tierType: 'full_ground'),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 2400,
          tierType: 'full_ground',
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Tier 4: Feature-length (4200s: 70m)
      expect(
        ChannelWalletService.calculateFactCheckCost(durationSeconds: 4200, tierType: 'full_ground'),
        equals(0.0),
      );
      expect(
        ChannelWalletService.calculateFactCheckCost(
          durationSeconds: 4200,
          tierType: 'full_ground',
          channelType: ChannelType.custom,
        ),
        equals(0.0),
      );

      // Full AIFeatureCost integration with Full Ground Fact-Checking
      final fullCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'factcheck'},
        targetLanguages: ['en'],
        durationSeconds: 1200,
        factCheckTier: 'full_ground',
      );
      expect(fullCost, equals(0.0));

      final fullCustomCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'factcheck'},
        targetLanguages: ['en'],
        durationSeconds: 1200,
        factCheckTier: 'full_ground',
        channelType: ChannelType.custom,
      );
      expect(fullCustomCost, equals(0.0));

      // Legacy tier names still evaluate to $0.00
      expect(ChannelWalletService.getFlatFactCheckPrice(tierType: 'short'), equals(0.0));
      expect(ChannelWalletService.getFlatFactCheckPrice(tierType: 'standard'), equals(0.0));
    });

    test('SpendableBalance mathematical breakdown includes rollover credits', () {
      final service = ChannelWalletService();
      final ch = Channel(
        id: 'ch_test_123',
        name: 'Test Channel',
        nameLowercase: 'test channel',
        handle: '@testchannel',
        handleLowercase: '@testchannel',
        description: 'Test description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_user_456',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        walletBalanceUSD: 15.00,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_test_123',
          rolloverCreditUSD: 7.50,
        ),
      );

      final spendable = service.getSpendableBalance(
        channel: ch,
        rawTotalRevenue: 30.00,
        withdrawableRevenue: 20.00,
        lockedRevenue: 10.00,
      );

      // Verify that totalSpendable equals funded + rollover + totalRevenue
      expect(spendable.fundedBalance, equals(15.00));
      expect(spendable.rolloverCredit, equals(7.50));
      expect(spendable.totalRevenue, equals(30.00));
      expect(spendable.totalSpendableBalance, equals(52.50));

      // Spendable breakdown string formatting
      final breakdownStr =
          'Available Spendable: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} '
          '(\$${spendable.fundedBalance.toStringAsFixed(2)} Wallet + '
          '\$${spendable.totalRevenue.toStringAsFixed(2)} Revenue'
          '${spendable.rolloverCredit > 0 ? " + \$${spendable.rolloverCredit.toStringAsFixed(2)} Rollover" : ""})';

      expect(
        breakdownStr,
        equals(r'Available Spendable: $52.50 ($15.00 Wallet + $30.00 Revenue + $7.50 Rollover)'),
      );
    });

    test('streamChannelTransactions queries with channelId and optional userId', () {
      final mockFirestore = MockFirestore();
      final mockCollection = MockCollectionReference();
      final mockQuery = MockQuery();

      when(() => mockFirestore.collection('channel_wallet_transactions')).thenReturn(mockCollection);
      when(() => mockCollection.where('channelId', isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.where('userId', isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.orderBy('timestamp', descending: true)).thenReturn(mockQuery);
      when(() => mockQuery.limit(20)).thenReturn(mockQuery);
      when(() => mockQuery.snapshots()).thenAnswer((_) => const Stream.empty());

      final service = ChannelWalletService(firestore: mockFirestore);
      expect(
        () => service.streamChannelTransactions('ch_test', userId: 'user_test'),
        returnsNormally,
      );
    });
  });
}
