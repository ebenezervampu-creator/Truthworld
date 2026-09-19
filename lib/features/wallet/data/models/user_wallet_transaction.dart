import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for user wallet transactions
enum UserWalletTransactionCategory {
  topup,
  superchat,
  membership,
  tip,
  premium,
  ppv,
  refund,
  other;

  String get displayName {
    switch (this) {
      case UserWalletTransactionCategory.topup:
        return 'Wallet Top-Up';
      case UserWalletTransactionCategory.superchat:
        return 'Superchat';
      case UserWalletTransactionCategory.membership:
        return 'Channel Membership';
      case UserWalletTransactionCategory.tip:
        return 'Creator Tip';
      case UserWalletTransactionCategory.premium:
        return 'Premium Subscription';
      case UserWalletTransactionCategory.ppv:
        return 'Pay-Per-View';
      case UserWalletTransactionCategory.refund:
        return 'Refund';
      case UserWalletTransactionCategory.other:
        return 'Payment';
    }
  }

  static UserWalletTransactionCategory fromString(String? value) {
    if (value == null) return UserWalletTransactionCategory.other;
    final normalized = value.toLowerCase().replaceAll('-', '_').trim();
    return UserWalletTransactionCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => UserWalletTransactionCategory.other,
    );
  }
}

/// Transaction type: credit (deposit/money in) or debit (spend/money out)
enum UserWalletTransactionType {
  credit,
  debit;

  static UserWalletTransactionType fromString(String? value) {
    if (value == null) return UserWalletTransactionType.debit;
    return value.toLowerCase().trim() == 'credit'
        ? UserWalletTransactionType.credit
        : UserWalletTransactionType.debit;
  }
}

/// Production-grade user wallet transaction record stored under `users/{userId}/wallet_transactions/{txId}`
class UserWalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final UserWalletTransactionType type;
  final UserWalletTransactionCategory category;
  final String description;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime timestamp;
  final String? paymentGateway;
  final String? orderId;
  final Map<String, dynamic>? metadata;

  const UserWalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.timestamp,
    this.paymentGateway,
    this.orderId,
    this.metadata,
  });

  bool get isCredit => type == UserWalletTransactionType.credit;
  bool get isDebit => type == UserWalletTransactionType.debit;

  /// Formats amount with plus/minus prefix (e.g. "+₹500.00" or "-₹100.00")
  String get formattedAmountWithSign {
    final prefix = isCredit ? '+' : '-';
    return '$prefix₹${amount.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'description': description,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'timestamp': Timestamp.fromDate(timestamp),
      if (paymentGateway != null) 'paymentGateway': paymentGateway,
      if (orderId != null) 'orderId': orderId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory UserWalletTransaction.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    DateTime parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return UserWalletTransaction(
      id: docId,
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: UserWalletTransactionType.fromString(map['type'] as String?),
      category: UserWalletTransactionCategory.fromString(
        map['category'] as String?,
      ),
      description: map['description'] as String? ?? '',
      balanceBefore: (map['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (map['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      timestamp: parseTime(map['timestamp']),
      paymentGateway: map['paymentGateway'] as String?,
      orderId: map['orderId'] as String?,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  factory UserWalletTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserWalletTransaction.fromMap(data, doc.id);
  }
}
