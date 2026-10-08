import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/data/models/subscriptions.dart';

enum ContentFilter {
  all,
  videos,
  playlists,
  communityPosts,
  topics,
}

enum SortFilter {
  trending,
  popular,
  newest,
  oldest,
}

enum DurationFilter {
  all,
  short,
  medium,
  long,
}

enum DateRangeFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
}

/// Core abstract base controller holding reactive observables, filters, and lifecycle for subscriptions.
abstract class SubscriptionStateBase extends BaseController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  StreamSubscription<ConnectivityResult>? connectivitySubscription;

  final RxList<SubscriptionContent> allContent = <SubscriptionContent>[].obs;
  final RxList<SubscriptionContent> filteredContent =
      <SubscriptionContent>[].obs;
  final RxList<Subscription> subscriptions = <Subscription>[].obs;
  final RxList<Channel> subscribedChannels = <Channel>[].obs;

  final RxString selectedContentFilter = ContentFilter.all.name.obs;
  final RxString selectedSortFilter = SortFilter.trending.name.obs;
  final RxString selectedDurationFilter = DurationFilter.all.name.obs;
  final RxString selectedDateRangeFilter = DateRangeFilter.all.name.obs;

  final RxBool rxIsLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString rxErrorMessage = ''.obs;

  String? get currentUserId =>
      AuthService.to.uid.isNotEmpty ? AuthService.to.uid : null;

  @override
  void onInit() {
    super.onInit();

    // Initial load
    refresh();

    // Setup auth listener to automatically refresh on auth status change
    addWorker(
      ever(AuthService.to.currentUser, (user) {
        debugPrint(
          '[SubscriptionController] Auth state changed. Refreshing subscriptions...',
        );
        refresh();
      }),
    );

    // Setup connectivity listener for automatic recovery
    try {
      if (Get.isRegistered<ConnectivityService>()) {
        connectivitySubscription = Get.find<ConnectivityService>()
            .onConnectivityRestored
            .listen(
              (_) {
                debugPrint(
                  '[SubscriptionController] Network restored. Refreshing subscriptions...',
                );
                refresh();
              },
              onError: (error, stackTrace) {
                ErrorHandler.log(
                  error,
                  stackTrace: stackTrace,
                  tag: 'SubscriptionController.connectivity',
                );
              },
            );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'SubscriptionController.connectivitySetup',
      );
    }
  }

  @override
  void onClose() {
    connectivitySubscription?.cancel();
    connectivitySubscription = null;
    super.onClose();
  }

  // Cross-mixin abstract contracts
  @override
  Future<void> refresh();
  Future<void> loadSubscriptions();
  Future<void> loadSubscribedChannels();
  Future<void> loadAllContent();
  void applyFilters();
}
