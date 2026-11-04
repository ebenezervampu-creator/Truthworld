import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/home/presentation/controllers/app_navigation_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/app_state_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/user_session_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class MainController extends BaseController {
  static MainController get to => Get.find<MainController>();

  late final AppStateController _stateCtrl;
  late final UserSessionController _sessionCtrl;
  late final AppNavigationController _navCtrl;

  @override
  void onInit() {
    super.onInit();
    _stateCtrl = Get.isRegistered<AppStateController>()
        ? Get.find<AppStateController>()
        : Get.put(AppStateController(), permanent: true);
    _sessionCtrl = Get.isRegistered<UserSessionController>()
        ? Get.find<UserSessionController>()
        : Get.put(UserSessionController(), permanent: true);
    _navCtrl = Get.isRegistered<AppNavigationController>()
        ? Get.find<AppNavigationController>()
        : Get.put(AppNavigationController(), permanent: true);
  }

  // FIREBASE SERVICES (from stateCtrl)
  FirebaseFirestore get firestore => _stateCtrl.firestore;
  FirebaseAuth get auth => _stateCtrl.auth;
  FlutterVideoInfo get videoInfo => _stateCtrl.videoInfo;

  // FILE PICKING STATE (from stateCtrl)
  Rx<PlatformFile?> get pickedImage => _stateCtrl.pickedImage;
  Rx<PlatformFile?> get pickedVideo => _stateCtrl.pickedVideo;

  // VIDEO STATE (from stateCtrl)
  RxList<Video> get videos => _stateCtrl.videos;
  RxList<Video> get filteredVideos => _stateCtrl.filteredVideos;
  RxString get searchQuery => _stateCtrl.searchQuery;

  // INTERACTION STATE (from sessionCtrl)
  RxMap<String, int> get videoLikes => _sessionCtrl.videoLikes;
  RxMap<String, int> get videoDislikes => _sessionCtrl.videoDislikes;
  RxMap<String, int> get videoViews => _sessionCtrl.videoViews;
  RxBool get isReporting => _sessionCtrl.isReporting;

  // VIDEO STREAM MANAGEMENT (from stateCtrl)
  Stream<List<Video>> streamVideos() => _stateCtrl.streamVideos();
  Future<void> restartVideoStream() => _stateCtrl.restartVideoStream();

  // FILE PICKING (from stateCtrl)
  Future<void> pickImage() => _stateCtrl.pickImage();
  Future<void> pickVideo() => _stateCtrl.pickVideo();

  // VIDEO INTERACTIONS (from sessionCtrl)
  Future<void> likeVideo(String videoId, String userId) => _sessionCtrl.likeVideo(videoId, userId);
  Future<void> dislikeVideo(String videoId, String userId) => _sessionCtrl.dislikeVideo(videoId, userId);
  Future<void> likeComment({required String videoId, required String commentId, required String userId}) => _sessionCtrl.likeComment(videoId: videoId, commentId: commentId, userId: userId);
  Future<void> dislikeComment({required String videoId, required String commentId, required String userId}) => _sessionCtrl.dislikeComment(videoId: videoId, commentId: commentId, userId: userId);
  Future<void> heartComment({required String videoId, required String commentId, required bool isHearted}) => _sessionCtrl.heartComment(videoId: videoId, commentId: commentId, isHearted: isHearted);
  Future<void> likeReply({required String videoId, required String commentId, required String replyId, required String userId}) => _sessionCtrl.likeReply(videoId: videoId, commentId: commentId, replyId: replyId, userId: userId);
  Future<void> dislikeReply({required String videoId, required String commentId, required String replyId, required String userId}) => _sessionCtrl.dislikeReply(videoId: videoId, commentId: commentId, replyId: replyId, userId: userId);

  // SHARING (from navCtrl - wait, share methods were in interaction? Let's check)
  // No, share is in sessionCtrl according to my script! Wait, share methods were part of VIDEO INTERACTIONS!
  Future<void> shareVideo(String v, String t, {String? thumbnailUrl, String? channelName, int? durationMs, Duration? currentPosition, String? subtitle}) => _sessionCtrl.shareVideo(v, t, thumbnailUrl: thumbnailUrl, channelName: channelName, durationMs: durationMs, currentPosition: currentPosition, subtitle: subtitle);
  Future<void> shareChannel(String c, String n, {String? avatarUrl, String? bannerUrl, String? handle, int? subscriberCount, int? videoCount, String? subtitle}) => _sessionCtrl.shareChannel(c, n, avatarUrl: avatarUrl, bannerUrl: bannerUrl, handle: handle, subscriberCount: subscriberCount, videoCount: videoCount, subtitle: subtitle);
  Future<void> sharePlaylist(String p, String n, {String? thumbnailUrl, String? channelName, int? videoCount, String? subtitle}) => _sessionCtrl.sharePlaylist(p, n, thumbnailUrl: thumbnailUrl, channelName: channelName, videoCount: videoCount, subtitle: subtitle);
  Future<void> shareTopic(String s, String t, {String? thumbnailUrl, int? videoCount, int? followerCount, String? subtitle}) => _sessionCtrl.shareTopic(s, t, thumbnailUrl: thumbnailUrl, videoCount: videoCount, followerCount: followerCount, subtitle: subtitle);

  // COMMENTS & REPLIES (from sessionCtrl)
  Future<void> addComment({required String videoId, required String userId, required String userName, required String userProfilePicUrl, required String text}) => _sessionCtrl.addComment(videoId: videoId, userId: userId, userName: userName, userProfilePicUrl: userProfilePicUrl, text: text);
  Future<void> addReply({required String videoId, required String commentId, required String userId, required String userName, required String userProfilePicUrl, required String text}) => _sessionCtrl.addReply(videoId: videoId, commentId: commentId, userId: userId, userName: userName, userProfilePicUrl: userProfilePicUrl, text: text);
  Future<void> deleteComment(String videoId, String commentId) => _sessionCtrl.deleteComment(videoId, commentId);
  Future<void> deleteReply({required String videoId, required String commentId, required String replyId}) => _sessionCtrl.deleteReply(videoId: videoId, commentId: commentId, replyId: replyId);
  Stream<List<Comment>> getCommentsStream(String videoId) => _sessionCtrl.getCommentsStream(videoId);
  Stream<List<Reply>> getRepliesStream(String videoId, String commentId) => _sessionCtrl.getRepliesStream(videoId, commentId);

  // METADATA UPDATES (from navCtrl)
  Future<void> addShare(String videoId, String share) => _navCtrl.addShare(videoId, share);
  Future<void> incrementViews({
    required String videoId,
    required String userId,
    required bool isQualified,
    String? channelId,
  }) => _navCtrl.incrementViews(
        videoId: videoId,
        channelId: channelId,
        userId: userId,
        isQualified: isQualified,
      );
  Future<bool> trackWatchEvent({
    required String videoId,
    required String eventType,
    required int position,
    required int duration,
    String? channelId,
    int? watchTimeSecondsDelta,
    bool isSubscriber = false,
    bool isNotSubscriber = false,
    String trafficSource = 'direct',
    String? viewerHash,
    String? dedupKey,
    String? sessionId,
  }) => _navCtrl.trackWatchEvent(
        videoId: videoId,
        channelId: channelId,
        eventType: eventType,
        position: position,
        duration: duration,
        watchTimeSecondsDelta: watchTimeSecondsDelta,
        isSubscriber: isSubscriber,
        isNotSubscriber: isNotSubscriber,
        trafficSource: trafficSource,
        viewerHash: viewerHash,
        dedupKey: dedupKey,
        sessionId: sessionId,
      );
  Future<void> recordWatchSession(Map<String, dynamic> sessionData) => _navCtrl.recordWatchSession(sessionData);
  Future<void> incrementShareCount(String videoId) => _navCtrl.incrementShareCount(videoId);

  // SEARCH & FILTERING (from stateCtrl)
  void filterVideos(String query) => _stateCtrl.filterVideos(query);

  // OFFLINE & DOWNLOAD (from stateCtrl)
  Future<void> downloadVideoToDevice(dynamic bytes, String fileName) => _stateCtrl.downloadVideoToDevice(bytes, fileName);
  Future<void> saveOfflineVideo(OfflineVideo video, String videoUrl) => _stateCtrl.saveOfflineVideo(video, videoUrl);

  // REPORTING (from sessionCtrl)
  Future<void> reportVideo({required BuildContext context, required String videoId, required String channelId, required String reason, required String comment}) => _sessionCtrl.reportVideo(context: context, videoId: videoId, channelId: channelId, reason: reason, comment: comment);
  Future<void> addToWatchLater(String videoId) => _sessionCtrl.addToWatchLater(videoId);

  // GETTERS (from sessionCtrl)
  bool get isAuthenticated => _sessionCtrl.isAuthenticated;
  String? get currentUserId => _sessionCtrl.currentUserId;
  int get filteredVideoCount => _stateCtrl.filteredVideoCount;
  int get totalVideoCount => _stateCtrl.totalVideoCount;
  bool get isImagePicked => _stateCtrl.isImagePicked;
  bool get isVideoPicked => _stateCtrl.isVideoPicked;
}
