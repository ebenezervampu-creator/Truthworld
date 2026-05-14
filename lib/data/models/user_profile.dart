import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/data/models/user_model.dart';

/// User profile model for storing user data in Firestore
class UserProfile {
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

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
    required this.createdAt,
    required this.lastLogin,
    this.isEmailVerified = false,
    this.isActive = true,
    this.metadata,
  });

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
    };
  }

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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLogin: (data['lastLogin'] as Timestamp).toDate(),
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
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
      isActive: true,
      metadata: metadata,
    );
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
    );
  }

  @override
  String toString() => 'UserProfile(uid: $uid, email: $email)';
}





