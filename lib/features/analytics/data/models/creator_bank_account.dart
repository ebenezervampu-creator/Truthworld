import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a creator's verified bank account for direct revenue withdrawals.
class CreatorBankAccount {
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String accountType; // 'Savings' or 'Current'
  final bool isDefault;
  final bool isVerified;
  final DateTime? updatedAt;

  const CreatorBankAccount({
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.accountType = 'Savings',
    this.isDefault = true,
    this.isVerified = true,
    this.updatedAt,
  });

  /// Masked representation for display e.g. "•••• •••• 4321"
  String get maskedAccountNumber {
    final clean = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length <= 4) return clean;
    final last4 = clean.substring(clean.length - 4);
    return '•••• •••• $last4';
  }

  /// Formatted IFSC Code in uppercase
  String get formattedIfsc => ifscCode.trim().toUpperCase();

  /// Validate Indian IFSC code (11 alphanumeric, 5th character '0')
  static bool isValidIfsc(String ifsc) {
    final trimmed = ifsc.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    return regex.hasMatch(trimmed);
  }

  /// Validate bank account number (9 to 18 digits)
  static bool isValidAccountNumber(String acc) {
    final clean = acc.replaceAll(RegExp(r'\s+'), '');
    final regex = RegExp(r'^\d{9,18}$');
    return regex.hasMatch(clean);
  }

  /// Guess bank name from IFSC prefix if not supplied
  static String inferBankName(String ifsc) {
    final prefix = ifsc.trim().toUpperCase();
    if (prefix.startsWith('SBIN')) return 'State Bank of India (SBI)';
    if (prefix.startsWith('HDFC')) return 'HDFC Bank';
    if (prefix.startsWith('ICIC')) return 'ICICI Bank';
    if (prefix.startsWith('AXIS') || prefix.startsWith('UTIB')) return 'Axis Bank';
    if (prefix.startsWith('PUNB')) return 'Punjab National Bank';
    if (prefix.startsWith('BARB')) return 'Bank of Baroda';
    if (prefix.startsWith('KKBK')) return 'Kotak Mahindra Bank';
    if (prefix.startsWith('YESB')) return 'Yes Bank';
    if (prefix.startsWith('INDB')) return 'IndusInd Bank';
    if (prefix.startsWith('CNRB')) return 'Canara Bank';
    if (prefix.startsWith('UBIN')) return 'Union Bank of India';
    if (prefix.startsWith('IDFB')) return 'IDFC First Bank';
    return 'Direct Bank Transfer';
  }

  Map<String, dynamic> toMap() => {
        'accountHolderName': accountHolderName.trim(),
        'accountNumber': accountNumber.trim(),
        'accountNumberMasked': maskedAccountNumber,
        'ifscCode': formattedIfsc,
        'bankName': bankName.trim(),
        'accountType': accountType,
        'isDefault': isDefault,
        'isVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory CreatorBankAccount.fromMap(Map<String, dynamic> map) {
    return CreatorBankAccount(
      accountHolderName: (map['accountHolderName'] as String?)?.trim() ?? '',
      accountNumber: (map['accountNumber'] as String?)?.trim() ?? '',
      ifscCode: (map['ifscCode'] as String?)?.trim().toUpperCase() ?? '',
      bankName: (map['bankName'] as String?)?.trim() ?? 'Direct Bank',
      accountType: (map['accountType'] as String?)?.trim() ?? 'Savings',
      isDefault: map['isDefault'] as bool? ?? true,
      isVerified: map['isVerified'] as bool? ?? true,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  CreatorBankAccount copyWith({
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? accountType,
    bool? isDefault,
    bool? isVerified,
    DateTime? updatedAt,
  }) {
    return CreatorBankAccount(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
      accountType: accountType ?? this.accountType,
      isDefault: isDefault ?? this.isDefault,
      isVerified: isVerified ?? this.isVerified,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
