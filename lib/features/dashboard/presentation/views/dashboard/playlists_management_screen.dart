import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_management_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_management_widgets.dart';

/// Modernized Playlists Management Tab for Truthworld Studio.
/// Visual architecture, fonts, colors, and layout fully aligned with Consumer App standards.
class PlaylistsManagementScreen
    extends GetView<PlaylistsManagementController> {
  const PlaylistsManagementScreen({
    super.key,
    this.channelId,
    this.isDarkMode = true,
    this.searchQuery = '',
  });

  final String? channelId;
  final bool isDarkMode;
  final String searchQuery;

  String get activeChannelId {
    if (channelId != null && channelId!.isNotEmpty) {
      return channelId!;
    }
    if (Get.isRegistered<AuthService>() &&
        AuthService.to.userChannel?.id != null) {
      return AuthService.to.userChannel!.id;
    }
    return AuthService.to.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          // Studio Header, Summary Metrics & Search/Filter Bar
          SliverToBoxAdapter(
            child: PlaylistsMetricsBar(channelId: activeChannelId),
          ),

          // Main Playlists Content Grid / List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: PlaylistsViewBody(channelId: activeChannelId),
            ),
          ),
        ],
      ),
    );
  }
}
