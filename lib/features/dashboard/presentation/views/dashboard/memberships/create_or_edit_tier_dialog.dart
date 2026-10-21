import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships/create_or_edit_tier_page.dart';

/// Opens the dedicated, 100% responsive Create or Edit Membership Tier Page.
/// Replaces the legacy modal dialog with a full-screen, device-adaptive Studio page.
void showCreateOrEditTierDialog({
  required BuildContext context,
  required MembershipsController controller,
  required bool isDarkMode,
  ChannelMembershipTier? tier,
}) {
  Get.to<void>(
    () => CreateOrEditTierPage(
      controller: controller,
      tier: tier,
      isDarkMode: isDarkMode,
    ),
  );
}
