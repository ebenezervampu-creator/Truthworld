import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_shortcuts_modal.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Presentation view controller managing animation controllers, responsive drawers,
/// channel resolution, and navigation routes for [DashboardScreen].
class DashboardViewController extends BaseController
    with GetTickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();
  bool _isSearchControllerDisposed = false;
  bool _isSearchFocusNodeDisposed = false;
  bool _isDisposed = false;

  TextEditingController get searchController {
    if (_isSearchControllerDisposed) {
      _searchController = TextEditingController();
      _isSearchControllerDisposed = false;
    }
    return _searchController;
  }

  FocusNode get searchFocusNode {
    if (_isSearchFocusNodeDisposed) {
      _searchFocusNode = FocusNode();
      _isSearchFocusNodeDisposed = false;
    }
    return _searchFocusNode;
  }

  final RxBool isSelectingDefault = true.obs;
  final Rxn<Channel> channelPendingDeletion = Rxn<Channel>();
  final RxBool isChannelInDeletionGracePeriod = false.obs;
  final RxBool isRestoringChannel = false.obs;

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
      final ctrl = Get.find<DashboardController>();
      final chId = getChannelId(channel);
      if (chId.isNotEmpty && ctrl.channelId != chId) {
        ctrl.updateChannelId(chId);
      } else if (chId.isEmpty && ctrl.channelId.isNotEmpty) {
        ctrl.clearData();
      }
      return ctrl;
    }
    return Get.put(DashboardController(channelId: getChannelId(channel)));
  }

  dynamic get channel {
    final currentUser = FirebaseAuth.instance.currentUser;
    final args = Get.arguments;
    if (args is Map && args['channel'] != null) {
      final ch = args['channel'];
      Channel? parsedChannel;
      if (ch is Channel) {
        parsedChannel = ch;
      } else if (ch is Map) {
        parsedChannel = Channel.fromMap(
          Map<String, dynamic>.from(ch),
          (ch['id'] ?? '').toString(),
        );
      }
      if (parsedChannel != null) {
        if (currentUser == null ||
            parsedChannel.ownerId == currentUser.uid) {
          return parsedChannel;
        }
      }
    }
    if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
      final authCh = AuthService.to.userChannel!;
      if (currentUser == null ||
          authCh.ownerId == currentUser.uid) {
        return authCh;
      }
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
    _initGlobalKeyboardListener();
    final initChannelId = getChannelId(channel);
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController(channelId: initChannelId));
    }
    unawaited(resolveChannelAndInit());

    _authWorker = ever(AuthService.to.isAuthenticated, (isAuth) {
      if (!isAuth) {
        channelPendingDeletion.value = null;
        isChannelInDeletionGracePeriod.value = false;
        isSelectingDefault.value = false;
        if (Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().clearData();
        }
      } else {
        if (Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().clearData();
        }
        unawaited(resolveChannelAndInit());
      }
    });

    _channelWorker = ever(AuthService.to.rxUserChannel, (ch) {
      if (ch == null) {
        if (Get.isRegistered<DashboardController>()) {
          dashboardController.clearData();
        }
      } else {
        if (Get.isRegistered<DashboardController>()) {
          dashboardController.currentChannel.value = ch;
          dashboardController.updateChannelId(ch.id);
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
    if (isClosed || _isDisposed) return;
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
      if (Get.isRegistered<DashboardController>()) {
        dashboardController.clearData();
      }
      return;
    }

    isSelectingDefault.value = true;
    try {

      dynamic resolvedChannel = channel;
      resolvedChannel ??= authService.userChannel;
      resolvedChannel ??= await authService.ensureChannelLoaded();

      Channel? foundDeletedChannel;

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
            final allDocs = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .toList();
            final activeDocs = allDocs
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();
            if (activeDocs.isNotEmpty) {
              resolvedChannel = activeDocs.first;
              authService.setUserChannel(resolvedChannel);
            } else {
              final deletedDocs = allDocs
                  .where((c) => c.status == ChannelStatus.deleted)
                  .toList();
              if (deletedDocs.isNotEmpty) {
                foundDeletedChannel = deletedDocs.first;
              }
            }
          }

          if (resolvedChannel == null) {
            final userDoc = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .get();
            final chId = (userDoc.data()?['deletedChannelId'] ??
                userDoc.data()?['channelId']) as String?;
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
                } else {
                  foundDeletedChannel ??= ch;
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

      foundDeletedChannel ??= authService.deletedChannel;

      if (resolvedChannel == null && foundDeletedChannel != null) {
        channelPendingDeletion.value = foundDeletedChannel;
        isChannelInDeletionGracePeriod.value = true;
        isSelectingDefault.value = false;
        return;
      }

      channelPendingDeletion.value = null;
      isChannelInDeletionGracePeriod.value = false;

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
        if (Get.isRegistered<DashboardController>()) {
          dashboardController.clearData();
        }
        return;
      }

      final channelId = getChannelId(resolvedChannel);
      final ctrl = dashboardController;
      if (channelId.isNotEmpty && ctrl.channelId != channelId) {
        ctrl.updateChannelId(channelId);
      } else if (channelId.isEmpty) {
        ctrl.clearData();
      }

      if (resolvedChannel is Channel) {
        ctrl.currentChannel.value = resolvedChannel;
      } else if (resolvedChannel is Map) {
        ctrl.currentChannel.value = Channel.fromMap(
          Map<String, dynamic>.from(resolvedChannel),
          (resolvedChannel['id'] ?? channelId).toString(),
        );
      } else {
        ctrl.currentChannel.value = null;
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
          ctrl.selectedIndex.value = 2;
        } else if (currentRoute.contains('/drafts') ||
            tabParam == 'drafts' ||
            tabParam == '20') {
          ctrl.selectedIndex.value = 2;
        } else if (currentRoute.contains('/community') ||
            tabParam == 'community' ||
            tabParam == 'posts' ||
            tabParam == '19') {
          ctrl.selectedIndex.value = 2;
        } else if (tabParam == 'verification' ||
            tabParam == 'fact_check' ||
            tabParam == '15') {
          ctrl.selectedIndex.value = 15;
        } else if (tabParam == 'copyright' ||
            tabParam == 'claims' ||
            tabParam == '9') {
          ctrl.selectedIndex.value = 9;
        } else if (tabParam == 'intelligence' ||
            tabParam == 'coach' ||
            tabParam == '16') {
          ctrl.selectedIndex.value = 16;
        } else if (tabParam == 'monetization' ||
            tabParam == 'wallet' ||
            tabParam == '5') {
          ctrl.selectedIndex.value = 5;
        } else if (tabParam == 'audience' ||
            tabParam == 'subscribers' ||
            tabParam == '12') {
          ctrl.selectedIndex.value = 12;
        } else if (tabParam == 'comments' || tabParam == '4') {
          ctrl.selectedIndex.value = 4;
        } else if (tabParam == 'analytics' || tabParam == '3') {
          ctrl.selectedIndex.value = 3;
        } else if (tabParam == 'content' ||
            tabParam == 'videos' ||
            tabParam == '2') {
          ctrl.selectedIndex.value = 2;
        }
      }

      final vmCtrl = Get.isRegistered<VideoManagementController>()
          ? Get.find<VideoManagementController>()
          : Get.put(VideoManagementController());
      if (channelId.isNotEmpty) {
        vmCtrl.ensureInitialized(channelId);
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
      if (!isClosed && !_isDisposed) {
        isSelectingDefault.value = false;
        if (AuthService.to.isAuthenticated.value) {
          startAnimations();
        }
      }
    }
  }

  Future<void> handleGoogleSignIn() async {
    try {
      final ctx = Get.context;
      if (ctx != null) {
        await AuthBottomSheet.show(ctx);
      } else {
        await AuthService.to.signInWithGoogle();
      }
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
          (e is AuthException && (e.code == 'user-cancelled' || e.code == 'redirecting')) ||
          (e is GoogleSignInException && (e.code == 'user-cancelled' || e.code == 'redirecting'))) {
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
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().clearData();
      }
      await AuthService.to.signOut();
      AppSnackbar.success('You have been successfully signed out.');
      final isStudioContext = AppFlavor.isStudio ||
          Get.currentRoute.toLowerCase().startsWith('/studio') ||
          (kIsWeb &&
              (Uri.base.host.toLowerCase().startsWith('studio') ||
                  Uri.base.path.toLowerCase().startsWith('/studio')));
      if (isStudioContext) {
        Get.offAllNamed(AppRoutes.studio);
      } else {
        Get.offAllNamed('/');
      }
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

  void _initGlobalKeyboardListener() {
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKeyEvent);
  }

  bool _handleGlobalHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Check if an editable text is already focused
    final primaryFocus = FocusManager.instance.primaryFocus;
    final isEditing = primaryFocus?.context?.widget is EditableText;

    // Escape clears search focus or dismisses
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (searchFocusNode.hasFocus) {
        searchFocusNode.unfocus();
        return true;
      }
    }

    // If typing inside an input field, do not hijack shortcuts (except Escape)
    if (isEditing) return false;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isControlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Show studio shortcuts modal: '?' or Shift + '/'
    if (!isControlOrMeta &&
        (event.logicalKey == LogicalKeyboardKey.question ||
            (isShift && event.logicalKey == LogicalKeyboardKey.slash))) {
      final context = Get.context;
      if (context != null) {
        StudioShortcutsModal.show(context);
        return true;
      }
    }

    // Quick Search focus: '/' (without shift/ctrl)
    if (!isShift && !isControlOrMeta && event.logicalKey == LogicalKeyboardKey.slash) {
      searchFocusNode.requestFocus();
      return true;
    }

    // Quick Search focus: Ctrl/Cmd + K
    if (isControlOrMeta && event.logicalKey == LogicalKeyboardKey.keyK) {
      searchFocusNode.requestFocus();
      return true;
    }

    // Studio Save: Ctrl/Cmd + S
    if (isControlOrMeta && event.logicalKey == LogicalKeyboardKey.keyS) {
      AppSnackbar.success(
        'All studio metadata and edits are up to date.',
        title: 'Studio Saved',
      );
      return true;
    }

    return false;
  }

  /// Cancels the scheduled channel deletion and restores the channel.
  Future<bool> cancelChannelDeletion() async {
    final channelToRestore = channelPendingDeletion.value;
    final user = FirebaseAuth.instance.currentUser;
    if (channelToRestore == null || user == null) {
      AppSnackbar.error('Unable to restore channel. Please try again.');
      return false;
    }

    if (channelToRestore.isPermanentDeletionExpired) {
      AppSnackbar.error(
        'The 30-day grace period for this channel has expired and it cannot be restored.',
      );
      return false;
    }

    try {
      isRestoringChannel.value = true;

      // 1. Restore channel document in Firestore
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelToRestore.id)
          .update({
        'status': ChannelStatus.active.name,
        'deletionScheduledAt': FieldValue.delete(),
        'deletionGracePeriodExpiresAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Restore user doc in Firestore
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .set({
        'hasChannel': true,
        'channelId': channelToRestore.id,
        'deletedChannelId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update active Channel object
      final restoredChannel = channelToRestore.copyWith(
        status: ChannelStatus.active,
      );

      // 4. Update AuthService
      final auth = AuthService.to;
      auth.setUserChannel(restoredChannel);
      auth.setDeletedChannel(null);
      auth.hasChannel.value = true;

      // 5. Update local view state
      channelPendingDeletion.value = null;
      isChannelInDeletionGracePeriod.value = false;

      // 6. Update DashboardController
      final ctrl = dashboardController;
      ctrl.updateChannelId(restoredChannel.id);
      ctrl.currentChannel.value = restoredChannel;
      ctrl.retryLoad();

      AppSnackbar.success(
        'Channel deletion cancelled. Your channel has been fully restored!',
        title: 'Channel Restored',
      );

      // Re-initialize dashboard
      await resolveChannelAndInit();
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardViewController.cancelChannelDeletion',
      );
      AppSnackbar.error(
        'Unable to restore channel. Please check your connection and try again.',
      );
      return false;
    } finally {
      isRestoringChannel.value = false;
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKeyEvent);
    _authWorker?.dispose();
    _channelWorker?.dispose();
    if (!_isSearchControllerDisposed) {
      _searchController.dispose();
      _isSearchControllerDisposed = true;
    }
    if (!_isSearchFocusNodeDisposed) {
      _searchFocusNode.dispose();
      _isSearchFocusNodeDisposed = true;
    }
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
