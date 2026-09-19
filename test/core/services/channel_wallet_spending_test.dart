import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';

void main() {
  group('ChannelWalletService Unit Tests', () {
    test('Calculates AI feature costs accurately', () {
      // 1. Fact-checking only
      final costFactcheck = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'factcheck'},
        targetLanguages: ['en'],
      );
      expect(costFactcheck, equals(2.00));

      // 2. Subtitles only in 3 languages ($0.10/lang, min $0.50)
      final costSubtitles = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles'},
        targetLanguages: ['te', 'hi', 'en'],
      );
      expect(costSubtitles, equals(0.50)); // Hit min clamp

      // 3. Dubbing only in 4 languages ($0.50/lang, min $1.50)
      final costDubbing = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'dubbing'},
        targetLanguages: ['te', 'hi', 'en', 'es'],
      );
      expect(costDubbing, equals(2.00));

      // 4. Chapters & Summary ($0.50)
      final costSummary = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'summary', 'chapters'},
        targetLanguages: ['en'],
      );
      expect(costSummary, equals(0.50));

      // 5. Complete bundle: Subtitles, Dubbing, Factcheck, Chapters (3 languages)
      // Subtitles = $0.50, Dubbing = $1.50, Factcheck = $2.00, Chapters = $0.50 => $4.50
      final costBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'chapters', 'summary'},
        targetLanguages: ['te', 'hi', 'en'],
      );
      expect(costBundle, equals(4.50));
    });

    test('Calculates Tiered Dubbing Pricing for Standard vs Custom Channels', () {
      // Rates and helper methods verification
      expect(ChannelWalletService.getDubbingRatePerLanguage(ChannelType.standard), equals(0.50));
      expect(ChannelWalletService.getDubbingMinCost(ChannelType.standard), equals(1.50));
      expect(ChannelWalletService.getDubbingCapCost(ChannelType.standard), equals(10.00));

      expect(ChannelWalletService.getDubbingRatePerLanguage(ChannelType.custom), equals(0.25));
      expect(ChannelWalletService.getDubbingMinCost(ChannelType.custom), equals(0.75));
      expect(ChannelWalletService.getDubbingCapCost(ChannelType.custom), equals(5.00));

      // 1 Language Dubbing
      // Standard: 1 * $0.50 = $0.50 -> clamped to min $1.50
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 1),
        equals(1.50),
      );
      // Custom: 1 * $0.25 = $0.25 -> clamped to min $0.75
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 1, channelType: ChannelType.custom),
        equals(0.75),
      );

      // 4 Languages Dubbing
      // Standard: 4 * $0.50 = $2.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 4),
        equals(2.00),
      );
      // Custom: 4 * $0.25 = $1.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 4, channelType: ChannelType.custom),
        equals(1.00),
      );

      // 30 Languages Dubbing (High-volume internationalization)
      // Standard: 30 * $0.50 = $15.00 -> clamped to cap $10.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 30),
        equals(10.00),
      );
      // Custom: 30 * $0.25 = $7.50 -> clamped to cap $5.00
      expect(
        ChannelWalletService.calculateDubbingCost(languageCount: 30, channelType: ChannelType.custom),
        equals(5.00),
      );

      // Full AI Bundle Comparison: 3 languages (Subtitles + Dubbing + Factcheck + Summary)
      // Subtitles ($0.50) + Factcheck ($2.00) + Summary ($0.50) = $3.00 base
      // Standard Dubbing: 3 * $0.50 = $1.50 => Total $4.50
      final standardBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'summary'},
        targetLanguages: ['te', 'hi', 'en'],
      );
      expect(standardBundle, equals(4.50));

      // Custom Dubbing: 3 * $0.25 = $0.75 => Total $3.75 (50% dubbing discount saves creator money)
      final customBundle = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing', 'factcheck', 'summary'},
        targetLanguages: ['te', 'hi', 'en'],
        channelType: ChannelType.custom,
      );
      expect(customBundle, equals(3.75));
    });

    test('SpendableBalance combines trial credit and revenue correctly', () {
      const balance = SpendableBalance(
        trialCreditRemaining: 10.0,
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
      expect(pack100.priceUSD, equals(9.00));
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

    test('SpendableBalance combines funded balance, trial credit and revenue correctly', () {
      const balance = SpendableBalance(
        fundedBalance: 25.0,
        trialCreditRemaining: 10.0,
        withdrawableRevenue: 20.0,
        lockedRevenue: 15.0,
      );

      expect(balance.fundedBalance, equals(25.0));
      expect(balance.trialCreditRemaining, equals(10.0));
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
  });
}
