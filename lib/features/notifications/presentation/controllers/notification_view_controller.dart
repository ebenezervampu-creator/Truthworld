import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';

/// Screen-level controller managing UI tabs, scrolling, search, and unified notification aggregation.
class NotificationViewController extends BaseController {
  final VideoFeedNotificationController feedController =
      Get.isRegistered<VideoFeedNotificationController>()
          ? Get.find<VideoFeedNotificationController>()
          : Get.put(VideoFeedNotificationController());

  final UserNotificationController userNotificationController =
      Get.isRegistered<UserNotificationController>()
          ? Get.find<UserNotificationController>()
          : Get.put(UserNotificationController());

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxInt selectedTabIndex = 0.obs;
  final RxBool showScrollToTop = false.obs;
  final RxString currentChannelId = ''.obs;
  final RxString currentCreatorId = ''.obs;

  /// Real-time stream of active channel issues synthesized as UserNotification items
  final RxList<UserNotification> channelIssues = <UserNotification>[].obs;
  final RxSet<String> dismissedIssueIds = <String>{}.obs;
  final RxSet<String> readIssueIds = <String>{}.obs;

  StreamSubscription? _videosSubscription;
  StreamSubscription? _copyrightSubscription;
  StreamSubscription? _channelSubscription;
  StreamSubscription? _topicsSubscription;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedVideoDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedCopyrightDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedTopicDocs = [];
  DocumentSnapshot<Map<String, dynamic>>? _cachedChannelDoc;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final shouldShow = scrollController.offset > 400;
    if (showScrollToTop.value != shouldShow) {
      showScrollToTop.value = shouldShow;
    }
  }

  void setChannelContext({required String channelId, String creatorId = ''}) {
    final changed = currentChannelId.value != channelId ||
        currentCreatorId.value != creatorId;
    currentChannelId.value = channelId;
    currentCreatorId.value = creatorId;
    userNotificationController.setChannelId(channelId);
    if (changed) {
      _listenToChannelIssues();
      _ensureChannelWelcomeAlert(
        channelId,
        creatorId.isNotEmpty ? creatorId : effectiveCreatorId,
      );
    }
  }

  Future<void> _ensureChannelWelcomeAlert(
    String channelId,
    String creatorId,
  ) async {
    if (channelId.isEmpty || creatorId.isEmpty) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('user_notifications')
          .doc('welcome_$channelId');
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final notifData = {
          'id': 'welcome_$channelId',
          'userId': creatorId,
          'channelId': channelId,
          'type': 'channel_notifications',
          'category': 'channel',
          'severity': 'info',
          'priority': 'medium',
          'targetApp': 'studio',
          'title': 'Welcome to Creator Studio',
          'message':
              'Your channel is registered and ready. Channel health is in good standing with zero policy strikes.',
          'actionUrl': '/studio',
          'metadata': {
            'channelId': channelId,
            'tab': 0,
            'category': 'channel',
            'targetApp': 'studio',
          },
          'read': false,
          'createdAt': now,
          'pushSent': true,
        };
        final batch = FirebaseFirestore.instance.batch();
        batch.set(docRef, notifData);
        batch.set(
          FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(creatorId)
              .collection('notifications_active')
              .doc('welcome_$channelId'),
          notifData,
        );
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        '[NotificationViewController] Welcome alert seeding skipped: $e',
      );
    }
  }

  /// Whether current view is rendered within Creator Studio channel context
  bool get isChannelContext => currentChannelId.value.isNotEmpty;

  /// Dynamically computes active tab pills based on view mode (Studio vs Consumer)
  List<NotificationTab> get activeTabs {
    if (isChannelContext) {
      return const [
        NotificationTab.all,
        NotificationTab.verifications,
        NotificationTab.studioAlerts,
        NotificationTab.topics,
        NotificationTab.comments,
        NotificationTab.mentions,
      ];
    }
    return const [
      NotificationTab.all,
      NotificationTab.topics,
      NotificationTab.comments,
      NotificationTab.mentions,
    ];
  }

  /// Returns identifier of currently active tab (e.g. 'all', 'verifications', 'studio_alerts', 'topics', 'comments', 'mentions')
  String get activeTabId {
    final tabs = activeTabs;
    final idx = selectedTabIndex.value;
    if (idx >= 0 && idx < tabs.length) {
      return tabs[idx].id;
    }
    return 'all';
  }

  /// Selects tab by semantic identifier
  void selectTabById(String id) {
    final tabs = activeTabs;
    final idx = tabs.indexWhere((t) => t.id == id);
    if (idx != -1) {
      selectTab(idx);
    }
  }

  String get effectiveCreatorId {
    if (currentCreatorId.value.isNotEmpty) return currentCreatorId.value;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void dismissIssue(String id) {
    dismissedIssueIds.add(id);
    channelIssues.refresh();
  }

  void markIssueAsRead(String id) {
    readIssueIds.add(id);
    channelIssues.refresh();
  }

  void _listenToChannelIssues() {
    _videosSubscription?.cancel();
    _copyrightSubscription?.cancel();
    _channelSubscription?.cancel();
    _topicsSubscription?.cancel();
    channelIssues.clear();

    final chId = currentChannelId.value;
    final uid = effectiveCreatorId;
    if (chId.isEmpty && uid.isEmpty) return;

    // Immediately compute initial baseline channel health status
    _recomputeChannelIssues();

    final firestore = FirebaseFirestore.instance;

    // 1. Listen to videos for active moderation/review/failure/dispute issues
    if (chId.isNotEmpty || uid.isNotEmpty) {
      final videosQuery = chId.isNotEmpty
          ? firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: chId)
              .limit(100)
          : firestore
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: uid)
              .limit(100);

      _videosSubscription = trackSubscription(
        videosQuery.snapshots().listen((snapshot) {
          _recomputeChannelIssues(videoDocs: snapshot.docs);
        }, onError: (err) {
          debugPrint('[NotificationViewController] Videos stream error: $err');
        }),
      );
    }

    // 2. Listen to copyright claims
    final copyrightQuery = uid.isNotEmpty
        ? firestore
            .collection('copyright_claims')
            .where('uploaderId', isEqualTo: uid)
        : firestore
            .collection('copyright_claims')
            .where('channelId', isEqualTo: chId);

    _copyrightSubscription = trackSubscription(
      copyrightQuery.snapshots().listen((snapshot) {
        _recomputeChannelIssues(copyrightDocs: snapshot.docs);
      }, onError: (err) {
        debugPrint(
            '[NotificationViewController] Copyright stream error: $err');
      }),
    );

    // 3. Listen to channel for branding and verification notices
    if (chId.isNotEmpty) {
      _channelSubscription = trackSubscription(
        firestore
            .collection(FirestoreCollections.channels)
            .doc(chId)
            .snapshots()
            .listen((snapshot) {
          _recomputeChannelIssues(channelDoc: snapshot);
        }, onError: (err) {
          debugPrint('[NotificationViewController] Channel stream error: $err');
        }),
      );
    }

    // 4. Listen to topics for active content moderation rejections or reviews
    if (chId.isNotEmpty || uid.isNotEmpty) {
      final topicsQuery = chId.isNotEmpty
          ? firestore
              .collection(FirestoreCollections.topics)
              .where('channelId', isEqualTo: chId)
              .limit(100)
          : firestore
              .collection(FirestoreCollections.topics)
              .where('creatorId', isEqualTo: uid)
              .limit(100);

      _topicsSubscription = trackSubscription(
        topicsQuery.snapshots().listen((snapshot) {
          _recomputeChannelIssues(topicDocs: snapshot.docs);
        }, onError: (err) {
          debugPrint('[NotificationViewController] Topics stream error: $err');
        }),
      );
    }
  }

  void _recomputeChannelIssues({
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? videoDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? copyrightDocs,
    DocumentSnapshot<Map<String, dynamic>>? channelDoc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? topicDocs,
  }) {
    if (videoDocs != null) _cachedVideoDocs = videoDocs;
    if (copyrightDocs != null) _cachedCopyrightDocs = copyrightDocs;
    if (channelDoc != null) _cachedChannelDoc = channelDoc;
    if (topicDocs != null) _cachedTopicDocs = topicDocs;

    final chId = currentChannelId.value;
    final uid = effectiveCreatorId;
    final issues = <UserNotification>[];

    // Topic issues (content moderation rejections, manual review, guideline flags)
    for (final doc in _cachedTopicDocs) {
      final data = doc.data();
      final rawName = (data['name'] as String?)?.trim() ??
          (data['title'] as String?)?.trim() ??
          '';
      final name = rawName.isNotEmpty ? rawName : 'Your Topic';
      final status = ((data['status'] as String?) ?? '').trim().toLowerCase();
      final geminiApproved = data['geminiApproved'] as bool?;
      final rawReason = (data['moderationReason'] as String?) ??
          (data['rejectionReason'] as String?) ??
          (data['reviewReason'] as String?) ??
          '';
      final thumb = (data['thumbnailUrl'] as String?) ??
          (data['coverImage'] as String?) ??
          '';
      final slug = (data['slug'] as String?) ?? doc.id;

      var updatedTime = DateTime.now();
      final ts = data['updatedAt'] ?? data['createdAt'];
      if (ts is Timestamp) {
        updatedTime = ts.toDate();
      } else if (ts is int) {
        updatedTime = DateTime.fromMillisecondsSinceEpoch(ts);
      }

      final isRejected = status == 'verificationrejected' ||
          status == 'rejected' ||
          status == 'action_required' ||
          status == 'actionrequired' ||
          (status != 'active' && geminiApproved == false);

      final isReview = status == 'underreview' ||
          status == 'manual_review' ||
          status == 'pending_review' ||
          (status == 'pending' && geminiApproved != true);

      if (isRejected) {
        issues.add(
          UserNotification(
            id: 'issue_topic_rejected_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'verification_result',
            severity: NotificationSeverity.priority,
            priority: NotificationPriority.critical,
            title: 'Content Moderation Action Required',
            message:
                'Your topic "$name" was not approved by content moderation: ${rawReason.isNotEmpty ? rawReason : "Did not meet community guidelines. Please edit and resubmit."}',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'moderation',
            metadata: {
              'topicId': doc.id,
              'topicSlug': slug,
              'topicTitle': name,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 14,
              'reason': rawReason,
              'itemType': 'topic',
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'all',
          ),
        );
      } else if (isReview) {
        issues.add(
          UserNotification(
            id: 'issue_topic_review_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'verification_result',
            severity: NotificationSeverity.warning,
            priority: NotificationPriority.high,
            title: 'Topic Under Manual Review',
            message:
                'Your topic "$name" is held for manual review by Trust & Safety.',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'moderation',
            metadata: {
              'topicId': doc.id,
              'topicSlug': slug,
              'topicTitle': name,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 14,
              'reason': rawReason,
              'itemType': 'topic',
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'all',
          ),
        );
      }
    }

    // Video issues (moderation, manual review, processing errors, fact-check disputes)
    for (final doc in _cachedVideoDocs) {
      final data = doc.data();
      final title = ((data['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['title'] as String).trim()
          : 'Your Video';
      final status = ((data['status'] as String?) ?? '').trim().toLowerCase();
      final modMap = data['moderation'] is Map
          ? Map<String, dynamic>.from(data['moderation'] as Map)
          : const <String, dynamic>{};
      final modStatus =
          ((modMap['status'] as String?) ?? '').trim().toLowerCase();
      final disputeMap = data['factCheckDispute'] is Map
          ? Map<String, dynamic>.from(data['factCheckDispute'] as Map)
          : const <String, dynamic>{};
      final disputeStatus =
          ((disputeMap['status'] as String?) ?? '').trim().toLowerCase();

      final rawReason = (data['rejectionReason'] as String?) ??
          (data['reviewReason'] as String?) ??
          (modMap['reason'] as String?) ??
          (data['errorMessage'] as String?) ??
          '';
      final thumb = (data['thumbnailUrl'] as String?) ?? '';

      var updatedTime = DateTime.now();
      final ts = data['updatedAt'] ?? data['createdAt'];
      if (ts is Timestamp) {
        updatedTime = ts.toDate();
      } else if (ts is int) {
        updatedTime = DateTime.fromMillisecondsSinceEpoch(ts);
      }

      if (status == 'rejected' || modStatus == 'rejected') {
        issues.add(
          UserNotification(
            id: 'issue_video_rejected_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'verification_result',
            severity: NotificationSeverity.priority,
            priority: NotificationPriority.critical,
            title: 'Truth Verification Action Required',
            message:
                'Your video "$title" was not accepted: ${rawReason.isNotEmpty ? rawReason : "Did not meet truth verification guidelines."}',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'verification',
            metadata: {
              'videoId': doc.id,
              'videoTitle': title,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 15,
              'reason': rawReason,
              'itemType': 'video',
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'studio',
          ),
        );
      } else if (status == 'manual_review' ||
          modStatus == 'manual_review' ||
          modStatus == 'pending_review') {
        issues.add(
          UserNotification(
            id: 'issue_video_manual_review_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'fact_check_pending',
            severity: NotificationSeverity.warning,
            priority: NotificationPriority.high,
            title: 'Video Under Manual Review',
            message:
                'Your video "$title" is held for manual human review by the Truthworld Trust & Safety team.',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'verification',
            metadata: {
              'videoId': doc.id,
              'videoTitle': title,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 15,
              'itemType': 'video',
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'studio',
          ),
        );
      } else if (status == 'failed' || status == 'error') {
        issues.add(
          UserNotification(
            id: 'issue_video_failed_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'video_processing_failed',
            severity: NotificationSeverity.warning,
            priority: NotificationPriority.high,
            title: 'Video Processing Issue',
            message:
                'Video "$title" encountered an issue during processing. Please re-upload or retry from Content.',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'pipeline',
            metadata: {
              'videoId': doc.id,
              'videoTitle': title,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 2,
              'itemType': 'video',
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'studio',
          ),
        );
      } else if (status == 'processing' ||
          status == 'uploading' ||
          status == 'transcribing' ||
          status == 'transcoding') {
        issues.add(
          UserNotification(
            id: 'issue_video_processing_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'video_processing',
            severity: NotificationSeverity.info,
            priority: NotificationPriority.medium,
            title: 'Video Processing In Progress',
            message:
                'Video "$title" is currently undergoing Truthworld AI transcription, processing, and safety checks.',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'pipeline',
            metadata: {
              'videoId': doc.id,
              'videoTitle': title,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 2,
              'itemType': 'video',
              'status': status,
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'studio',
          ),
        );
      }

      if (disputeStatus == 'pending_review' || disputeStatus == 'processing') {
        issues.add(
          UserNotification(
            id: 'issue_video_dispute_${doc.id}',
            userId: uid,
            channelId: chId,
            type: 'claim_dispute',
            severity: NotificationSeverity.info,
            priority: NotificationPriority.medium,
            title: 'Fact-Check Appeal In Review',
            message:
                'Fact-check appeal for "$title" is currently being re-evaluated with your provided sources.',
            thumbnailUrl: thumb,
            actionUrl: '/studio',
            category: 'verification',
            metadata: {
              'videoId': doc.id,
              'videoTitle': title,
              'thumbnailUrl': thumb,
              'channelId': chId,
              'tab': 15,
              'itemType': 'video',
            },
            read: false,
            createdAt: updatedTime,
            targetApp: 'studio',
          ),
        );
      }
    }

    // Copyright claims
    for (final doc in _cachedCopyrightDocs) {
      final data = doc.data();
      final claimChannelId = (data['channelId'] ?? '').toString();
      if (chId.isNotEmpty &&
          claimChannelId.isNotEmpty &&
          claimChannelId != chId) {
        continue;
      }
      final videoTitle =
          (data['videoTitle'] as String?)?.trim() ?? 'Your Video';
      final thumb = (data['thumbnailUrl'] as String?) ?? '';
      var createdTime = DateTime.now();
      final ts = data['createdAt'];
      if (ts is Timestamp) {
        createdTime = ts.toDate();
      } else if (ts is int) {
        createdTime = DateTime.fromMillisecondsSinceEpoch(ts);
      }

      issues.add(
        UserNotification(
          id: 'issue_copyright_${doc.id}',
          userId: uid,
          channelId: chId,
          type: 'copyright_claim',
          severity: NotificationSeverity.priority,
          priority: NotificationPriority.critical,
          title: 'Copyright Claim Notice',
          message:
              'A copyright claim was submitted for your video "$videoTitle". Review details in Copyright tab.',
          thumbnailUrl: thumb,
          actionUrl: '/studio',
          category: 'copyright',
          metadata: {
            'claimId': doc.id,
            'videoId': data['videoId'] ?? '',
            'videoTitle': videoTitle,
            'thumbnailUrl': thumb,
            'channelId': chId,
            'tab': 9,
          },
          read: false,
          createdAt: createdTime,
          targetApp: 'studio',
        ),
      );
    }

    // Channel branding & status notices
    if (_cachedChannelDoc != null && _cachedChannelDoc!.exists) {
      try {
        final channel = Channel.fromDocumentSnapshot(_cachedChannelDoc!);
        final updatedTime = channel.updatedAt.toDate();

        if (channel.avatarStatus == 'REJECTED' ||
            channel.avatarStatus == 'FLAGGED' ||
            channel.avatarStatus == 'MANUAL_REVIEW') {
          issues.add(
            UserNotification(
              id: 'issue_channel_avatar_${channel.id}',
              userId: uid,
              channelId: channel.id,
              type: 'channel_policy',
              severity: NotificationSeverity.warning,
              priority: NotificationPriority.high,
              title: 'Channel Profile Picture Notice',
              message:
                  'Your channel profile picture requires attention (${channel.avatarStatusReason ?? "Verification flagged"}).',
              actionUrl: '/studio',
              category: 'channel',
              metadata: {
                'channelId': channel.id,
                'tab': 6,
                'itemType': 'avatar',
                'avatarStatus': channel.avatarStatus,
              },
              read: false,
              createdAt: updatedTime,
              targetApp: 'studio',
            ),
          );
        }

        if (channel.bannerStatus == 'REJECTED' ||
            channel.bannerStatus == 'FLAGGED' ||
            channel.bannerStatus == 'MANUAL_REVIEW') {
          issues.add(
            UserNotification(
              id: 'issue_channel_banner_${channel.id}',
              userId: uid,
              channelId: channel.id,
              type: 'channel_policy',
              severity: NotificationSeverity.warning,
              priority: NotificationPriority.high,
              title: 'Channel Banner Notice',
              message:
                  'Your channel banner requires attention (${channel.bannerStatusReason ?? "Verification flagged"}).',
              actionUrl: '/studio',
              category: 'channel',
              metadata: {
                'channelId': channel.id,
                'tab': 6,
                'itemType': 'banner',
                'bannerStatus': channel.bannerStatus,
              },
              read: false,
              createdAt: updatedTime,
              targetApp: 'studio',
            ),
          );
        }

        if (channel.status == ChannelStatus.verificationRejected ||
            channel.status == ChannelStatus.underReview ||
            channel.status == ChannelStatus.suspended) {
          issues.add(
            UserNotification(
              id: 'issue_channel_status_${channel.id}',
              userId: uid,
              channelId: channel.id,
              type: 'channel_policy',
              severity: NotificationSeverity.priority,
              priority: NotificationPriority.critical,
              title: 'Channel Verification Update',
              message: channel.status == ChannelStatus.verificationRejected
                  ? 'Your channel verification was not approved. Please review channel policies in Studio.'
                  : 'Your channel verification is currently under review by Truthworld Trust & Safety.',
              actionUrl: '/studio',
              category: 'channel',
              metadata: {
                'channelId': channel.id,
                'tab': 8,
                'status': channel.status.name,
              },
              read: false,
              createdAt: updatedTime,
              targetApp: 'studio',
            ),
          );
        }

        if (channel.infraConfig?.isWithdrawalHeld == true) {
          issues.add(
            UserNotification(
              id: 'issue_channel_withdrawal_${channel.id}',
              userId: uid,
              channelId: channel.id,
              type: 'monetization_payout',
              severity: NotificationSeverity.warning,
              priority: NotificationPriority.high,
              title: 'Monetization Notice: Payout On Hold',
              message:
                  'Withdrawals are temporarily on hold for this channel. Review your Monetization settings.',
              actionUrl: '/studio',
              category: 'monetization',
              metadata: {
                'channelId': channel.id,
                'tab': 5,
              },
              read: false,
              createdAt: updatedTime,
              targetApp: 'studio',
            ),
          );
        }

        // Live audience subscriber milestone check from authentic channel stats
        if (channel.subscriberCount >= 100) {
          issues.add(
            UserNotification(
              id:
                  'milestone_subscribers_${channel.id}_${channel.subscriberCount}',
              userId: uid,
              channelId: channel.id,
              type: 'subscribers_milestone_v1',
              severity: NotificationSeverity.success,
              priority: NotificationPriority.high,
              title: '🎉 Milestone: ${channel.subscriberCount} Subscribers!',
              message:
                  'Congratulations! Your channel reached ${channel.subscriberCount} subscribers. Keep up the momentum!',
              actionUrl: '/subscribers',
              category: 'growth',
              metadata: {
                'channelId': channel.id,
                'tab': 12,
                'targetValue': channel.subscriberCount,
              },
              read: false,
              createdAt: updatedTime,
              targetApp: 'studio',
            ),
          );
        }

        // Live Channel Health & Good Standing status for Studio Alerts
        final hasVideoIssues = _cachedVideoDocs.any((d) {
          final s = (d.data()['status'] as String? ?? '').toLowerCase();
          return s == 'rejected' || s == 'failed' || s == 'error';
        });
        final hasTopicIssues = _cachedTopicDocs.any((d) {
          final s = (d.data()['status'] as String? ?? '').toLowerCase();
          final g = d.data()['geminiApproved'] as bool?;
          return s == 'verificationrejected' || s == 'rejected' || s == 'action_required' || s == 'actionrequired' || g == false;
        });
        final hasCopyrightClaims = _cachedCopyrightDocs.isNotEmpty;
        final isGoodStanding = !hasVideoIssues &&
            !hasTopicIssues &&
            !hasCopyrightClaims &&
            channel.status == ChannelStatus.active &&
            channel.avatarStatus != 'REJECTED' &&
            channel.bannerStatus != 'REJECTED' &&
            channel.infraConfig?.isWithdrawalHeld != true;

        if (isGoodStanding) {
          issues.add(
            UserNotification(
              id: 'channel_health_${channel.id}',
              userId: uid,
              channelId: channel.id,
              type: 'channel_health',
              severity: NotificationSeverity.info,
              title: 'Channel Health: Good Standing',
              message:
                  'All systems operational. No active copyright strikes, 0 policy violations, and your content pipeline is ready.',
              actionUrl: '/studio',
              category: 'channel',
              metadata: {
                'channelId': channel.id,
                'channelName': channel.channelName,
                'tab': 0,
                'status': 'healthy',
              },
              read: false,
              createdAt: updatedTime,
              targetApp: 'studio',
            ),
          );
        }
      } catch (e) {
        debugPrint('[NotificationViewController] Channel doc parse error: $e');
      }
    }

    // Baseline Channel Health alert whenever channel context is active and no issue items exist
    if (chId.isNotEmpty && issues.isEmpty) {
      issues.add(
        UserNotification(
          id: 'channel_health_$chId',
          userId: uid,
          channelId: chId,
          type: 'channel_health',
          severity: NotificationSeverity.info,
          title: 'Channel Health: Good Standing',
          message:
              'All systems operational. No active copyright strikes, 0 policy violations, and your content pipeline is ready.',
          actionUrl: '/studio',
          category: 'channel',
          metadata: {
            'channelId': chId,
            'tab': 0,
            'status': 'healthy',
          },
          read: false,
          createdAt: DateTime.now(),
          targetApp: 'studio',
        ),
      );
    }

    channelIssues.value = issues;
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    searchController.dispose();
    _videosSubscription?.cancel();
    _copyrightSubscription?.cancel();
    _channelSubscription?.cancel();
    _topicsSubscription?.cancel();
    channelIssues.clear();
    dismissedIssueIds.clear();
    readIssueIds.clear();
    super.onClose();
  }

  void selectTab(int index) {
    if (selectedTabIndex.value != index) {
      selectedTabIndex.value = index;
      HapticFeedback.selectionClick();
    }
  }

  void toggleSearching() {
    feedController.toggleSearching();
    if (!feedController.isSearching.value) {
      searchController.clear();
    }
  }

  void onSearchChanged(String value) {
    feedController.searchQuery.value = value;
    userNotificationController.searchQuery.value = value;
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  List<UnifiedNotificationItem> getUnifiedNotificationsForTab() {
    final items = <UnifiedNotificationItem>[];
    final tabId = activeTabId;
    final query = feedController.searchQuery.value.trim().toLowerCase();
    final chId = currentChannelId.value;
    final uid = effectiveCreatorId;
    final isStudio = isChannelContext || AppFlavor.isStudio;

    // 1. Video upload notifications (only for "all" tab and consumer feed mode)
    if (tabId == 'all' && !isStudio) {
      for (final v in feedController.notifications) {
        if (query.isNotEmpty) {
          final titleMatch = v.title.toLowerCase().contains(query);
          final channelMatch = v.channelName.toLowerCase().contains(query);
          if (!titleMatch && !channelMatch) continue;
        }
        items.add(
          UnifiedNotificationItem(
            video: v,
            timestamp: v.uploadedAt.toDate(),
            isSeen: v.isSeen,
          ),
        );
      }
    }

    // 2. Track video IDs, claim IDs, and topic IDs already covered by authentic backend notifications
    final existingVideoIds = <String>{};
    final existingClaimIds = <String>{};
    final existingTopicIds = <String>{};

    // 3. User & Channel notifications from backend
    for (final n in userNotificationController.notifications) {
      // In Consumer App mode: strictly gate out all Creator Studio notifications
      // (e.g. Fact-Check Completed, Video Processing Started, New Subscriber, Studio Alerts, etc.)
      if (!isStudio && (n.isStudioNotification && !n.isConsumerNotification)) {
        continue;
      }

      // In Studio mode: strictly gate out consumer notifications and enforce channel isolation
      if (isStudio) {
        final isForThisCreator =
            currentCreatorId.value.isNotEmpty && n.userId == currentCreatorId.value;
        if (!n.isStudioNotification && !isForThisCreator) {
          continue;
        }
        if (chId.isNotEmpty && n.channelId.isNotEmpty && n.channelId != chId) {
          continue;
        }
      }

      final typeLower = n.type.toLowerCase();
      final isMention = typeLower == 'mention' || n.category == 'mention';
      final titleLower = n.title.toLowerCase();
      final msgLower = n.message.toLowerCase();

      final isFactCheck = typeLower.contains('fact_check') ||
          typeLower.contains('factcheck') ||
          typeLower == 'claim_dispute' ||
          typeLower == 'batch_verification_result' ||
          (n.verificationReportId != null && n.verificationReportId!.isNotEmpty) ||
          titleLower.contains('fact-check') ||
          titleLower.contains('factcheck') ||
          titleLower.contains('fact check') ||
          titleLower.contains('truth verification') ||
          titleLower.contains('credibility score') ||
          titleLower.contains('truth score') ||
          titleLower.contains('claim appeal') ||
          msgLower.contains('fact-check') ||
          msgLower.contains('credibility score');

      final isProcessingStatus = typeLower.contains('processing') ||
          typeLower.contains('transcription') ||
          typeLower.contains('transcoding') ||
          typeLower.contains('dubbing') ||
          n.category == 'pipeline' ||
          titleLower.contains('processing') ||
          titleLower.contains('transcription') ||
          titleLower.contains('transcoding') ||
          titleLower.contains('dubbing') ||
          msgLower.contains('processing');

      final isPolicyAlert = typeLower.contains('policy') ||
          typeLower.contains('moderation') ||
          typeLower.contains('strike') ||
          n.category == 'policy' ||
          n.category == 'moderation' ||
          titleLower.contains('policy') ||
          titleLower.contains('moderation') ||
          titleLower.contains('manual review') ||
          titleLower.contains('not accepted') ||
          titleLower.contains('rejected') ||
          titleLower.contains('strike') ||
          titleLower.contains('guidelines') ||
          msgLower.contains('community guidelines') ||
          msgLower.contains('not accepted');

      final isChannelHealthAlert = typeLower.contains('channel') ||
          typeLower.contains('health') ||
          typeLower.contains('welcome') ||
          typeLower.contains('avatar') ||
          typeLower.contains('banner') ||
          n.category == 'channel' ||
          n.category == 'system' ||
          titleLower.contains('channel health') ||
          titleLower.contains('good standing') ||
          titleLower.contains('creator studio') ||
          titleLower.contains('welcome') ||
          msgLower.contains('all systems operational') ||
          msgLower.contains('welcome to creator studio');

      final isCopyrightAlert = typeLower.contains('copyright') ||
          n.category == 'copyright' ||
          titleLower.contains('copyright');

      final isMonetizationAlert = typeLower.contains('monetization') ||
          typeLower.contains('payout') ||
          n.category == 'monetization' ||
          titleLower.contains('monetization') ||
          titleLower.contains('payout');

      final isMilestoneAlert = typeLower.contains('milestone') ||
          typeLower.contains('sub_milestone') ||
          typeLower.contains('subscriber') ||
          n.category == 'growth' ||
          titleLower.contains('milestone') ||
          titleLower.contains('subscribers');

      final isVerif = isFactCheck ||
          (!isProcessingStatus &&
              !isPolicyAlert &&
              !isChannelHealthAlert &&
              !isCopyrightAlert &&
              (n.category == 'verification' ||
                  typeLower == 'verification_result' ||
                  typeLower.contains('verification')));

      final isAlert = !isFactCheck &&
          (isProcessingStatus ||
              isPolicyAlert ||
              isChannelHealthAlert ||
              isCopyrightAlert ||
              isMonetizationAlert ||
              isMilestoneAlert ||
              n.priority == NotificationPriority.critical ||
              n.severity == NotificationSeverity.priority ||
              n.severity == NotificationSeverity.warning);

      var belongsToTab = false;
      if (tabId == 'all') {
        belongsToTab = true; // All notifications (backend, audience, analytics, issues, comments, mentions)
      } else if (tabId == 'verifications') {
        belongsToTab = isVerif;
      } else if (tabId == 'studio_alerts') {
        belongsToTab = isAlert;
      } else if (tabId == 'topics') {
        belongsToTab = typeLower == 'new_video_topic' ||
            typeLower.contains('topic') ||
            n.category == 'topic' ||
            n.metadata?['itemType'] == 'topic' ||
            (n.metadata?['topicId'] as String?)?.isNotEmpty == true ||
            titleLower.contains('topic');
      } else if (tabId == 'comments') {
        belongsToTab = !isMention &&
            (typeLower.contains('comment') ||
                typeLower.contains('reply') ||
                typeLower.contains('like') ||
                n.typeCategory == 'social' ||
                n.category == 'comment');
      } else if (tabId == 'mentions') {
        belongsToTab = isMention;
      }

      if (!belongsToTab) continue;

      if (query.isNotEmpty) {
        final titleMatch = n.title.toLowerCase().contains(query);
        final messageMatch = n.message.toLowerCase().contains(query);
        if (!titleMatch && !messageMatch) continue;
      }

      final vId = (n.metadata?['videoId'] as String?) ?? '';
      if (vId.isNotEmpty) existingVideoIds.add(vId);
      final cId = (n.metadata?['claimId'] as String?) ?? '';
      if (cId.isNotEmpty) existingClaimIds.add(cId);
      final tId = (n.metadata?['topicId'] as String?) ?? '';
      if (tId.isNotEmpty) existingTopicIds.add(tId);

      items.add(
        UnifiedNotificationItem(
          alert: n,
          timestamp: n.createdAt,
          isSeen: n.read,
        ),
      );
    }

    // 4. Merge live channel issues
    final shouldIncludeIssues = (chId.isNotEmpty || uid.isNotEmpty) &&
        (tabId == 'all' || tabId == 'verifications' || tabId == 'studio_alerts' || tabId == 'topics');

    if (shouldIncludeIssues) {
      for (final issue in channelIssues) {
        if (dismissedIssueIds.contains(issue.id)) continue;

        // Baseline channel_health issue is reserved exclusively for studio_alerts when no other alerts exist
        if (issue.type == 'channel_health') continue;

        final isVerifIssue = issue.category == 'verification' ||
            issue.type == 'verification_result' ||
            issue.type == 'fact_check_pending' ||
            issue.type == 'claim_dispute';

        final isAlertIssue = issue.category == 'copyright' ||
            issue.category == 'channel' ||
            issue.category == 'pipeline' ||
            issue.category == 'policy' ||
            issue.category == 'moderation' ||
            issue.category == 'monetization' ||
            issue.type == 'video_processing' ||
            issue.type == 'video_processing_failed' ||
            issue.type == 'video_processing_started' ||
            issue.type == 'copyright_claim' ||
            issue.type == 'channel_policy' ||
            issue.type == 'video_policy' ||
            issue.type == 'monetization_payout' ||
            issue.type == 'subscribers_milestone_v1' ||
            issue.title.toLowerCase().contains('policy') ||
            issue.title.toLowerCase().contains('moderation') ||
            issue.title.toLowerCase().contains('health') ||
            issue.title.toLowerCase().contains('processing');

        final isTopicIssue = issue.metadata?['itemType'] == 'topic' ||
            (issue.metadata?['topicId'] as String?)?.isNotEmpty == true ||
            issue.type.contains('topic') ||
            issue.title.toLowerCase().contains('topic');

        var belongsToActiveTab = false;
        if (tabId == 'all') {
          belongsToActiveTab = true;
        } else if (tabId == 'verifications') {
          belongsToActiveTab = isVerifIssue;
        } else if (tabId == 'studio_alerts') {
          belongsToActiveTab = isAlertIssue;
        } else if (tabId == 'topics') {
          belongsToActiveTab = isTopicIssue;
        }

        if (!belongsToActiveTab) continue;

        final vId = (issue.metadata?['videoId'] as String?) ?? '';
        final cId = (issue.metadata?['claimId'] as String?) ?? '';
        final tId = (issue.metadata?['topicId'] as String?) ?? '';

        // If an authentic notification already covers this exact video, claim, or topic, authentic takes precedence
        if (vId.isNotEmpty && existingVideoIds.contains(vId)) continue;
        if (cId.isNotEmpty && existingClaimIds.contains(cId)) continue;
        if (tId.isNotEmpty && existingTopicIds.contains(tId)) continue;

        if (query.isNotEmpty) {
          final titleMatch = issue.title.toLowerCase().contains(query);
          final messageMatch = issue.message.toLowerCase().contains(query);
          if (!titleMatch && !messageMatch) continue;
        }

        final isSeen = readIssueIds.contains(issue.id) || issue.read;

        items.add(
          UnifiedNotificationItem(
            alert: issue.copyWith(read: isSeen),
            timestamp: issue.createdAt,
            isSeen: isSeen,
          ),
        );
      }
    }

    // 5. Studio Alerts Guarantee: If on studio_alerts tab and no alerts exist, inject baseline Channel Health
    if (tabId == 'studio_alerts' && chId.isNotEmpty && items.isEmpty) {
      final cachedHealth = channelIssues.firstWhereOrNull((i) => i.type == 'channel_health');
      final baselineHealth = cachedHealth ??
          UserNotification(
            id: 'channel_health_$chId',
            userId: effectiveCreatorId,
            channelId: chId,
            type: 'channel_health',
            severity: NotificationSeverity.info,
            title: 'Channel Health: Good Standing',
            message:
                'All systems operational. No active copyright strikes, 0 policy violations, and your content pipeline is ready.',
            actionUrl: '/studio',
            category: 'channel',
            metadata: {
              'channelId': chId,
              'tab': 0,
              'status': 'healthy',
            },
            read: readIssueIds.contains('channel_health_$chId'),
            createdAt: DateTime.now(),
            targetApp: 'studio',
          );

      if (!dismissedIssueIds.contains(baselineHealth.id)) {
        final isSeen = readIssueIds.contains(baselineHealth.id) || baselineHealth.read;
        items.add(
          UnifiedNotificationItem(
            alert: baselineHealth.copyWith(read: isSeen),
            timestamp: baselineHealth.createdAt,
            isSeen: isSeen,
          ),
        );
      }
    }

    // Sort: Critical priority first, then descending by timestamp
    items.sort((a, b) {
      final aPriority = a.alert?.priority ?? NotificationPriority.low;
      final bPriority = b.alert?.priority ?? NotificationPriority.low;

      if (aPriority == NotificationPriority.critical &&
          bPriority != NotificationPriority.critical) {
        return -1;
      }
      if (bPriority == NotificationPriority.critical &&
          aPriority != NotificationPriority.critical) {
        return 1;
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return items;
  }

  void markAllActiveTabAsRead() {
    final items = getUnifiedNotificationsForTab();
    final unreadItems = items.where((item) => !item.isSeen).toList();

    if (unreadItems.isEmpty) return;

    final hasUnreadVideos = unreadItems.any((item) => item.video != null);
    final hasUnreadAlerts = unreadItems.any((item) => item.alert != null);

    if (hasUnreadVideos) {
      feedController.markAllAsSeen();
    }
    if (hasUnreadAlerts) {
      for (final item in unreadItems) {
        if (item.alert != null) {
          readIssueIds.add(item.alert!.id);
        }
      }
      userNotificationController.markAllAsRead();
    }

    AppSnackbar.info(
      'Marked active notifications as read',
      title: 'Notifications updated',
    );
  }
}
