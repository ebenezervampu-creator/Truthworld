import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';

class UserClipsController extends BaseController {
  final RxList<VideoClip> clips = <VideoClip>[].obs;
  final RxBool rxIsLoading = true.obs;
  final RxString rxErrorMessage = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearchExpanded = false.obs;
  final RxBool isListView = true.obs;
  final RxString selectedCategory = 'All'.obs;

  @override
  void onInit() {
    super.onInit();
    fetchClips();
  }

  Future<void> fetchClips() async {
    rxIsLoading.value = true;
    rxErrorMessage.value = '';
    if (!AuthService.to.isAuthenticated.value) {
      rxIsLoading.value = false;
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      rxIsLoading.value = false;
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('clips')
          .orderBy('createdAt', descending: true)
          .get();

      clips.assignAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return VideoClip.fromMap(data);
        }).toList(),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserClipsController.fetchClips');
      rxErrorMessage.value = AppException.from(e).displayMessage;
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<void> deleteClip(String clipId) async {
    if (!AuthService.to.isAuthenticated.value) return;
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('clips')
          .doc(clipId)
          .delete();
      clips.removeWhere((c) => c.id == clipId);
      AppSnackbar.success('Clip removed from library.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to delete clip. Please try again.');
    }
  }

  void toggleView() {
    isListView.value = !isListView.value;
    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void playClip(VideoClip clip) {
    final startMs = (clip.startTime * 1000).toInt();
    final resumePos = Duration(milliseconds: startMs);
    VideoPlaybackHandoff.registerResumePosition(clip.videoId, resumePos);

    final currentRouteName = Get.currentRoute.toLowerCase();
    final hasWatchInStack = RouteStackObserver.routeStack.isNotEmpty &&
        (RouteStackObserver.routeStack.last.settings.name?.toLowerCase().contains('/watch') ?? false);
    final isCurrentlyOnWatch = currentRouteName.contains('/watch') || hasWatchInStack;

    final targetUrl = '/watch?v=${clip.videoId}&start=${clip.startTime}&end=${clip.endTime}';
    final navArgs = <String, dynamic>{
      'clip': clip,
      'resumePosition': resumePos,
      'initialPosition': resumePos,
    };

    if (isCurrentlyOnWatch) {
      Get.offNamed<void>(targetUrl, arguments: navArgs);
    } else {
      Get.toNamed<void>(targetUrl, arguments: navArgs);
    }
  }

  List<VideoClip> get filteredClips {
    var result = clips.toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((c) {
        return c.title.toLowerCase().contains(q) ||
            c.videoTitle.toLowerCase().contains(q) ||
            c.channelName.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, List<VideoClip>> groupClipsByDate(List<VideoClip> clipsList) {
    final groups = <String, List<VideoClip>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final clip in clipsList) {
      final date = clip.createdAt;
      final dateOnly = DateTime(date.year, date.month, date.day);
      String key;
      if (dateOnly == today) {
        key = 'Today';
      } else if (dateOnly == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${date.day} ${_getMonthName(date.month)} ${date.year}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(clip);
    }
    return groups;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
