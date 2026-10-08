import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// THEME COLORS (Exact TruthWorld Discover Palette)
// ==========================================================================

const Color bgColor = AppColors.bgPage;
const Color surfaceColor = AppColors.bgPage;
const Color cardColor = Color(0xFF1E1E22);
const Color primaryText = AppColors.textPrimary;
const Color secondaryText = AppColors.textSecondary;
const Color accentColor = AppColors.textPrimary;
const Color buttonBg = AppColors.bgSurfaceHover;
const Color kDiscoverVerifiedBlue = Color(0xFF3B82F6);
const Color kDiscoverCardBorder = Color(0x1FFFFFFF);

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================

const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

// ==========================================================================
// FORMATTERS & MAPPERS
// ==========================================================================

String formatSubscriberCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

String getCategoryImage(String category) {
  return AppCategories.getImageUrl(category);
}

String getCategoryChannelCount(String category) {
  // Returns authentic count from DiscoverChannelsController if available.
  if (Get.isRegistered<DiscoverChannelsController>()) {
    final count = Get.find<DiscoverChannelsController>().getCategoryCount(category);
    return formatChannelCount(count);
  }
  return AppCategories.getChannelCount(category);
}

String formatChannelCount(int count) {
  if (count <= 0) return '0 channels';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M channels';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K channels';
  return '$count ${count == 1 ? 'channel' : 'channels'}';
}

IconData getCategoryIcon(String category) {
  return AppCategories.getIcon(category);
}

String getCategoryDescription(String category) {
  return AppCategories.getDescription(category);
}
