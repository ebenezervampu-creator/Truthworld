import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// KYC verification status enum
enum KycStatus {
  notSubmitted,
  pending,
  verified,
  rejected;

  String get label {
    switch (this) {
      case KycStatus.verified:
        return 'Verified';
      case KycStatus.pending:
        return 'Under Review';
      case KycStatus.rejected:
        return 'Action Required';
      case KycStatus.notSubmitted:
        return 'Not Submitted';
    }
  }

  static KycStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'verified':
        return KycStatus.verified;
      case 'pending':
        return KycStatus.pending;
      case 'rejected':
        return KycStatus.rejected;
      default:
        return KycStatus.notSubmitted;
    }
  }

  String toDbString() {
    switch (this) {
      case KycStatus.verified:
        return 'verified';
      case KycStatus.pending:
        return 'pending';
      case KycStatus.rejected:
        return 'rejected';
      case KycStatus.notSubmitted:
        return 'not_submitted';
    }
  }
}

/// Supported Identity & Address Proof types
enum IdentityProofType {
  maskedAadhaar,
  drivingLicense,
  voterId,
  passport;

  String get displayName {
    switch (this) {
      case IdentityProofType.maskedAadhaar:
        return 'Masked Aadhaar Card';
      case IdentityProofType.drivingLicense:
        return 'Driving License';
      case IdentityProofType.voterId:
        return 'Voter ID Card';
      case IdentityProofType.passport:
        return 'Passport';
    }
  }

  static IdentityProofType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'driving_license':
      case 'driving license':
        return IdentityProofType.drivingLicense;
      case 'voter_id':
      case 'voter id':
      case 'voter id card':
        return IdentityProofType.voterId;
      case 'passport':
        return IdentityProofType.passport;
      default:
        return IdentityProofType.maskedAadhaar;
    }
  }

  String toDbString() {
    switch (this) {
      case IdentityProofType.maskedAadhaar:
        return 'masked_aadhaar';
      case IdentityProofType.drivingLicense:
        return 'driving_license';
      case IdentityProofType.voterId:
        return 'voter_id';
      case IdentityProofType.passport:
        return 'passport';
    }
  }
}

/// Model holding verified creator KYC details and identity proofs
class CreatorKycVerification {
  final String channelId;
  final String userId;
  final KycStatus status;
  final String panNumber;
  final String panLegalName;
  final DateTime? dateOfBirth;
  final String panDocumentUrl;
  final IdentityProofType identityProofType;
  final String identityProofNumber;
  final String identityProofFrontUrl;
  final String? identityProofBackUrl;
  final String bankAccountName;
  final double nameMatchScore;
  final bool isNameMatched;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final Map<String, dynamic>? metadata;

  const CreatorKycVerification({
    required this.channelId,
    required this.userId,
    required this.panNumber,
    required this.panLegalName,
    this.status = KycStatus.notSubmitted,
    this.dateOfBirth,
    this.panDocumentUrl = '',
    this.identityProofType = IdentityProofType.maskedAadhaar,
    this.identityProofNumber = '',
    this.identityProofFrontUrl = '',
    this.identityProofBackUrl,
    this.bankAccountName = '',
    this.nameMatchScore = 0.0,
    this.isNameMatched = false,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.metadata,
  });

  /// Check if KYC is officially verified for payouts
  bool get isVerified => status == KycStatus.verified;

  /// Check if KYC is pending review
  bool get isPending => status == KycStatus.pending;

  /// Check if KYC is rejected
  bool get isRejected => status == KycStatus.rejected;

  /// Check if KYC has not been submitted yet
  bool get isNotSubmitted => status == KycStatus.notSubmitted;

  /// Masked PAN representation (e.g., "ABCDE••••F")
  String get maskedPan {
    final clean = panNumber.trim().toUpperCase();
    if (clean.length < 10) return clean;
    return '${clean.substring(0, 5)}••••${clean.substring(9)}';
  }

  /// Formatted date of birth string e.g. "15/08/1995"
  String get formattedDob {
    if (dateOfBirth == null) return '';
    final d = dateOfBirth!.day.toString().padLeft(2, '0');
    final m = dateOfBirth!.month.toString().padLeft(2, '0');
    final y = dateOfBirth!.year.toString();
    return '$d/$m/$y';
  }

  /// Indian PAN validation (10 alphanumeric characters: 5 uppercase letters, 4 digits, 1 uppercase letter)
  static bool isValidPan(String pan) {
    final trimmed = pan.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return regex.hasMatch(trimmed);
  }

  /// Age check: must be at least 18 years old
  static bool isValidAge(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  /// Tokenized Jaccard & Levenshtein string similarity for Bank Name vs PAN Legal Name
  /// Returns a confidence score between 0.0 (no match) and 1.0 (exact match)
  static double calculateNameMatchScore(String name1, String name2) {
    final s1 = _normalizeName(name1);
    final s2 = _normalizeName(name2);

    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    final tokens1 = s1.split(' ').where((t) => t.isNotEmpty).toSet();
    final tokens2 = s2.split(' ').where((t) => t.isNotEmpty).toSet();

    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;

    // Token Jaccard similarity
    final intersection = tokens1.intersection(tokens2).length;
    final union = tokens1.union(tokens2).length;
    final jaccard = union > 0 ? (intersection / union) : 0.0;

    // Direct subset check: e.g. "Ebenezer Vampu" and "Vampu Ebenezer" or "Ebenezer Vampu John"
    if (tokens1.containsAll(tokens2) || tokens2.containsAll(tokens1)) {
      return math.max(0.90, jaccard);
    }

    // Levenshtein similarity on sorted combined tokens
    final sorted1 = (tokens1.toList()..sort()).join(' ');
    final sorted2 = (tokens2.toList()..sort()).join(' ');
    final levSim = _levenshteinSimilarity(sorted1, sorted2);

    return math.max(jaccard, levSim);
  }

  /// Determine if two names match sufficiently for KYC compliance (threshold >= 0.70)
  static bool isNameMatching(String bankName, String panLegalName) {
    return calculateNameMatchScore(bankName, panLegalName) >= 0.70;
  }

  static String _normalizeName(String input) {
    var cleaned = input.toLowerCase().trim();
    // Remove common honorifics
    final honorifics = ['mr', 'mrs', 'ms', 'dr', 'shri', 'smt', 'md', 'mister', 'miss'];
    for (final h in honorifics) {
      cleaned = cleaned.replaceAll(RegExp('\\b$h\\b[.]?'), '');
    }
    // Remove punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    // Remove extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  static double _levenshteinSimilarity(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0 && len2 == 0) return 1.0;
    if (len1 == 0 || len2 == 0) return 0.0;

    var previousRow = List<int>.generate(len2 + 1, (i) => i);
    var currentRow = List<int>.filled(len2 + 1, 0);

    for (var i = 0; i < len1; i++) {
      currentRow[0] = i + 1;
      for (var j = 0; j < len2; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        currentRow[j + 1] = math.min(
          currentRow[j] + 1,
          math.min(previousRow[j + 1] + 1, previousRow[j] + cost),
        );
      }
      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    final distance = previousRow[len2];
    final maxLen = math.max(len1, len2);
    return (maxLen - distance) / maxLen;
  }

  factory CreatorKycVerification.fromMap(Map<String, dynamic> data, {String? channelId, String? userId}) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawStatus = data['kycStatus'] as String? ?? data['status'] as String? ?? 'not_submitted';
    final panNum = (data['panNumber'] as String? ?? '').trim().toUpperCase();
    final panName = (data['panLegalName'] as String? ?? data['legalName'] as String? ?? '').trim();
    final bankName = (data['bankAccountName'] as String? ?? '').trim();

    final score = (data['nameMatchScore'] as num?)?.toDouble() ??
        (panName.isNotEmpty && bankName.isNotEmpty
            ? calculateNameMatchScore(bankName, panName)
            : 0.0);

    return CreatorKycVerification(
      channelId: channelId ?? data['channelId'] as String? ?? '',
      userId: userId ?? data['userId'] as String? ?? '',
      status: KycStatus.fromString(rawStatus),
      panNumber: panNum,
      panLegalName: panName,
      dateOfBirth: parseDate(data['dateOfBirth']),
      panDocumentUrl: data['panDocumentUrl'] as String? ?? '',
      identityProofType: IdentityProofType.fromString(data['identityProofType'] as String?),
      identityProofNumber: (data['identityProofNumber'] as String? ?? '').trim(),
      identityProofFrontUrl: data['identityProofFrontUrl'] as String? ?? '',
      identityProofBackUrl: data['identityProofBackUrl'] as String?,
      bankAccountName: bankName,
      nameMatchScore: score,
      isNameMatched: data['isNameMatched'] as bool? ?? (score >= 0.70),
      rejectionReason: data['rejectionReason'] as String?,
      submittedAt: parseDate(data['submittedAt']),
      reviewedAt: parseDate(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'channelId': channelId,
      'userId': userId,
      'kycStatus': status.toDbString(),
      'panNumber': panNumber.trim().toUpperCase(),
      'panLegalName': panLegalName.trim(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'panDocumentUrl': panDocumentUrl,
      'identityProofType': identityProofType.toDbString(),
      'identityProofNumber': identityProofNumber.trim(),
      'identityProofFrontUrl': identityProofFrontUrl,
      'identityProofBackUrl': identityProofBackUrl,
      'bankAccountName': bankAccountName.trim(),
      'nameMatchScore': nameMatchScore,
      'isNameMatched': isNameMatched,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (metadata != null) 'metadata': metadata,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CreatorKycVerification copyWith({
    String? channelId,
    String? userId,
    KycStatus? status,
    String? panNumber,
    String? panLegalName,
    DateTime? dateOfBirth,
    String? panDocumentUrl,
    IdentityProofType? identityProofType,
    String? identityProofNumber,
    String? identityProofFrontUrl,
    String? identityProofBackUrl,
    String? bankAccountName,
    double? nameMatchScore,
    bool? isNameMatched,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    Map<String, dynamic>? metadata,
  }) {
    return CreatorKycVerification(
      channelId: channelId ?? this.channelId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      panNumber: panNumber ?? this.panNumber,
      panLegalName: panLegalName ?? this.panLegalName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      panDocumentUrl: panDocumentUrl ?? this.panDocumentUrl,
      identityProofType: identityProofType ?? this.identityProofType,
      identityProofNumber: identityProofNumber ?? this.identityProofNumber,
      identityProofFrontUrl: identityProofFrontUrl ?? this.identityProofFrontUrl,
      identityProofBackUrl: identityProofBackUrl ?? this.identityProofBackUrl,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      nameMatchScore: nameMatchScore ?? this.nameMatchScore,
      isNameMatched: isNameMatched ?? this.isNameMatched,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      metadata: metadata ?? this.metadata,
    );
  }
}
