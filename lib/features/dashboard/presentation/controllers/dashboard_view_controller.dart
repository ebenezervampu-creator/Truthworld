import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';

/// Presentation view controller managing animation controllers, responsive drawers,
/// channel resolution, and navigation routes for [DashboardScreen].
class DashboardViewController extends BaseController
    with GetTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController searchController = TextEditingController();

  final RxBool isSelectingDefault = true.obs;

  Worker? _authWorker;
  Worker? _channelWorker;

  // Animation Controllers
  late AnimationController staggeredAnimationController;
  late AnimationController drawerAnimationController;
  late AnimationController statsAnimationController;
  late AnimationController chartAnimationController;

  // Animations
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> drawerAnimation;
  late Animation<double> statsAnimation;
  late Animation<double> chartAnimation;

  DashboardController get dashboardController {
    if (Get.isRegistered<DashboardController>()) {
      return Get.find<DashboardController>();
    }
    return Get.put(DashboardController(channelId: getChannelId(channel)));
  }

  dynamic get channel {
    final args = Get.arguments;
    if (args is Map && args['channel'] != null) {
      final ch = args['channel'];
      if (ch is Channel) return ch;
      if (ch is Map) {
        return Channel.fromMap(
          Map<String, dynamic>.from(ch),
          (ch['id'] ?? '').toString(),
        );
      }
      return ch;
    }
    if (Get.isRegistered<DashboardController>()) {
      final activeCtrl = Get.find<DashboardController>();
      if (activeCtrl.currentChannel.value != null) {
        return activeCtrl.currentChannel.value;
      }
    }
    if (AuthService.to.userChannel != null) {
      return AuthService.to.userChannel;
    }
    return null;
  }

  String getChannelId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.id;
    if (ch is Map) return (ch['id'] ?? '').toString();
    if (ch is DocumentSnapshot) return ch.id;
    return '';
  }

  String getOwnerId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.ownerId;
    if (ch is Map) return (ch['ownerId'] ?? ch['userId'] ?? '').toString();
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      return (data?['ownerId'] ?? data?['userId'] ?? '').toString();
    }
    return '';
  }

  String getChannelName(dynamic ch) {
    if (ch == null) return 'Unknown Channel';
    if (ch is Channel) return ch.name.isNotEmpty ? ch.name : 'Unknown Channel';
    if (ch is Map) {
      final val = ch['channelName'] ?? ch['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      final val = data?['channelName'] ?? data?['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    return 'Unknown Channel';
  }

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    final initChannelId = getChannelId(channel);
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController(channelId: initChannelId));
    }
    unawaited(resolveChannelAndInit());

    _authWorker = ever(AuthService.to.isAuthenticated, (isAuth) {
      if (isAuth && !isSelectingDefault.value && channel == null) {
        unawaited(resolveChannelAndInit());
      }
    });

    _channelWorker = ever(AuthService.to.rxUserChannel, (ch) {
      if (ch != null) {
        if (Get.isRegistered<DashboardController>()) {
          dashboardController.currentChannel.value = ch;
        }
      }
    });
  }

  void _initializeAnimations() {
    staggeredAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: staggeredAnimationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: staggeredAnimationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: staggeredAnimationController,
        curve: const Interval(0.4, 1, curve: Curves.elasticOut),
      ),
    );

    drawerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: drawerAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    statsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: statsAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    chartAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: chartAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void startAnimations() {
    if (!staggeredAnimationController.isAnimating &&
        !staggeredAnimationController.isCompleted) {
      staggeredAnimationController.forward();
    }
    if (!drawerAnimationController.isAnimating &&
        !drawerAnimationController.isCompleted) {
      drawerAnimationController.forward();
    }
    if (!statsAnimationController.isAnimating &&
        !statsAnimationController.isCompleted) {
      statsAnimationController.forward();
    }
    if (!chartAnimationController.isAnimating &&
        !chartAnimationController.isCompleted) {
      chartAnimationController.forward();
    }
  }

  Future<void> resolveChannelAndInit() async {
    final authService = AuthService.to;
    final user = FirebaseAuth.instance.currentUser;

    if (!authService.isAuthenticated.value && user == null) {
      isSelectingDefault.value = false;
      return;
    }

    isSelectingDefault.value = true;
    try {

      dynamic resolvedChannel = channel;
      resolvedChannel ??= authService.userChannel;
      resolvedChannel ??= await authService.ensureChannelLoaded();

      if (resolvedChannel == null && user != null) {
        try {
          var snapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .where('ownerId', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection(FirestoreCollections.channels)
                .where('userId', isEqualTo: user.uid)
                .limit(1)
                .get();
          }

          if (snapshot.docs.isNotEmpty) {
            final activeDocs = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();
            if (activeDocs.isNotEmpty) {
              resolvedChannel = activeDocs.first;
              authService.setUserChannel(resolvedChannel);
            }
          }

          if (resolvedChannel == null) {
            final userDoc = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .get();
            final chId = userDoc.data()?['channelId'] as String?;
            if (chId != null && chId.isNotEmpty) {
              final chDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(chId)
                  .get();
              if (chDoc.exists && chDoc.data() != null) {
                final ch = Channel.fromDocumentSnapshot(chDoc);
                if (ch.status != ChannelStatus.deleted) {
                  resolvedChannel = ch;
                  authService.setUserChannel(resolvedChannel);
                }
              }
            }
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'DashboardViewController.resolveChannelAndInit.fetchChannel',
          );
        }
      }

      if (resolvedChannel != null && authService.userChannel == null) {
        if (resolvedChannel is Channel) {
          authService.setUserChannel(resolvedChannel);
        } else if (resolvedChannel is Map) {
          authService.setUserChannel(
            Channel.fromMap(
              Map<String, dynamic>.from(resolvedChannel),
              (resolvedChannel['id'] ?? '').toString(),
            ),
          );
        }
      }

      if (resolvedChannel == null &&
          !authService.hasChannel.value &&
          authService.isAuthenticated.value) {
        isSelectingDefault.value = false;
        await Get.offAllNamed<dynamic>('/channelscreen');
        return;
      }

      final channelId = getChannelId(resolvedChannel);
      final ctrl = dashboardController;
      if (channelId.isNotEmpty && ctrl.channelId != channelId) {
        ctrl.updateChannelId(channelId);
      }

      if (ctrl.currentChannel.value == null) {
        if (resolvedChannel is Channel) {
          ctrl.currentChannel.value = resolvedChannel;
        } else if (resolvedChannel is Map) {
          ctrl.currentChannel.value = Channel.fromMap(
            Map<String, dynamic>.from(resolvedChannel),
            (resolvedChannel['id'] ?? channelId).toString(),
          );
        }
      }

      final args = Get.arguments;
      final tabIndex = args is Map ? args['tab'] as int? : null;
      if (tabIndex != null) {
        ctrl.selectedIndex.value = tabIndex;
      } else {
        final currentRoute = Get.currentRoute.toLowerCase();
        final tabParam = (Get.parameters['tab'] ?? '').toLowerCase();
        if (currentRoute.contains('/chapters') ||
            tabParam == 'chapters' ||
            tabParam == '11') {
          ctrl.selectedIndex.value = 11;
        } else if (currentRoute.contains('/trash') ||
            tabParam == 'trash' ||
            tabParam == '13') {
          ctrl.selectedIndex.value = 13;
        } else if (currentRoute.contains('/drafts') ||
            tabParam == 'drafts' ||
            tabParam == '20') {
          ctrl.selectedIndex.value = 20;
        }
      }

      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
    } on Object catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardViewController.resolveChannelAndInit',
      );
      if (!Get.isRegistered<DashboardController>()) {
        Get.put(DashboardController());
      }
      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
    } finally {
      isSelectingDefault.value = false;
      if (AuthService.to.isAuthenticated.value) {
        startAnimations();
      }
    }
  }

  Future<void> handleGoogleSignIn() async {
    try {
      await AuthService.to.signInWithGoogle();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        AppSnackbar.success('Signed in as ${user.email}');
        await resolveChannelAndInit();
      } else {
        isSelectingDefault.value = false;
      }
    } catch (e) {
      isSelectingDefault.value = false;
      if (e is GoogleSignInUserCancelledException ||
          (e is AuthException && e.code == 'user-cancelled')) {
        return;
      }
      var message = 'Failed to sign in';
      if (e is GoogleSignInException) {
        message = e.getDisplayMessage();
      }
      AppSnackbar.error(message);
    }
  }

  Future<void> handleSignOut() async {
    try {
      await AuthService.to.signOut();
      AppSnackbar.success('You have been successfully signed out.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to sign out. Please try again.');
    }
  }

  void openCreateTopicDialogFromQuickActions(
    BuildContext context,
    bool isDarkMode,
  ) {
    final topicCtrl = Get.isRegistered<TopicManagementController>()
        ? Get.find<TopicManagementController>()
        : Get.put(TopicManagementController());
    final currentChannelId = getChannelId(channel);
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDarkMode,
      channelVideosFuture: topicCtrl.fetchChannelVideos(currentChannelId),
      onCreateTopicSubmitted: (createCtrl) async {
        String? finalThumbnailUrl;
        if (createCtrl.thumbnailSource.value == 'custom' &&
            createCtrl.pickedCustomImageBytes.value != null) {
          finalThumbnailUrl = await topicCtrl.uploadTopicThumbnail(
            createCtrl.pickedCustomImageBytes.value!,
            createCtrl.pickedCustomImageName.value ?? 'custom_topic_thumb.jpg',
          );
        } else if (createCtrl.thumbnailSource.value == 'video') {
          finalThumbnailUrl = createCtrl.chosenVideoThumbnailUrl.value;
        }

        await topicCtrl.createTopic(
          channelId: currentChannelId,
          title: createCtrl.titleController.text,
          handle: createCtrl.handleController.text,
          description: createCtrl.descriptionController.text,
          category: createCtrl.categoryController.text.isEmpty
              ? 'General'
              : createCtrl.categoryController.text,
          thumbnailUrl: finalThumbnailUrl,
          selectedVideoIds: createCtrl.selectedVideoIds.toList(),
        );
      },
    );
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    _channelWorker?.dispose();
    searchController.dispose();
    if (staggeredAnimationController.isAnimating) {
      staggeredAnimationController.stop();
    }
    staggeredAnimationController.dispose();
    if (drawerAnimationController.isAnimating) {
      drawerAnimationController.stop();
    }
    drawerAnimationController.dispose();
    if (statsAnimationController.isAnimating) {
      statsAnimationController.stop();
    }
    statsAnimationController.dispose();
    if (chartAnimationController.isAnimating) {
      chartAnimationController.stop();
    }
    chartAnimationController.dispose();
    if (Get.isRegistered<DashboardController>()) {
      Get.delete<DashboardController>();
    }
    super.onClose();
  }
}
