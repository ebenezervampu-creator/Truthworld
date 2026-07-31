import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/data/models/user_model.dart';

/// User profile model for storing user data in Firestore
class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.provider,
    required this.createdAt,
    required this.lastLogin,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.isActive = true,
    this.metadata,
    this.gender,
    this.age,
    this.birthdate,
    this.location,
    this.city,
    this.state,
    this.country,
  });

  /// Create from Firestore document
  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UserProfile(
      uid: data['uid'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      provider: data['provider'] as String? ?? 'email',
      createdAt:
          TimestampUtils.parseToDateTime(data['createdAt']) ?? DateTime.now(),
      lastLogin:
          TimestampUtils.parseToDateTime(data['lastLogin']) ?? DateTime.now(),
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
      gender: data['gender'] as String?,
      age: (data['age'] as num?)?.toInt(),
      birthdate: data['birthdate'] as String?,
      location: data['location'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      country: data['country'] as String?,
    );
  }

  /// Create from Firebase User
  factory UserProfile.fromFirebaseUser(
    UserModel firebaseUser, {
    required String provider,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      provider: provider,
      createdAt: firebaseUser.createdAt ?? now,
      lastLogin: now,
      isEmailVerified: firebaseUser.metadata['emailVerified'] as bool? ?? false,
      metadata: metadata,
      gender: firebaseUser.gender,
      age: firebaseUser.age,
      birthdate: firebaseUser.birthdate,
      location: firebaseUser.location,
      city: firebaseUser.city,
      state: firebaseUser.state,
      country: firebaseUser.country,
    );
  }
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String provider; // 'google', 'email', 'apple', etc.
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isEmailVerified;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final String? gender;
  final int? age;
  final String? birthdate;
  final String? location;
  final String? city;
  final String? state;
  final String? country;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'provider': provider,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
      'isEmailVerified': isEmailVerified,
      'isActive': isActive,
      'metadata': metadata,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (birthdate != null) 'birthdate': birthdate,
      if (location != null) 'location': location,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? provider,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isEmailVerified,
    bool? isActive,
    Map<String, dynamic>? metadata,
    String? gender,
    int? age,
    String? birthdate,
    String? location,
    String? city,
    String? state,
    String? country,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      birthdate: birthdate ?? this.birthdate,
      location: location ?? this.location,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
    );
  }

  @override
  String toString() => 'UserProfile(uid: $uid, email: $email)';
}
