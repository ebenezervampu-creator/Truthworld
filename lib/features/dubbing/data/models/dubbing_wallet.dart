/// Represents a transaction in the user's pay-as-you-go dubbing wallet.
class DubbingWalletTx {
  final String id;
  final String type; // 'trial_credit', 'topup', 'job_debit', 'refund'
  final int amountCredits;
  final double amountUsd;
  final String description;
  final DateTime timestamp;

  const DubbingWalletTx({
    required this.id,
    required this.type,
    required this.amountCredits,
    required this.amountUsd,
    required this.description,
    required this.timestamp,
  });

  factory DubbingWalletTx.fromMap(Map<String, dynamic> map) {
    final rawTs = map['timestamp'];
    final ts = rawTs is num
        ? DateTime.fromMillisecondsSinceEpoch(rawTs.toInt())
        : DateTime.now();

    return DubbingWalletTx(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'job_debit',
      amountCredits: (map['amountCredits'] as num?)?.toInt() ?? 0,
      amountUsd: (map['amountUsd'] as num?)?.toDouble() ?? 0.0,
      description: map['description']?.toString() ?? '',
      timestamp: ts,
    );
  }
}

/// User's Dubbing Wallet state.
class DubbingWallet {
  final String userId;
  final int balanceCredits;
  final double balanceUsd;
  final bool trialClaimed;
  final int totalCharactersUsed;
  final double totalSpentUsd;
  final double specialDiscountPercent;
  final String specialDiscountType;
  final bool isDubbingFree;
  final String discountReason;
  final String discountAppliedBy;
  final List<DubbingWalletTx> transactions;

  const DubbingWallet({
    this.userId = '',
    this.balanceCredits = 0,
    this.balanceUsd = 0.0,
    this.trialClaimed = false,
    this.totalCharactersUsed = 0,
    this.totalSpentUsd = 0.0,
    this.specialDiscountPercent = 0.0,
    this.specialDiscountType = 'none',
    this.isDubbingFree = false,
    this.discountReason = '',
    this.discountAppliedBy = '',
    this.transactions = const [],
  });

  static const DubbingWallet empty = DubbingWallet();

  factory DubbingWallet.fromMap(Map<String, dynamic> map) {
    final txs = <DubbingWalletTx>[];
    if (map['transactions'] is List) {
      for (final item in map['transactions']) {
        if (item is Map) {
          txs.add(DubbingWalletTx.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawDiscountPercent = (map['specialDiscountPercent'] as num?)?.toDouble() ?? 0.0;
    final discountType = (map['specialDiscountType'] ?? 'none').toString();
    final free = map['isDubbingFree'] == true || discountType == 'free' || rawDiscountPercent >= 100.0;

    return DubbingWallet(
      userId: map['userId']?.toString() ?? '',
      balanceCredits: (map['balanceCredits'] as num?)?.toInt() ?? 0,
      balanceUsd: (map['balanceUsd'] as num?)?.toDouble() ?? 0.0,
      trialClaimed: map['trialClaimed'] == true,
      totalCharactersUsed: (map['totalCharactersUsed'] as num?)?.toInt() ?? 0,
      totalSpentUsd: (map['totalSpentUsd'] as num?)?.toDouble() ?? 0.0,
      specialDiscountPercent: rawDiscountPercent,
      specialDiscountType: discountType,
      isDubbingFree: free,
      discountReason: (map['discountReason'] ?? '').toString(),
      discountAppliedBy: (map['discountAppliedBy'] ?? '').toString(),
      transactions: txs,
    );
  }

  /// Helper to format balance for display.
  String get displayCreditString => '$balanceCredits characters';
  String get displayUsdString => '\$${balanceUsd.toStringAsFixed(2)}';
  String get displayUsdOrFreeString => isDubbingFree ? '100% Free' : displayUsdString;

  /// Whether any active special discount or free waiver applies.
  bool get hasSpecialDiscount => isDubbingFree || specialDiscountPercent > 0;

  /// Human-readable label for special discount.
  String get discountDisplayString {
    if (isDubbingFree) return '100% Free Waiver';
    if (specialDiscountPercent > 0) return '${specialDiscountPercent.round()}% Off';
    return 'Standard Pricing';
  }
}
