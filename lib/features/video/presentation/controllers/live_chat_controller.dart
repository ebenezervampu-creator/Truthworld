import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/live_chat_message.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/live_chat_service.dart';
import 'package:truthworld/theme/app_colors.dart';

/// GetX Controller for Live Chat interactions, streaming, auto-scrolling, and Superchats.
class LiveChatController extends GetxController {
  LiveChatController({required this.videoId, this.video});

  final String videoId;
  final Video? video;

  final LiveChatService _service = Get.put(LiveChatService());

  final RxList<LiveChatMessage> messages = <LiveChatMessage>[].obs;
  final Rx<LiveChatMessage?> pinnedMessage = Rx<LiveChatMessage?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isSending = false.obs;
  final RxBool isAutoScrollEnabled = true.obs;
  final RxInt unreadCount = 0.obs;
  final RxInt cooldownSeconds = 0.obs;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _pinnedSubscription;
  Timer? _cooldownTicker;

  String get currentUserId => AuthService.to.uid;
  bool get isCreator =>
      currentUserId.isNotEmpty && (video?.ownerId == currentUserId);

  @override
  void onInit() {
    super.onInit();
    _initStreams();
    _initScrollListener();
  }

  void _initStreams() {
    if (videoId.isEmpty) return;

    isLoading.value = true;

    // Stream live messages (bounded to 100)
    _messageSubscription = _service.streamMessages(videoId).listen(
      (newMessages) {
        final previousCount = messages.length;
        messages.assignAll(newMessages);
        isLoading.value = false;

        if (isAutoScrollEnabled.value) {
          _scrollToBottom();
        } else if (newMessages.length > previousCount) {
          unreadCount.value += newMessages.length - previousCount;
        }
      },
      onError: (e) {
        isLoading.value = false;
        debugPrint('[LiveChatController] Error listening to messages: $e');
      },
    );

    // Stream pinned superchat
    _pinnedSubscription = _service.streamPinnedMessage(videoId).listen((pinned) {
      pinnedMessage.value = pinned;
    });
  }

  void _initScrollListener() {
    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;

      // If user is within 60px of the bottom, keep auto-scroll on
      if (maxScroll - currentScroll <= 60) {
        if (!isAutoScrollEnabled.value) {
          isAutoScrollEnabled.value = true;
          unreadCount.value = 0;
        }
      } else {
        if (isAutoScrollEnabled.value) {
          isAutoScrollEnabled.value = false;
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void resumeAutoScroll() {
    isAutoScrollEnabled.value = true;
    unreadCount.value = 0;
    _scrollToBottom();
  }

  /// Send a regular live chat message
  Future<void> sendChatMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || isSending.value) return;

    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty) {
      Get.snackbar(
        'Sign In Required',
        'Please sign in to participate in live chat.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        mainButton: TextButton(
          onPressed: AuthService.to.signInWithGoogle,
          child: const Text(
            'SIGN IN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      return;
    }

    if (cooldownSeconds.value > 0) {
      AppSnackbar.warning(
        'Please wait ${cooldownSeconds.value}s before sending another message.',
        title: 'Slow Mode',
      );
      return;
    }

    isSending.value = true;

    try {
      final auth = AuthService.to;
      final userName = auth.activeDisplayName;
      final userPhoto = auth.activePhotoUrl;

      await _service.sendMessage(
        videoId: videoId,
        text: text,
        userName: userName,
        userProfilePicUrl: userPhoto,
        channelId: auth.userChannel?.id,
        channelName: auth.userChannel?.name,
        isCreator: isCreator,
      );

      textController.clear();
      resumeAutoScroll();
      _startCooldownTicker();
    } catch (e) {
      AppSnackbar.error(
        e.toString().replaceAll('Exception:', '').trim(),
        title: 'Message Not Sent',
      );
    } finally {
      isSending.value = false;
    }
  }

  void _startCooldownTicker() {
    cooldownSeconds.value = 2; // 2s slow mode
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (cooldownSeconds.value > 1) {
        cooldownSeconds.value--;
      } else {
        cooldownSeconds.value = 0;
        timer.cancel();
      }
    });
  }

  /// Send Superchat fan support
  Future<bool> sendSuperchat({
    required double amount,
    required String text,
    String currency = 'USD',
  }) async {
    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty || video == null) {
      Get.snackbar(
        'Sign In Required',
        'Please sign in to send a Superchat.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        mainButton: TextButton(
          onPressed: AuthService.to.signInWithGoogle,
          child: const Text(
            'SIGN IN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      return false;
    }

    try {
      final success = await _service.sendSuperchat(
        videoId: videoId,
        channelId: video!.channelId,
        text: text,
        amount: amount,
        currency: currency,
      );

      if (success) {
        AppSnackbar.success(
          'Thank you for supporting the creator! 🎉',
          title: 'Superchat Sent!',
        );
        resumeAutoScroll();
      }
      return success;
    } catch (e) {
      AppSnackbar.error(
        e.toString().replaceAll('Exception:', '').trim(),
        title: 'Superchat Failed',
      );
      return false;
    }
  }

  /// Creator moderation actions (timeout, ban, delete)
  Future<void> moderateUser({
    required String targetUserId,
    required String action,
    int durationSeconds = 300,
    String? deleteMessageId,
  }) async {
    try {
      await _service.sendModerationAction(
        videoId: videoId,
        targetUserId: targetUserId,
        action: action,
        durationSeconds: durationSeconds,
        deleteMessageId: deleteMessageId,
      );
      AppSnackbar.success(
        'Moderation action "$action" applied.',
        title: 'Action Completed',
      );
    } catch (e) {
      AppSnackbar.error(
        e.toString().replaceAll('Exception:', '').trim(),
        title: 'Moderation Error',
      );
    }
  }

  @override
  void onClose() {
    _messageSubscription?.cancel();
    _pinnedSubscription?.cancel();
    _cooldownTicker?.cancel();
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
