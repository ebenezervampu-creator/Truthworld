import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_models.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Controller managing state and user flow for creator channel plan selection.
class ChannelPlanSelectionController extends BaseController
    with GetSingleTickerProviderStateMixin {
  final selectedPlan = Rx<ChannelPlanType?>(null);
  final hoveredPlan = Rx<ChannelPlanType?>(null);
  late AnimationController animController;
  late Animation<double> fadeAnim;

  @override
  void onInit() {
    super.onInit();
    animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
    );
    animController.forward();
  }

  @override
  void onClose() {
    animController.dispose();
    super.onClose();
  }

  /// Verifies moderation lockout criteria before proceeding to channel wizard.
  Future<void> proceedToChannelCreation() async {
    if (selectedPlan.value == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final rejectionCount =
              (data['channelRejectionCount'] as num?)?.toInt() ?? 0;
          final lastRejectedAt =
              (data['channelLastRejectedAt'] as num?)?.toInt();
          if (rejectionCount >= 2 && lastRejectedAt != null) {
            final lastRejectedDateTime = DateTime.fromMillisecondsSinceEpoch(
              lastRejectedAt,
            );
            final unlockDateTime = lastRejectedDateTime.add(
              const Duration(days: 30),
            );
            if (DateTime.now().isBefore(unlockDateTime)) {
              final unlockDateStr =
                  unlockDateTime.toLocal().toString().split(' ')[0];
              AppSnackbar.show(
                'Account Locked',
                'Channel creation is locked until $unlockDateStr due to multiple moderation failures.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
              );
              return;
            }
          }
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ChannelPlanSelectionController.proceedToCreation',
        );
      }
    }

    Get.toNamed(
      '/channelscreen',
      arguments: {'planType': selectedPlan.value},
    );
  }
}
