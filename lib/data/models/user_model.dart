// ==========================================================================
// UserModel — Scalable user data model for millions of users
// Designed for Firestore serialization with optimized read/write patterns
// ==========================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Authentication provider types
enum AuthProvider {
  google,
  email,
  anonymous;

  String get value {
    switch (this) {
      case AuthProvider.google:
        return 'google.com';
      case AuthProvider.email:
        return 'password';
      case AuthProvider.anonymous:
        return 'anonymous';
    }
  }

  static AuthProvider fromString(String value) {
    switch (value) {
      case 'google.com':
        return AuthProvider.google;
      case 'password':
        return AuthProvider.email;
      default:
        return AuthProvider.anonymous;
    }
  }
}

/// User account status
enum AccountStatus {
  active,
  suspended,
  deleted;

  String get value => name;

  static AccountStatus fromString(String value) {
    switch (value) {
      case 'suspended':
        return AccountStatus.suspended;
      case 'deleted':
        return AccountStatus.deleted;
      default:
        return AccountStatus.active;
    }
  }
}

/// Industry-standard user model optimized for Firestore at scale
///
/// Design decisions for millions of users:
/// - Flat document structure (avoids nested reads)
/// - `fcmTokens` as a `Map<deviceId, token>` for multi-device push
/// - `metadata` as extensible Map for future fields without schema migration
/// - Server timestamps for consistency across clients
/// - Immutable fields (`uid`, `email`, `provider`, `createdAt`) enforced by rules
class UserModel {
  // Primary channel ID

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoURL = '',
    this.provider = AuthProvider.google,
    this.status = AccountStatus.active,
    this.createdAt,
    this.lastLoginAt,
    this.fcmTokens = const {},
    this.metadata = const {},
    this.channelId,
    this.gender,
    this.age,
    this.birthdate,
    this.location,
    this.city,
    this.state,
    this.country,
    this.hasCompletedOnboarding = false,
    this.ageGroup,
    this.walletBalance = 0.0,
  });

  /// Create from Firestore document snapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoURL: data['photoURL'] as String? ?? '',
      provider: AuthProvider.fromString(data['provider'] as String? ?? ''),
      status: AccountStatus.fromString(data['status'] as String? ?? 'active'),
      createdAt: _toDateTime(data['createdAt']),
      lastLoginAt: _toDateTime(data['lastLoginAt']),
      fcmTokens: (data['fcmTokens'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map ? (value['token'] as String? ?? '') : value.toString(),
        ),
      ),
      metadata: Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
      channelId: data['channelId'] as String?,
      gender: data['gender'] as String?,
      age: _sanitizeAge((data['age'] as num?)?.toInt()),
      birthdate: data['birthdate'] as String?,
      location: data['location'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      country: data['country'] as String?,
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      ageGroup: data['ageGroup'] as String?,
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Create from Firebase Auth User (for initial sign-in)
  factory UserModel.fromFirebaseUser(User user) {
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'anonymous';

    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      photoURL: user.photoURL ?? '',
      provider: AuthProvider.fromString(providerId),
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }
  final String uid;
  final String email;
  final String displayName;
  final String photoURL;
  final AuthProvider provider;
  final AccountStatus status;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final Map<String, String> fcmTokens; // deviceId → token
  final Map<String, dynamic> metadata; // extensible key-value store
  final String? channelId;
  final String? gender;
  final int? age;
  final String? birthdate;
  final String? location;
  final String? city;
  final String? state;
  final String? country;
  final bool hasCompletedOnboarding;
  final String? ageGroup;
  final double walletBalance;

  /// Serialize for Firestore document creation
  /// Uses `FieldValue.serverTimestamp()` for consistent timestamps
  Map<String, dynamic> toFirestoreCreate() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'name': displayName, // Compatibility
      'username': displayName, // Compatibility
      'photoURL': photoURL,
      'provider': provider.value,
      'status': status.value,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'fcmTokens': fcmTokens,
      'metadata': metadata,
      'channelId': channelId,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'walletBalance': walletBalance,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (birthdate != null) 'birthdate': birthdate,
      if (location != null) 'location': location,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (ageGroup != null) 'ageGroup': ageGroup,
    };
  }

  /// Serialize for Firestore document update (login refresh)
  /// Only updates mutable fields — never overwrites `uid`, `email`, `createdAt`
  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'displayName': displayName,
      'name': displayName, // Compatibility
      'photoURL': photoURL,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'status': status.value,
      'channelId': channelId,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'walletBalance': walletBalance,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (birthdate != null) 'birthdate': birthdate,
      if (location != null) 'location': location,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (ageGroup != null) 'ageGroup': ageGroup,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? displayName,
    String? photoURL,
    AccountStatus? status,
    DateTime? lastLoginAt,
    Map<String, String>? fcmTokens,
    Map<String, dynamic>? metadata,
    String? channelId,
    String? gender,
    int? age,
    String? birthdate,
    String? location,
    String? city,
    String? state,
    String? country,
    bool? hasCompletedOnboarding,
    String? ageGroup,
    double? walletBalance,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      provider: provider,
      status: status ?? this.status,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      metadata: metadata ?? this.metadata,
      channelId: channelId ?? this.channelId,
      gender: gender ?? this.gender,
      age: _sanitizeAge(age) ?? this.age,
      birthdate: birthdate ?? this.birthdate,
      location: location ?? this.location,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      ageGroup: ageGroup ?? this.ageGroup,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }

  /// Rejects any age outside the valid human range [1, 120].
  /// Returns null for out-of-range or null input so corrupt legacy / external
  /// data is silently discarded rather than persisted.
  static int? _sanitizeAge(int? raw) {
    if (raw == null) return null;
    if (raw < 1 || raw > 120) return null;
    return raw;
  }

  /// Helper to convert Firestore Timestamp to DateTime
  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, name: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
