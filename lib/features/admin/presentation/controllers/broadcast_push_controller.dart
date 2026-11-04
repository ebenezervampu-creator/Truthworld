import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Preset template definition for engaging Zomato-style push notifications
class ZomatoPushPreset {
  final String id;
  final String category;
  final String emoji;
  final String title;
  final String body;
  final String suggestedActionUrl;
  final String hint;

  const ZomatoPushPreset({
    required this.id,
    required this.category,
    required this.emoji,
    required this.title,
    required this.body,
    required this.hint,
    this.suggestedActionUrl = '/feed',
  });
}

/// Controller for Super Admin Zomato-style push notification broadcasts.
/// Manages live preview state, curated preset templates, real-time input validation,
/// Cloud Function dispatch, and historical campaign records.
class BroadcastPushController extends BaseController {
  static BroadcastPushController get to => Get.find<BroadcastPushController>();

  // Input Controllers
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  final TextEditingController actionUrlController = TextEditingController();
  final TextEditingController targetUserController = TextEditingController();

  // Reactive Mirrors for Instant Phone Preview
  final RxString titleRx = ''.obs;
  final RxString bodyRx = ''.obs;
  final RxString imageUrlRx = ''.obs;
  final RxString actionUrlRx = '/feed'.obs;
  final RxString targetUserRx = ''.obs;

  // Targeting Options
  // 'broadcast' (All devices via topic) | 'direct_user' (1-to-1 direct message notification)
  final RxString targetMode = 'broadcast'.obs;
  // 'all' = Android + iOS | 'android' = Android only | 'ios' = iOS only
  final RxString selectedPlatform = 'all'.obs;
  // 'app' = Consumer App | 'studio' = Creator Studio | 'all' = All TruthWorld Apps
  final RxString selectedTargetApp = 'app'.obs;
  final RxString selectedPresetId = ''.obs;

  // Live Phone Mockup Platform Preview ('ios' vs 'android')
  final RxString previewDevice = 'ios'.obs;

  // Loading and State Flags
  final RxBool isSending = false.obs;
  final RxBool isLoadingHistory = false.obs;
  final RxList<Map<String, dynamic>> broadcastHistory = <Map<String, dynamic>>[].obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _historySubscription;

  // Curated Zomato-Style Push Presets
  final List<ZomatoPushPreset> presets = const [
    ZomatoPushPreset(
      id: 'lunch_truth_bite',
      category: 'Food For Thought',
      emoji: '🍕',
      title: 'Hungry for the truth? 🍕',
      body: "A piping-hot 2-minute snack of today's most verified stories is ready. Grab a slice!",
      hint: 'High conversion during lunch hours (12:30 PM - 2:00 PM)',
    ),
    ZomatoPushPreset(
      id: 'fomo_curiosity',
      category: 'Curiosity & FOMO',
      emoji: '👀',
      title: "You won't believe what was just fact-checked! 👀",
      body: 'Stop scrolling past misinformation. Here is what actually happened behind the viral buzz.',
      suggestedActionUrl: '/trending',
      hint: 'Drives massive click-through with natural curiosity gap',
    ),
    ZomatoPushPreset(
      id: 'breaking_factcheck',
      category: 'Breaking Verdict',
      emoji: '⚡',
      title: '⚡ BREAKING FACT CHECK',
      body: 'Major internet claim conclusively debunked with verified evidence. See the breakdown.',
      suggestedActionUrl: '/trending',
      hint: 'Maximum urgency when debunking major breaking stories',
    ),
    ZomatoPushPreset(
      id: 'family_forward_shield',
      category: 'Family Group Armor',
      emoji: '🚨',
      title: "🚨 Don't let your family group get fooled!",
      body: 'That viral message everyone is forwarding? We verified the real story. Arm yourself with facts.',
      hint: 'Highly relatable, prompts immediate social sharing',
    ),
    ZomatoPushPreset(
      id: 'midnight_curiosity',
      category: 'Midnight Thoughts',
      emoji: '🌙',
      title: "Can't sleep? Neither can our truth engines 🌙",
      body: 'Bite-sized verified stories to satisfy your late-night curiosity before you drift off.',
      hint: 'Perfect for late night wind-down (10:30 PM - 12:00 AM)',
    ),
    ZomatoPushPreset(
      id: 'morning_espresso',
      category: 'Morning Brew',
      emoji: '☕',
      title: 'Coffee in hand? ☕',
      body: "Here is your 60-second morning espresso shot of what's real and what's fake today.",
      hint: 'Optimal morning engagement (7:30 AM - 9:30 AM)',
    ),
    ZomatoPushPreset(
      id: 'weekend_popcorn',
      category: 'Weekend Binge',
      emoji: '🍿',
      title: 'Weekend vibe check 🍿',
      body: 'Grab the popcorn! The top 5 truth investigations of the week are wilder than fiction.',
      suggestedActionUrl: '/trending',
      hint: 'Best sent Friday evenings or Saturday afternoons',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    // Synchronize text changes to reactive observables for the live mockup
    titleController.addListener(() => titleRx.value = titleController.text);
    bodyController.addListener(() => bodyRx.value = bodyController.text);
    imageUrlController.addListener(() => imageUrlRx.value = imageUrlController.text.trim());
    actionUrlController.addListener(() => actionUrlRx.value = actionUrlController.text.trim());
    targetUserController.addListener(() => targetUserRx.value = targetUserController.text.trim());

    // Initialize with first preset
    applyPreset(presets.first);

    // Start listening to past broadcast campaigns
    _listenToBroadcastHistory();
  }

  /// Populates the composer with a selected Zomato-style preset
  void applyPreset(ZomatoPushPreset preset) {
    selectedPresetId.value = preset.id;
    titleController.text = preset.title;
    bodyController.text = preset.body;
    actionUrlController.text = preset.suggestedActionUrl;
    titleRx.value = preset.title;
    bodyRx.value = preset.body;
    actionUrlRx.value = preset.suggestedActionUrl;
  }

  /// Quickly duplicates a previously sent campaign into the composer
  void copyFromHistory(Map<String, dynamic> item) {
    titleController.text = (item['title'] as String? ?? '').trim();
    bodyController.text = (item['body'] as String? ?? '').trim();
    imageUrlController.text = (item['imageUrl'] as String? ?? '').trim();
    actionUrlController.text = (item['actionUrl'] as String? ?? '/feed').trim();
    selectedPlatform.value = (item['targetPlatform'] as String? ?? 'all').trim();
    selectedTargetApp.value = (item['targetApp'] as String? ?? 'app').trim();
    selectedPresetId.value = (item['presetTag'] as String? ?? '').trim();

    final mode = item['targetMode'] as String? ?? 'broadcast';
    targetMode.value = mode == 'direct_user' ? 'direct_user' : 'broadcast';
    targetUserController.text = (item['targetUserEmail'] as String? ??
            item['targetUid'] as String? ??
            item['targetDisplayName'] as String? ??
            '')
        .trim();
    targetUserRx.value = targetUserController.text;

    titleRx.value = titleController.text;
    bodyRx.value = bodyController.text;
    imageUrlRx.value = imageUrlController.text;
    actionUrlRx.value = actionUrlController.text;

    AppSnackbar.info('Campaign loaded into composer.');
  }

  /// Listens to historical broadcasts from Firestore
  void _listenToBroadcastHistory() {
    isLoadingHistory.value = true;
    try {
      _historySubscription?.cancel();
      _historySubscription = FirebaseFirestore.instance
          .collection('broadcast_notifications')
          .orderBy('sentAt', descending: true)
          .limit(25)
          .snapshots()
          .listen(
        (snapshot) {
          final items = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          broadcastHistory.assignAll(items);
          isLoadingHistory.value = false;
        },
        onError: (err, stack) {
          isLoadingHistory.value = false;
          ErrorHandler.log(err, stackTrace: stack, tag: 'BroadcastPushController._listenToBroadcastHistory');
        },
      );
    } catch (e, stack) {
      isLoadingHistory.value = false;
      ErrorHandler.log(e, stackTrace: stack, tag: 'BroadcastPushController._listenToBroadcastHistory');
    }
  }

  /// Dispatches the push broadcast to all target devices via Cloud Functions
  Future<bool> sendBroadcast({bool isDryRun = false}) async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();
    final imageUrl = imageUrlController.text.trim();
    final actionUrl = actionUrlController.text.trim();

    if (title.isEmpty) {
      AppSnackbar.warning('Please enter a notification title.');
      return false;
    }
    if (body.isEmpty) {
      AppSnackbar.warning('Please enter the notification message body.');
      return false;
    }

    if (imageUrl.isNotEmpty) {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        AppSnackbar.warning('Please provide a valid image URL starting with http:// or https://.');
        return false;
      }
    }

    if (targetMode.value == 'direct_user' && targetUserController.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter the target user UID, Email, or Username.');
      return false;
    }

    isSending.value = true;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendBroadcastPushNotification');

      final response = await callable.call<Map<String, dynamic>>({
        'title': title,
        'body': body,
        'imageUrl': imageUrl.isNotEmpty ? imageUrl : null,
        'actionUrl': actionUrl.isNotEmpty ? actionUrl : '/feed',
        'targetMode': targetMode.value,
        'targetUser': targetUserController.text.trim(),
        'targetPlatform': selectedPlatform.value,
        'targetApp': selectedTargetApp.value,
        'presetTag': selectedPresetId.value,
        'dryRun': isDryRun,
      });

      final resData = response.data;
      if (resData['success'] == true) {
        if (targetMode.value == 'direct_user') {
          final userLabel = resData['targetUserEmail'] as String? ??
              resData['targetDisplayName'] as String? ??
              resData['targetUid'] as String? ??
              'target user';

          AppSnackbar.success(
            isDryRun
                ? 'Dry run validation succeeded for $userLabel.'
                : 'Direct message notification successfully sent to $userLabel!',
          );
        } else {
          final platformName = selectedPlatform.value == 'all'
              ? 'All Devices (Android & iOS)'
              : (selectedPlatform.value == 'android' ? 'Android Devices' : 'iOS Devices');

          AppSnackbar.success(
            isDryRun
                ? 'Dry run validation succeeded for $platformName.'
                : 'Push notification successfully dispatched to $platformName!',
          );
        }
        return true;
      } else {
        AppSnackbar.error('Unable to send push broadcast. Please try again.');
        return false;
      }
    } catch (e, stack) {
      ErrorHandler.log(e, stackTrace: stack, tag: 'BroadcastPushController.sendBroadcast');
      AppSnackbar.error('Failed to send broadcast. Please verify your connection and permissions.');
      return false;
    } finally {
      isSending.value = false;
    }
  }

  /// Resets composer to blank draft
  void clearDraft() {
    titleController.clear();
    bodyController.clear();
    imageUrlController.clear();
    targetUserController.clear();
    actionUrlController.text = '/feed';
    titleRx.value = '';
    bodyRx.value = '';
    imageUrlRx.value = '';
    targetUserRx.value = '';
    actionUrlRx.value = '/feed';
    selectedPresetId.value = '';
  }

  @override
  void onClose() {
    _historySubscription?.cancel();
    titleController.dispose();
    bodyController.dispose();
    imageUrlController.dispose();
    actionUrlController.dispose();
    targetUserController.dispose();
    super.onClose();
  }
}
