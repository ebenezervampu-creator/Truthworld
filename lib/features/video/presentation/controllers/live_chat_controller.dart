import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/user_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/live_chat_message.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/live_chat_service.dart';
import 'package:truthworld/features/wallet/data/models/user_wallet_transaction.dart';

/// GetX Controller for Live Chat interactions, streaming, auto-scrolling, and Superchats.
class LiveChatController extends BaseController {
  LiveChatController({required this.videoId, this.video});

  final String videoId;
  final Video? video;

  final LiveChatService _service = Get.put(LiveChatService());

  final RxList<LiveChatMessage> messages = <LiveChatMessage>[].obs;
  final Rx<LiveChatMessage?> pinnedMessage = Rx<LiveChatMessage?>(null);
  final RxBool isSending = false.obs;
  final RxBool isAutoScrollEnabled = true.obs;
  final RxInt unreadCount = 0.obs;
  final RxInt cooldownSeconds = 0.obs;

  late final TextEditingController textController =
      trackTextController(TextEditingController());
  late final ScrollController scrollController =
      trackScrollController(ScrollController());

  StreamSubscription? _messageSubscription;
  StreamSubscription? _pinnedSubscription;
  Timer? _cooldownTicker;

  String get currentUserId => AuthService.to.uid;
  String get currentUserName =>
      AuthService.to.user?.displayName ?? 'Anonymous';
  String get currentUserPhoto => AuthService.to.user?.photoURL ?? '';
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

    setViewState(ViewState.loading);

    // Stream live messages (bounded to 100)
    _messageSubscription = trackSubscription(
      _service.streamMessages(videoId).listen(
        (newMessages) {
          final previousCount = messages.length;
          messages.assignAll(newMessages);
          setViewState(ViewState.success);

          if (isAutoScrollEnabled.value) {
            _scrollToBottom();
          } else if (newMessages.length > previousCount) {
            unreadCount.value += newMessages.length - previousCount;
          }
        },
        onError: (e, stackTrace) {
          setViewState(ViewState.error);
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'LiveChatController.streamMessages',
          );
        },
      ),
    );

    // Stream pinned superchat
    _pinnedSubscription = trackSubscription(
      _service.streamPinnedMessage(videoId).listen(
        (pinned) {
          pinnedMessage.value = pinned;
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'LiveChatController.streamPinnedMessage',
        ),
      ),
    );
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

    final validation = ContentValidator.validate(text, fieldName: 'Chat message');
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty) {
      AppSnackbar.info(
        'Please sign in to participate in live chat.',
        title: 'Sign In Required',
        actionLabel: 'SIGN IN',
        onAction: AuthService.to.signInWithGoogle,
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
      final cleanText = ContentValidator.cleanProfanity(text);

      await _service.sendMessage(
        videoId: videoId,
        text: cleanText,
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
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to send message. Please try again.',
      );
    } finally {
      isSending.value = false;
    }
  }

  void _startCooldownTicker() {
    cooldownSeconds.value = 2; // 2s slow mode
    _cooldownTicker?.cancel();
    _cooldownTicker = trackTimer(
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (cooldownSeconds.value > 1) {
          cooldownSeconds.value--;
        } else {
          cooldownSeconds.value = 0;
          timer.cancel();
        }
      }),
    );
  }

  /// Send Superchat fan support
  Future<bool> sendSuperchat({
    required double amount,
    required String text,
    String currency = 'USD',
  }) async {
    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty || video == null) {
      AppSnackbar.info(
        'Please sign in to send a Superchat.',
        title: 'Sign In Required',
        actionLabel: 'SIGN IN',
        onAction: AuthService.to.signInWithGoogle,
      );
      return false;
    }

    if (text.isNotEmpty) {
      final validation = ContentValidator.validate(text, fieldName: 'Superchat message');
      if (!validation.isValid) {
        AppSnackbar.warning(validation.message);
        return false;
      }
    }

    try {
      final cleanText = ContentValidator.cleanProfanity(text);
      final success = await _service.sendSuperchat(
        videoId: videoId,
        channelId: video!.channelId,
        text: cleanText,
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
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete Super Chat. Please try again.',
      );
      return false;
    }
  }

  /// Send Superchat fan support directly via Cashfree PG
  Future<bool> sendSuperchatWithCashfree({
    required double amountINR,
    required String text,
    double? originalAmount,
    String? originalCurrency,
  }) async {
    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty || video == null) {
      AppSnackbar.info(
        'Please sign in to send a Superchat.',
        title: 'Sign In Required',
        actionLabel: 'SIGN IN',
        onAction: AuthService.to.signInWithGoogle,
      );
      return false;
    }

    if (text.isNotEmpty) {
      final validation = ContentValidator.validate(text, fieldName: 'Superchat message');
      if (!validation.isValid) {
        AppSnackbar.warning(validation.message);
        return false;
      }
    }

    if (amountINR.isNaN || amountINR.isInfinite || amountINR < 1.0) {
      AppSnackbar.warning('Minimum Super Chat amount is ₹1.00.');
      return false;
    }

    try {
      final cleanText = ContentValidator.cleanProfanity(text);
      final isUsd = originalCurrency == 'USD' && originalAmount != null;
      final orderNote = isUsd
          ? 'Superchat on ${video!.title} (\$${originalAmount.toStringAsFixed(2)} USD)'
          : 'Superchat on ${video!.title}';
      final sanitizedAmountINR = double.parse(amountINR.toStringAsFixed(2));
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: sanitizedAmountINR,
        purpose: 'superchat',
        orderNote: orderNote,
        metadata: {
          'channelId': video!.channelId,
          'videoId': videoId,
          'text': cleanText,
          'userName': currentUserName,
          'userProfilePicUrl': currentUserPhoto,
          if (isUsd) 'originalAmount': originalAmount,
          'originalCurrency': originalCurrency ?? 'INR',
        },
      );

      if (paymentResult.success) {
        AppSnackbar.success(
          'Thank you for supporting the creator! 🎉',
          title: 'Superchat Sent!',
        );
        resumeAutoScroll();
        return true;
      } else if (paymentResult.errorMessage != null &&
          !paymentResult.errorMessage!.toLowerCase().contains('cancel')) {
        AppSnackbar.error(paymentResult.errorMessage!);
      }
      return false;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'LiveChatController.sendSuperchatWithCashfree');
      AppSnackbar.error('Unable to complete Super Chat payment. Please try again.');
      return false;
    }
  }

  /// Send Superchat fan support directly from User Wallet (1-click, no PG redirect)
  Future<bool> sendSuperchatWithWallet({
    required double amountINR,
    required String text,
    double? originalAmount,
    String? originalCurrency,
  }) async {
    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty || video == null) {
      AppSnackbar.info(
        'Please sign in to send a Superchat.',
        title: 'Sign In Required',
        actionLabel: 'SIGN IN',
        onAction: AuthService.to.signInWithGoogle,
      );
      return false;
    }

    if (text.isNotEmpty) {
      final validation = ContentValidator.validate(text, fieldName: 'Superchat message');
      if (!validation.isValid) {
        AppSnackbar.warning(validation.message);
        return false;
      }
    }

    if (amountINR.isNaN || amountINR.isInfinite || amountINR < 1.0) {
      AppSnackbar.warning('Minimum Super Chat amount is ₹1.00.');
      return false;
    }

    final sanitizedAmountINR = double.parse(amountINR.toStringAsFixed(2));

    // 1. Spend authoritatively from User Wallet
    final walletService = UserWalletService.to;
    if (!walletService.canAfford(sanitizedAmountINR)) {
      AppSnackbar.warning(
        'Insufficient wallet balance. Please add money or pay via Cashfree.',
        title: 'Low Wallet Balance',
      );
      return false;
    }

    final cleanText = ContentValidator.cleanProfanity(text);
    final isUsd = originalCurrency == 'USD' && originalAmount != null;

    final tx = await walletService.spendWallet(
      amountINR: sanitizedAmountINR,
      category: UserWalletTransactionCategory.superchat,
      description: 'Superchat on ${video!.title} (₹${sanitizedAmountINR.toStringAsFixed(2)})',
      metadata: {
        'channelId': video!.channelId,
        'videoId': videoId,
        'text': cleanText,
        if (isUsd) 'originalAmount': originalAmount,
        'originalCurrency': ?originalCurrency,
      },
    );

    if (tx == null) return false;

    // 2. Dispatch Superchat into channel & live chat stream
    try {
      final success = await _service.sendSuperchat(
        videoId: videoId,
        channelId: video!.channelId,
        text: cleanText,
        amount: isUsd ? originalAmount : sanitizedAmountINR,
        currency: isUsd ? 'USD' : 'INR',
      );

      AppSnackbar.success(
        'Thank you for supporting the creator with your wallet! 🎉',
        title: 'Superchat Sent!',
      );
      resumeAutoScroll();
      return success;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'LiveChatController.sendSuperchatWithWallet');
      return true; // Wallet was debited and transaction logged
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
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to complete moderation action. Please try again.',
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
