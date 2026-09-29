import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/data/models/user_model.dart';

/// Handles Firestore user document synchronization, legacy account consolidation, and deletion.
class AuthFirestoreSync {
  bool _isSyncingUser = false;
  String? _lastSyncedUid;
  DateTime? _lastSyncTime;

  /// Synchronizes user profile and metadata into Firestore 'users' collection with legacy account migration.
  Future<void> syncUserToFirestore(
    User user, {
    required void Function(bool needsOnboarding) onNeedsOnboardingChanged,
    Map<String, dynamic>? lastGooglePeopleData,
    VoidCallback? onPromptOnboarding,
  }) async {
    if (user.isAnonymous) return;

    // Avoid duplicate simultaneous/rapid syncs during auth state startup bursts
    if (_isSyncingUser && _lastSyncedUid == user.uid) {
      debugPrint(
        'AuthFirestoreSync: Sync already in progress for UID: ${user.uid}. Skipping duplicate.',
      );
      return;
    }
    if (_lastSyncedUid == user.uid &&
        _lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!).inSeconds < 10) {
      debugPrint(
        'AuthFirestoreSync: User ${user.uid} already synced recently. Skipping duplicate.',
      );
      return;
    }

    _isSyncingUser = true;
    _lastSyncedUid = user.uid;

    debugPrint(
      'AuthFirestoreSync: Starting synchronization for UID: ${user.uid}',
    );
    final userDoc = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid);

    try {
      // Capture critical security and lifecycle metadata
      final metadata = <String, dynamic>{
        'creationTime': user.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        'emailVerified': user.emailVerified,
        'phoneNumber': user.phoneNumber,
        'isAnonymous': user.isAnonymous,
        'lastSyncAt': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'web' : 'mobile',
      };

      final docSnapshot = await userDoc.get().timeout(
        const Duration(seconds: 10),
      );

      if (!docSnapshot.exists) {
        debugPrint(
          'AuthFirestoreSync: No document found by UID. Checking for legacy account with email: ${user.email}...',
        );

        String? restoredChannelId;
        Map<String, dynamic>? legacyData;

        if (user.email != null && user.email!.isNotEmpty) {
          try {
            final emailQuery = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .where('email', isEqualTo: user.email)
                .limit(5)
                .get();

            final legacyDocs =
                emailQuery.docs.where((d) => d.id != user.uid).toList();
            if (legacyDocs.isNotEmpty) {
              debugPrint(
                'AuthFirestoreSync: Found ${legacyDocs.length} legacy user doc(s) for email ${user.email}. Consolidating...',
              );
              for (final oldDoc in legacyDocs) {
                final oldData = oldDoc.data();
                legacyData ??= oldData;
                final oldChannelId = oldData['channelId'] as String?;
                if (oldChannelId != null && oldChannelId.isNotEmpty) {
                  restoredChannelId = oldChannelId;
                  // Re-assign channel ownership to active UID
                  try {
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.channels)
                        .doc(oldChannelId)
                        .update({
                          'ownerId': user.uid,
                          'userId': user.uid,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                    debugPrint(
                      'AuthFirestoreSync: Re-linked channel $oldChannelId to new UID ${user.uid}',
                    );
                  } catch (chErr, chStack) {
                    ErrorHandler.log(
                      chErr,
                      stackTrace: chStack,
                      tag: 'AuthFirestoreSync.relinkChannel',
                    );
                  }
                }

                // Remove stale legacy user document
                try {
                  await oldDoc.reference.delete();
                  debugPrint(
                    'AuthFirestoreSync: Cleaned up legacy user doc ${oldDoc.id}',
                  );
                } catch (delErr, delStack) {
                  ErrorHandler.log(
                    delErr,
                    stackTrace: delStack,
                    tag: 'AuthFirestoreSync.deleteLegacyDoc',
                  );
                }
              }
            }
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'AuthFirestoreSync.legacyQuery',
            );
          }
        }

        final hasCompletedOnboarding =
            legacyData?['hasCompletedOnboarding'] as bool? ?? false;
        onNeedsOnboardingChanged(!hasCompletedOnboarding);

        final newUser = UserModel.fromFirebaseUser(user).copyWith(
          metadata: metadata,
          channelId: restoredChannelId ?? legacyData?['channelId'] as String?,
          gender: legacyData?['gender'] as String?,
          age: _sanitizeAge(
            (legacyData?['age'] as num?)?.toInt() ??
            (lastGooglePeopleData?['age'] as num?)?.toInt(),
          ),
          ageGroup: legacyData?['ageGroup'] as String?,
          birthdate:
              legacyData?['birthdate'] as String? ??
              lastGooglePeopleData?['birthdate'] as String?,
          location:
              legacyData?['location'] as String? ??
              lastGooglePeopleData?['location'] as String?,
          city:
              legacyData?['city'] as String? ?? lastGooglePeopleData?['city'] as String?,
          state:
              legacyData?['state'] as String? ?? lastGooglePeopleData?['state'] as String?,
          country:
              legacyData?['country'] as String? ??
              lastGooglePeopleData?['country'] as String?,
          hasCompletedOnboarding: hasCompletedOnboarding,
        );

        await userDoc.set(newUser.toFirestoreCreate());
        debugPrint(
          'AuthFirestoreSync: NEW user record created successfully (legacy data consolidated if present)',
        );
        if (!hasCompletedOnboarding && onPromptOnboarding != null) {
          onPromptOnboarding();
        }
      } else {
        debugPrint(
          'AuthFirestoreSync: Document exists. Updating lifecycle timestamps...',
        );
        final docData = docSnapshot.data() ?? {};
        final hasCompletedOnboarding =
            docData['hasCompletedOnboarding'] as bool? ??
            (docData['birthdate'] != null &&
                docData['birthdate'].toString().isNotEmpty);
        onNeedsOnboardingChanged(!hasCompletedOnboarding);

        final existingName =
            (docData['displayName'] as String?) ?? (docData['name'] as String?);
        final existingPhoto =
            (docData['photoURL'] as String?) ??
            (docData['photoUrl'] as String?) ??
            (docData['avatarUrl'] as String?);
        final resolvedName =
            (existingName != null && existingName.isNotEmpty)
                ? existingName
                : (user.displayName ?? '');
        final resolvedPhoto =
            (existingPhoto != null && existingPhoto.isNotEmpty)
                ? existingPhoto
                : (user.photoURL ?? '');

        if (existingName != null &&
            existingName.isNotEmpty &&
            user.displayName != existingName) {
          try {
            await user.updateDisplayName(existingName);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'AuthFirestoreSync.updateDisplayName',
            );
          }
        }
        if (existingPhoto != null &&
            existingPhoto.isNotEmpty &&
            user.photoURL != existingPhoto) {
          try {
            await user.updatePhotoURL(existingPhoto);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'AuthFirestoreSync.updatePhotoURL',
            );
          }
        }

        final currentUser = UserModel.fromFirebaseUser(user).copyWith(
          displayName: resolvedName,
          photoURL: resolvedPhoto,
          metadata: metadata,
          age: _sanitizeAge((lastGooglePeopleData?['age'] as num?)?.toInt()),
          birthdate: lastGooglePeopleData?['birthdate'] as String?,
          location: lastGooglePeopleData?['location'] as String?,
          city: lastGooglePeopleData?['city'] as String?,
          state: lastGooglePeopleData?['state'] as String?,
          country: lastGooglePeopleData?['country'] as String?,
          hasCompletedOnboarding: hasCompletedOnboarding,
        );

        final updateData = currentUser.toFirestoreUpdate();
        updateData['metadata'] = metadata;
        if (existingName != null && existingName.isNotEmpty) {
          updateData['displayName'] = existingName;
          updateData['name'] = existingName;
        }
        if (existingPhoto != null && existingPhoto.isNotEmpty) {
          updateData['photoURL'] = existingPhoto;
        }

        if (docData['status'] == 'deactivated') {
          updateData['status'] = 'active';
          updateData['reactivatedAt'] = FieldValue.serverTimestamp();
        }

        await userDoc.set(updateData, SetOptions(merge: true));
        debugPrint(
          'AuthFirestoreSync: EXISTING user record updated successfully (preserved custom profile)',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AuthFirestoreSync.syncUser');
      logger.error('Sync failure for ${user.uid}: $e', tag: 'AUTH');

      // Critical Fallback: Use idempotent set() with merge if get() or update() failed
      try {
        debugPrint(
          'AuthFirestoreSync: Attempting idempotent fallback (set with merge)...',
        );
        final fallbackUser = UserModel.fromFirebaseUser(user).copyWith(
          age: _sanitizeAge((lastGooglePeopleData?['age'] as num?)?.toInt()),
          birthdate: lastGooglePeopleData?['birthdate'] as String?,
          location: lastGooglePeopleData?['location'] as String?,
          city: lastGooglePeopleData?['city'] as String?,
          state: lastGooglePeopleData?['state'] as String?,
          country: lastGooglePeopleData?['country'] as String?,
        );
        await userDoc.set(
          fallbackUser.toFirestoreCreate(),
          SetOptions(merge: true),
        );
        debugPrint(
          'AuthFirestoreSync: Idempotent fallback successful',
        );
      } catch (fallbackError, fallbackStack) {
        ErrorHandler.log(
          fallbackError,
          stackTrace: fallbackStack,
          tag: 'AuthFirestoreSync.syncUser.fallback',
        );
      }
    } finally {
      _isSyncingUser = false;
    }
  }

  /// Cleans up Firestore user document, all nested subcollections, and associated channel upon account deletion.
  Future<void> deleteAccountData(String uidToDelete) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDocRef = firestore
          .collection(FirestoreCollections.users)
          .doc(uidToDelete);
      final userSnap = await userDocRef.get();

      // 1. Delete associated channel if exists
      if (userSnap.exists) {
        final channelId = userSnap.data()?['channelId'] as String?;
        if (channelId != null && channelId.isNotEmpty) {
          await firestore
              .collection(FirestoreCollections.channels)
              .doc(channelId)
              .delete()
              .catchError((e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s is StackTrace ? s : null,
                  tag: 'AuthFirestoreSync.deleteAccount.channel',
                );
              });
        }
      }

      // 2. Thoroughly purge all known subcollections under users/{uidToDelete}
      await _purgeUserSubcollections(userDocRef);

      // 3. Purge user cache collection if present
      await _deleteCollectionInBatches(
        firestore.collection('userCache').doc(uidToDelete).collection('data'),
      );
      await firestore
          .collection('userCache')
          .doc(uidToDelete)
          .delete()
          .catchError((e, s) {
            // Non-fatal cache cleanup
          });

      // 4. Mark status as deleted and permanently delete the parent user document
      if (userSnap.exists) {
        await userDocRef.set({
          'status': 'deleted',
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((e, s) {});
      }

      await userDocRef.delete().catchError((e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s is StackTrace ? s : null,
          tag: 'AuthFirestoreSync.deleteAccount.userDoc',
        );
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthFirestoreSync.deleteAccount.firestore',
      );
    }
  }

  /// Recursively purges all documents across all user subcollections.
  Future<void> _purgeUserSubcollections(DocumentReference userDocRef) async {
    // 1. Handle playlists with nested 'items' subcollection
    try {
      final playlistsCol = userDocRef.collection('playlists');
      var playlistSnapshots = await playlistsCol.limit(100).get();
      while (playlistSnapshots.docs.isNotEmpty) {
        for (final pDoc in playlistSnapshots.docs) {
          await _deleteCollectionInBatches(pDoc.reference.collection('items'));
          await pDoc.reference.delete().catchError((Object? _) {});
        }
        playlistSnapshots = await playlistsCol.limit(100).get();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthFirestoreSync.purge.playlists',
      );
    }

    // 2. Standard user subcollections
    const subcollectionNames = [
      'watch_history',
      'liked_videos',
      'likedVideos',
      'disliked_videos',
      'dislikedVideos',
      'watch_later',
      'saved_playlists',
      'clips',
      'liked_clips',
      'feed_inbox',
      'savedTopics',
      'likedTopics',
      'liked_topic_comments',
      'liked_topic_replies',
      'comment_interactions',
      'reply_interactions',
      'savedCommunityPosts',
      'savedComments',
      'hiddenCommunityPosts',
      'mutedCommunityChannels',
      'reportedCommunityPosts',
      'subscriptions',
      'channelMemberships',
      'channel_memberships',
      'notifications_active',
      'notifications_archive',
      'saved_ads',
    ];

    for (final colName in subcollectionNames) {
      try {
        await _deleteCollectionInBatches(userDocRef.collection(colName));
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'AuthFirestoreSync.purge.$colName',
        );
      }
    }
  }

  /// Deletes all documents in a collection reference in chunks of up to 500 documents.
  Future<void> _deleteCollectionInBatches(
    CollectionReference collectionRef, {
    int batchSize = 500,
  }) async {
    try {
      var snapshot = await collectionRef.limit(batchSize).get();
      while (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        snapshot = await collectionRef.limit(batchSize).get();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AuthFirestoreSync.deleteCollectionInBatches',
      );
    }
  }
  /// Rejects any age outside the valid human range [1, 120].
  /// Returns null for out-of-range or null input so corrupt legacy / external
  /// data is silently discarded rather than persisted to Firestore.
  static int? _sanitizeAge(int? raw) {
    if (raw == null) return null;
    if (raw < 1 || raw > 120) return null;
    return raw;
  }
}
