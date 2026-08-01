import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';

class WatchHistoryService extends GetxService {
  static WatchHistoryService get to => Get.find<WatchHistoryService>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxMap<String, double> _watchProgress =
      <String, double>{}.obs; // videoId -> percentage (0-100)
  final RxMap<String, int> _lastPositions =
      <String, int>{}.obs; // videoId -> seconds

  StreamSubscription? _historySubscription;

  @override
  void onInit() {
    super.onInit();
    // Listen to auth changes to fetch history for the new user
    ever(AuthService.to.currentUser, _handleAuthChanged);
    _handleAuthChanged(AuthService.to.user);
  }

  void _handleAuthChanged(dynamic user) {
    _historySubscription?.cancel();
    _watchProgress.clear();
    _lastPositions.clear();

    if (user != null) {
      final userId = AuthService.to.uid;
      _historySubscription = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .snapshots()
          .listen(
            (snapshot) {
              final newProgress = <String, double>{};
              final newPositions = <String, int>{};

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final videoId = doc.id;
                final percentage =
                    (data['watchPercentage'] as num?)?.toDouble() ?? 0.0;
                final lastPos = (data['lastPosition'] as num?)?.toInt() ?? 0;

                newProgress[videoId] = percentage;
                newPositions[videoId] = lastPos;
              }

              _watchProgress.assignAll(newProgress);
              _lastPositions.assignAll(newPositions);
            },
            onError: (e) {
              logger.error(
                'Error listening to watch history: $e',
                tag: 'WATCH_HISTORY',
              );
            },
          );
    }
  }

  /// Get watch progress percentage for a video (0.0 to 100.0)
  double getProgress(String videoId) {
    return _watchProgress[videoId] ?? 0.0;
  }

  /// Get last watched position in seconds for a video
  int getLastPosition(String videoId) {
    return _lastPositions[videoId] ?? 0;
  }

  /// Check if a video has any watch progress
  bool hasProgress(String videoId) {
    return _watchProgress.containsKey(videoId) && _watchProgress[videoId]! > 0;
  }

  @override
  void onClose() {
    _historySubscription?.cancel();
    super.onClose();
  }
}
