import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';

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

    test('WalletTransaction serialization and deserialization works cleanly', () {
      final tx = WalletTransaction(
        id: 'tx_demo_123',
        channelId: 'ch_test_999',
        userId: 'user_456',
        amount: 5.0,
        trialCreditDeducted: 5.0,
        revenueDeducted: 0.0,
        category: WalletTransactionCategory.storageTopup,
        description: 'Storage Add-on: +50 GB',
        balanceBefore: 10.0,
        balanceAfter: 5.0,
        timestamp: DateTime(2026, 8, 18),
        metadata: {'packId': 'storage_50gb', 'gigabytes': 50},
      );

      final map = tx.toMap();
      expect(map['id'], equals('tx_demo_123'));
      expect(map['amount'], equals(5.0));
      expect(map['category'], equals('storageTopup'));

      final fromMapTx = WalletTransaction.fromMap(map, 'tx_demo_123');
      expect(fromMapTx.id, equals('tx_demo_123'));
      expect(fromMapTx.amount, equals(5.0));
      expect(fromMapTx.trialCreditDeducted, equals(5.0));
      expect(fromMapTx.category, equals(WalletTransactionCategory.storageTopup));
      expect(fromMapTx.metadata?['gigabytes'], equals(50));
    });
  });
}
