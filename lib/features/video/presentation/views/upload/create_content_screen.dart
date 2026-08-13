import 'dart:io' as io;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/image_cropper_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/ai_features_selector.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// CREATE CONTENT SCREEN - Refactored to support specific upload types
// ==========================================================================

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({
    required this.uploadType,
    super.key,
  });
  final UploadType uploadType;

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final UploadController _uploadController;
  late final PlaylistController _playlistController;

  // Text Controllers with validation
  final _videoDetailsFormKey = GlobalKey<FormState>();
  final _communityDetailsFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _communityTitleController = TextEditingController();
  final _communityDescriptionController = TextEditingController();
  final _communityTagsController = TextEditingController();

  // Animation Controllers
  late AnimationController _mainAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideInAnimation;

  // Page Controller for step navigation
  late final PageController _pageController;
  final int _totalSteps = 4;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _startInitialAnimations();
  }

  void _initializeControllers() {
    _pageController = PageController();

    if (!Get.isRegistered<UploadController>()) {
      Get.put(UploadController());
    }
    _uploadController = Get.find<UploadController>();

    if (!Get.isRegistered<PlaylistController>()) {
      Get.put(PlaylistController());
    }
    _playlistController = Get.find<PlaylistController>();

    // Add listeners for real-time validation
    _titleController.addListener(_validateForm);
    _descriptionController.addListener(_validateForm);
    _communityTitleController.addListener(_validateForm);
    _communityDescriptionController.addListener(_validateForm);

    // Initialize playlist controller and load public playlists
    _playlistController.fetchPublicPlaylists();
    debugPrint('🎵 Playlist controller initialized with public playlists');
  }

  void _initializeAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _slideInAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );
  }

  void _startInitialAnimations() {
    _mainAnimationController.forward();
  }

  void _validateForm() {
    if (!mounted) return;
    final isValid =
        _titleController.text.trim().length >= 5 &&
        _descriptionController.text.trim().length >= 10;
    _uploadController.setFormValid(isValid);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _communityTitleController.dispose();
    _communityDescriptionController.dispose();
    _communityTagsController.dispose();
    _mainAnimationController.dispose();
    _progressAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Responsive design helpers
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1200;

  double get responsivePadding {
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 16;
  }

  double get maxContentWidth {
    if (isDesktop) return 1200;
    if (isTablet) return 800;
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: ResponsiveBuilder(
          builder: (context, device) {
            return FadeTransition(
              opacity: _fadeInAnimation,
              child: SlideTransition(
                position: _slideInAnimation,
                child: _buildMainContent(device),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(DeviceState device) {
    return Obx(() {
      if (_uploadController.isChannelsLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_uploadController.channels.isEmpty) {
        return Center(
          child: SingleChildScrollView(
            child: _buildNoChannelsCard(),
          ),
        );
      }

      final channel = _uploadController.selectedChannel.value;
      if (channel == null) {
        return const Center(child: CircularProgressIndicator());
      }

      if (channel.status != ChannelStatus.active) {
        return Center(
          child: SingleChildScrollView(
            child: _buildBlockedUploadCard(channel),
          ),
        );
      }

      // For web/desktop/tablet: use horizontal split layout with fixed sections
      if (!device.isMobile) {
        final tokens = context.layoutTokens;
        final isCommunity = widget.uploadType == UploadType.communityPost;
        return Row(
          children: [
            // Left sidebar - fixed width
            Container(
              width: tokens.sidebarWidth > 0 ? tokens.sidebarWidth : 280,
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(
                  right: BorderSide(
                    color: context.colors.divider,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCompactAppBar(true),
                    if (!isCommunity) ...[
                      const SizedBox(height: 20),
                      _buildVerticalStepper(true),
                    ],
                  ],
                ),
              ),
            ),
            // Main content area - flexible
            Expanded(
              child: widget.uploadType == UploadType.video
                  ? _buildVideoUploadFlow(true)
                  : _buildCommunityUploadFlow(true),
            ),
          ],
        );
      }

      // Mobile layout - original vertical layout
      return Column(
        children: [
          _buildEnhancedAppBar(),
          if (widget.uploadType != UploadType.communityPost)
            _buildProgressIndicator(true),
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.layoutTokens.contentMaxWidth,
              ),
              margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
              child: widget.uploadType == UploadType.video
                  ? _buildVideoUploadFlow(true)
                  : _buildCommunityUploadFlow(true),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBlockedUploadCard(Channel channel) {
    Color statusColor;
    IconData icon;
    String title;
    String subtitle;
    var showButton = false;

    if (channel.status == ChannelStatus.underReview) {
      statusColor = context.colors.info;
      icon = Icons.sync_rounded;
      title = 'Branding Under Moderation';
      subtitle =
          'Your channel details are currently under review by Gemini AI. You can publish videos once approved.';
    } else if (channel.status == ChannelStatus.verificationRejected) {
      statusColor = context.colors.error;
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected';
      subtitle =
          channel.moderationReason != null &&
              channel.moderationReason!.isNotEmpty
          ? channel.moderationReason!
          : 'Your channel details were rejected by Gemini AI. Please update your name, description, or tags in customization to re-verify.';
      showButton = true;
    } else if (channel.status == ChannelStatus.verificationPending) {
      statusColor = context.colors.warning;
      icon = Icons.hourglass_empty_rounded;
      title = 'Verification Pending';
      subtitle =
          'Your channel is currently verification pending. You can publish videos once your branding is verified.';
    } else if (channel.status == ChannelStatus.suspended) {
      statusColor = context.colors.error;
      icon = Icons.gavel_rounded;
      title = 'Channel Suspended';
      subtitle =
          'Your channel has been suspended for policy violations. Publishing is disabled.';
    } else {
      statusColor = context.colors.textDisabled;
      icon = Icons.info_outline_rounded;
      title = 'Upload Disabled';
      subtitle = 'Publishing is currently disabled for this channel.';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.colors.divider,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: channel.status == ChannelStatus.underReview
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 40,
                      color: statusColor,
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.themeTypography.headline,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.themeTypography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (showButton) ...[
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                Get.toNamed(
                  '/community-guidelines',
                  arguments: {
                    'fromRejectedChannelId': channel.id,
                    'ownerId': channel.ownerId,
                  },
                );
              },
              icon: const Icon(Icons.description_outlined, size: 20),
              label: Text(
                'Review Community Guidelines',
                style: context.themeTypography.button,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedAppBar() {
    final isCommunity = widget.uploadType == UploadType.communityPost;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsivePadding,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: context.colors.appBarSurface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildBackButton(true),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: context.gradients.primary,
                        borderRadius: context.radius.md,
                      ),
                      child: Icon(
                        isCommunity
                            ? Icons.campaign_rounded
                            : Icons.cloud_upload_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCommunity ? 'Community Post' : 'Upload Content',
                      style: context.themeTypography.headline.copyWith(
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (!isCommunity) ...[
                  const SizedBox(height: 16),
                  _buildChannelSelector(true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoChannelsCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.colors.divider,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 40,
                color: context.colors.error,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Channels Yet',
            style: context.themeTypography.headline.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first channel to start\nuploading amazing content',
            textAlign: TextAlign.center,
            style: context.themeTypography.body.copyWith(
              color: context.colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/channelscreen'),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(
              'Create Channel',
              style: context.themeTypography.button,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== WEB-OPTIMIZED COMPONENTS ==========

  Widget _buildCompactAppBar(bool isDark) {
    final isCommunity = widget.uploadType == UploadType.communityPost;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCommunity ? Icons.campaign_rounded : Icons.cloud_upload_rounded,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isCommunity ? 'Community Post' : 'Upload',
            style: context.themeTypography.headline.copyWith(
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalStepper(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEPS',
            style: context.themeTypography.label.copyWith(
              color: isDark ? AppColors.textTertiary : const Color(0xFF9CA3AF),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          ..._buildStepItems(isDark),
        ],
      ),
    );
  }

  List<Widget> _buildStepItems(bool isDark) {
    final steps = [
      {'icon': Icons.cloud_upload_rounded, 'label': 'Upload Media'},
      {'icon': Icons.edit_rounded, 'label': 'Add Details'},
      {'icon': Icons.tune_rounded, 'label': 'Settings'},
      {'icon': Icons.rocket_launch_rounded, 'label': 'Publish'},
    ];

    return List.generate(steps.length, (index) {
      return Obx(() {
        final isActive = index == _uploadController.uploadStage.value;
        final isCompleted = index < _uploadController.uploadStage.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                _uploadController.setUploadStage(index);

                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );

                HapticFeedback.lightImpact();
              },
              // Disable on desktop/tablet (no PageView there)
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isActive || isCompleted
                            ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              )
                            : null,
                        color: isActive || isCompleted
                            ? null
                            : isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : steps[index]['icon']! as IconData,
                        size: 16,
                        color: isActive || isCompleted
                            ? AppColors.textPrimary
                            : isDark
                            ? AppColors.textTertiary
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[index]['label']! as String,
                        style: context.themeTypography.bodySmall.copyWith(
                          color: isActive
                              ? (isDark
                                    ? AppColors.textPrimary
                                    : const Color(0xFF0F172A))
                              : isCompleted
                              ? (isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary)
                              : (isDark
                                    ? AppColors.textTertiary
                                    : const Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                    Icon(
                      isActive
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.chevron_right_rounded,
                      size: 12,
                      color: isActive
                          ? const Color(0xFF6366F1)
                          : (isDark
                                ? AppColors.textDisabled
                                : const Color(0xFFD1D5DB)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
    });
  }

  Widget _buildChannelSelector(bool isDark) {
    return Obx(() {
      // Show loading state
      if (_uploadController.isChannelsLoading.value) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.textPrimary : const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading channels...',
                style: context.themeTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      // Show error state
      if (_uploadController.channelsError.value.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadController.channelsError.value,
                      style: context.themeTypography.body.copyWith(
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadController.fetchChannelsWithRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Show empty channels state
      if (_uploadController.channels.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 32,
                color: isDark
                    ? AppColors.textTertiary
                    : const Color(0xFFD1D5DB),
              ),
              const SizedBox(height: 12),
              Text(
                'No Channels Yet',
                style: context.themeTypography.title.copyWith(
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a channel to start uploading',
                style: context.themeTypography.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Get.toNamed('/channelscreen'),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Create Channel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Show selected channel as info (non-interactive)
      final channel = _uploadController.selectedChannel.value;
      if (channel == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            UserAvatar(
              radius: 14,
              photoUrl: channel.avatarUrl,
              displayName: channel.channelName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.channelName,
                    style: context.themeTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    channel.status == ChannelStatus.active
                        ? 'Active Channel'
                        : channel.status == ChannelStatus.underReview
                        ? 'Under Review'
                        : channel.status == ChannelStatus.verificationRejected
                        ? 'Rejected'
                        : channel.status == ChannelStatus.verificationPending
                        ? 'Pending Verification'
                        : 'Suspended',
                    style: context.themeTypography.label.copyWith(
                      color: channel.status == ChannelStatus.active
                          ? (isDark ? AppColors.textTertiary : Colors.black45)
                          : channel.status == ChannelStatus.underReview
                          ? const Color(0xFF3B82F6)
                          : channel.status == ChannelStatus.verificationRejected
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPublishPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.visibility_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Preview',
                style: context.themeTypography.headline.copyWith(
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 160,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Obx(() {
                    final image = _uploadController.pickedImage.value;
                    if (image != null) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: kIsWeb
                                ? MemoryImage(image.bytes!) as ImageProvider
                                : FileImage(io.File(image.path!)),
                            fit: BoxFit.cover,
                          ),
                          // Duration badge
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgPage.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '00:00',
                                style: context.themeTypography.label.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: isDark
                            ? AppColors.textPrimary.withValues(alpha: 0.2)
                            : const Color(0xFFD1D5DB),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 16),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.isNotEmpty
                          ? _titleController.text
                          : 'Untitled Video',
                      style: context.themeTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF0F172A),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Obx(() {
                      final channel = _uploadController.selectedChannel.value;
                      return Row(
                        children: [
                          if (channel != null) ...[
                            CachedNetworkImage(
                              imageUrl: channel.avatarUrl,
                              imageBuilder: (context, imageProvider) =>
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundImage: imageProvider,
                                  ),
                              placeholder: (context, url) => const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.textSecondary,
                                child: Icon(
                                  Icons.person,
                                  size: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.textSecondary,
                                    child: Icon(
                                      Icons.person,
                                      size: 10,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              channel?.channelName ?? 'No channel',
                              style: context.themeTypography.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),
                    Obx(() {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _getVisibilityColor(
                            _uploadController.selectedVisibility.value,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getVisibilityIcon(
                                _uploadController.selectedVisibility.value,
                              ),
                              size: 14,
                              color: _getVisibilityColor(
                                _uploadController.selectedVisibility.value,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _uploadController.selectedVisibility.value,
                              style: context.themeTypography.bodySmall.copyWith(
                                color: _getVisibilityColor(
                                  _uploadController.selectedVisibility.value,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Obx(() {
                      final playlistId =
                          _uploadController.selectedPlaylist.value;
                      if (playlistId.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.playlist_play_rounded,
                              size: 16,
                              color: Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _getPlaylistName(playlistId),
                                style: context.themeTypography.bodySmall
                                    .copyWith(
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPlaylistName(String id) {
    if (id.isEmpty) return 'None';
    final playlist = _playlistController.publicPlaylists.firstWhereOrNull(
      (p) => p.id == id,
    );
    return playlist?.playlistName ?? 'Selected Playlist';
  }

  Color _getVisibilityColor(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return const Color(0xFF10B981);
      case 'unlisted':
        return const Color(0xFFF59E0B);
      case 'private':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ========== SEPARATE VIDEO UPLOAD COMPONENTS ==========

  // ========== SEPARATE COMMUNITY POST COMPONENTS ==========

  Widget _buildFinalPublishSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Publish',
                      style: context.themeTypography.headline.copyWith(
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your video will be processed and made available to viewers',
                      style: context.themeTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textPrimary.withValues(alpha: 0.75)
                            : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPublishChecklist(isDark),
          const SizedBox(height: 20),
          Obx(
            () => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thumbnail Status: ${_uploadController.finalstatus.value}',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textPrimary.withValues(alpha: 0.8)
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildValidationSummaryRow(
                          label: 'Title',
                          status: _uploadController.titleValidationStatus.value,
                          reason: _uploadController.titleValidationReason.value,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildValidationSummaryRow(
                          label: 'Description',
                          status: _uploadController
                              .descriptionValidationStatus
                              .value,
                          reason: _uploadController
                              .descriptionValidationReason
                              .value,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishChecklist(bool isDark) {
    return Obx(() {
      final isUploading = _uploadController.isUploading.value;
      final videoProgress = _uploadController.videoUploadProgress.value;
      final videoUrl = _uploadController.videoUrl.value;

      final checks = [
        (
          isUploading
              ? 'Uploading video... (${(videoProgress * 100).toInt()}%)'
              : (videoUrl.isNotEmpty ? 'Video uploaded' : 'Video not uploaded'),
          videoUrl.isNotEmpty,
          Icons.videocam_rounded,
          isUploading,
        ),
        (
          _uploadController.finalstatus.value == 'APPROVED'
              ? 'Thumbnail approved'
              : (_uploadController.finalstatus.value == 'REJECTED'
                    ? 'Thumbnail rejected'
                    : (_uploadController.finalstatus.value == 'FLAGGED'
                          ? 'Thumbnail pending admin review...'
                          : (_uploadController.finalstatus.value == 'PENDING'
                                ? 'Verifying thumbnail...'
                                : 'Thumbnail added'))),
          _uploadController.finalstatus.value == 'APPROVED',
          _uploadController.finalstatus.value == 'REJECTED'
              ? Icons.error_outline_rounded
              : (_uploadController.finalstatus.value == 'FLAGGED'
                    ? Icons.hourglass_top_rounded
                    : Icons.image_rounded),
          _uploadController.finalstatus.value == 'PENDING' ||
              _uploadController.finalstatus.value == 'FLAGGED',
        ),
        (
          'Title (min. 5 chars)',
          _titleController.text.trim().length >= 5,
          Icons.title_rounded,
          false,
        ),
      ];

      return Column(
        children: checks.map((check) {
          final (label, isComplete, icon, isProcessing) = check;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
                width: isComplete ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF10B981)
                        : isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isComplete ? Icons.check_rounded : icon,
                    size: 14,
                    color: isComplete
                        ? AppColors.textPrimary
                        : isDark
                        ? AppColors.textPrimary.withValues(alpha: 0.4)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.themeTypography.body.copyWith(
                          color: isComplete
                              ? (isDark
                                    ? AppColors.textPrimary
                                    : const Color(0xFF111827))
                              : (isProcessing && isDark
                                    ? AppColors.textPrimary
                                    : isDark
                                    ? AppColors.textPrimary.withValues(
                                        alpha: 0.6,
                                      )
                                    : const Color(0xFF6B7280)),
                          fontWeight: isComplete
                              ? FontWeight.w500
                              : FontWeight.w500,
                        ),
                      ),
                      if (isProcessing && !isComplete) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: videoProgress,
                            backgroundColor: isDark
                                ? AppColors.textPrimary.withValues(alpha: 0.1)
                                : AppColors.bgPage.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildPublishButton(bool isDark) {
    return Obx(() {
      final canPublish = _canPublishVideo();
      final isUploading = _uploadController.isUploading.value;

      if (isUploading) {
        return _buildUploadingButton(isDark);
      }

      // Check if we're waiting for the backend to sync URLs
      final isVideoUrlEmpty = _uploadController.videoUrl.value.isEmpty;
      final isThumbnailUrlEmpty = _uploadController.thumbnailUrl.value.isEmpty;

      // Only show finalizing if we've picked a file but don't have the URL and the upload task is done
      if (isVideoUrlEmpty &&
          _uploadController.pickedVideo.value != null &&
          !isUploading) {
        return _buildProcessingButton(isDark, 'Finalizing Video...');
      }

      if (isThumbnailUrlEmpty &&
          _uploadController.pickedImage.value != null &&
          !isUploading) {
        return _buildProcessingButton(isDark, 'Finalizing Thumbnail...');
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: canPublish
              ? LinearGradient(
                  colors: _uploadController.isScheduled.value
                      ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                )
              : null,
          color: canPublish
              ? null
              : isDark
              ? const Color(0xFF21262D)
              : const Color(0xFFE5E7EB),
          boxShadow: canPublish
              ? [
                  BoxShadow(
                    color:
                        (_uploadController.isScheduled.value
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF6366F1))
                            .withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: canPublish ? _handleVideoUpload : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _uploadController.isScheduled.value
                        ? Icons.schedule_rounded
                        : Icons.cloud_upload_rounded,
                    size: 22,
                    color: canPublish
                        ? AppColors.textPrimary
                        : isDark
                        ? AppColors.textPrimary.withValues(alpha: 0.3)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _uploadController.isScheduled.value
                        ? 'Schedule Upload'
                        : 'Publish Now',
                    style: context.themeTypography.title.copyWith(
                      color: canPublish
                          ? AppColors.textPrimary
                          : isDark
                          ? AppColors.textPrimary.withValues(alpha: 0.3)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSaveDraftButton(bool isDark) {
    return Obx(() {
      final isUploading = _uploadController.isUploading.value;
      final hasVideo = _uploadController.videoUrl.value.isNotEmpty;
      final hasTitle = _titleController.text.trim().isNotEmpty;
      final canSaveDraft = hasVideo && hasTitle && !isUploading;

      return Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark ? const Color(0xFF1F2937) : AppColors.textPrimary,
          border: Border.all(
            color: canSaveDraft
                ? (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB))
                : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: canSaveDraft ? () => _handleVideoUpload(isDraft: true) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_outline_rounded,
                    size: 20,
                    color: canSaveDraft
                        ? (isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF374151))
                        : (isDark
                            ? AppColors.textPrimary.withValues(alpha: 0.3)
                            : const Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Save Draft',
                    style: context.themeTypography.button.copyWith(
                      color: canSaveDraft
                          ? (isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF374151))
                          : (isDark
                              ? AppColors.textPrimary.withValues(alpha: 0.3)
                              : const Color(0xFF9CA3AF)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPublishActionRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSaveDraftButton(isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildPublishButton(isDark),
        ),
      ],
    );
  }

  Widget _buildProcessingButton(bool isDark, String message) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            message,
            style: context.themeTypography.body.copyWith(
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingButton(bool isDark) {
    return Obx(() {
      final progress = _uploadController.uploadProgress.value;
      final progressText = '${(progress * 100).toInt()}%';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.textPrimary,
                      ),
                      value: progress,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uploading...',
                        style: context.themeTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Processing your video',
                        style: context.themeTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  progressText,
                  style: context.themeTypography.headline.copyWith(
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF3F4F6),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStepNavigation({
    required bool isDark,
    bool showBack = false,
    String? nextLabel,
    Widget? customAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bgPage.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: _goToPreviousStep,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: Text(
                    'Back',
                    style: context.themeTypography.button,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF374151),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF1F2937)
                        : AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: showBack ? 2 : 1,
            child:
                customAction ??
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _handleNextStep,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      nextLabel ?? 'Continue',
                      style: context.themeTypography.button.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.textPrimary,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _handleNextStep() {
    debugPrint(
      '--- Navigating to next step from step ${_uploadController.uploadStage.value} ---',
    );
    var canProceed = true;
    var errorMessage = '';

    switch (_uploadController.uploadStage.value) {
      case 0:
        debugPrint('Validating Step 1: Media Selection');
        if (_uploadController.pickedVideo.value == null) {
          errorMessage += 'Please select a video.\n';
          canProceed = false;
        }
        if (_uploadController.pickedImage.value == null) {
          errorMessage += 'Please select a thumbnail.\n';
          canProceed = false;
        }
        if (_uploadController.finalstatus.value == 'REJECTED') {
          errorMessage +=
              'Thumbnail was rejected. Please upload a different one.';
          canProceed = false;
        }
        debugPrint(
          "Step 1 validation result: canProceed=$canProceed, errorMessage='$errorMessage'",
        );
      case 1:
        debugPrint('Validating Step 2: Basic Info');
        if (_videoDetailsFormKey.currentState != null &&
            !_videoDetailsFormKey.currentState!.validate()) {
          canProceed = false;
          errorMessage = 'Please fill in all required fields correctly.';
        } else if (_uploadController.selectedCategory.value.isEmpty) {
          canProceed = false;
          errorMessage = 'Please select a category.';
        }
        debugPrint(
          "Step 2 validation result: canProceed=$canProceed, errorMessage='$errorMessage'",
        );
      case 2:
        debugPrint('Validating Step 3: Advanced Settings');
        if (!_uploadController.isFactCheckSourcesValid) {
          canProceed = false;
          errorMessage =
              'Please provide at least one source link for Fact-Checking.';
        }
        debugPrint(
          "Step 3 validation result: canProceed=$canProceed, errorMessage='$errorMessage'",
        );
      case 3:
        debugPrint('Step 4: No validation needed for final step');
      // For other steps, assume can proceed
    }

    if (canProceed) {
      debugPrint('Proceeding to next step.');
      _goToNextStep();
    } else {
      debugPrint('Cannot proceed. Showing error snackbar.');
      Get.snackbar(
        'Cannot Proceed',
        errorMessage.trim(),
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      HapticFeedback.heavyImpact();
    }
  }

  // Community Upload Methods
  Widget _buildCommunityMediaSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media',
          style: context.themeTypography.title.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildCommunityImageUpload(isDark),
      ],
    );
  }

  Widget _buildCommunityImageUpload(bool isDark) {
    return Obx(() {
      final hasImage = _uploadController.pickedCommunityImage.value != null;
      final isUploading = _uploadController.isUploading.value;

      return InkWell(
        onTap: isUploading
            ? null
            : () {
                _uploadController.pickImage(forCommunity: true);
                HapticFeedback.mediumImpact();
              },
        child: Container(
          height: isMobile ? 180 : 200,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasImage
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                  : isDark
                  ? const Color(0xFF30363D)
                  : const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
          child: hasImage
              ? _buildCommunityImagePreview(isDark)
              : _buildCommunityImagePlaceholder(isDark),
        ),
      );
    });
  }

  Widget _buildCommunityImagePreview(bool isDark) {
    return Obx(() {
      final file = _uploadController.pickedCommunityImage.value!;
      final isUploaded = _uploadController.communityImageUrl.value.isNotEmpty;

      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: kIsWeb
                      ? MemoryImage(file.bytes!) as ImageProvider
                      : FileImage(io.File(file.path!)),
                ),
              ),
            ),
          ),
          if (isUploaded)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Uploaded',
                      style: context.themeTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildCommunityImagePlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.image_rounded,
            size: 48,
            color: Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Upload Image',
          style: context.themeTypography.headline.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add an image to your community post',
          style: context.themeTypography.body.copyWith(
            color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'JPEG, PNG, GIF • Max 20MB',
          style: context.themeTypography.bodySmall.copyWith(
            color: isDark
                ? AppColors.textPrimary.withValues(alpha: 0.4)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityDetailsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Post Details',
          style: context.themeTypography.title.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildEnhancedTextField(
          controller: _communityTitleController,
          label: 'Title',
          hint: "What's happening?",
          icon: Icons.campaign_rounded,
          isDark: isDark,
          maxLength: 100,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Title is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildEnhancedTextField(
          controller: _communityDescriptionController,
          label: 'Description',
          hint: 'Share more details with your community',
          icon: Icons.description_rounded,
          isDark: isDark,
          maxLines: 4,
          maxLength: 2000,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Description is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildEnhancedTextField(
          controller: _communityTagsController,
          label: 'Tags (Max 5)',
          hint: 'Add tags separated by commas (max 5 tags)',
          icon: Icons.tag_rounded,
          isDark: isDark,
          maxLength: 200,
        ),
      ],
    );
  }

  Widget _buildCommunityPublishSection(bool isDark) {
    return Obx(() {
      final isUploading = _uploadController.isUploading.value;

      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _handleCommunityUpload,
          icon: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.publish_rounded, size: 20),
          label: Text(
            isUploading ? 'Publishing...' : 'Publish Post',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
      );
    });
  }

  // Helper Methods

  bool _canPublishVideo() {
    // Access Rx variables to ensure Obx dependency tracking
    final videoUrl = _uploadController.videoUrl.value;
    final thumbnailUrl = _uploadController.thumbnailUrl.value;
    final pickedImage = _uploadController.pickedImage.value;
    final selectedChannel = _uploadController.selectedChannel.value;
    final selectedCategory = _uploadController.selectedCategory.value;
    final isUploading = _uploadController.isUploading.value;
    final finalStatus = _uploadController.finalstatus.value.toUpperCase();

    final hasVideo = videoUrl.isNotEmpty;
    final hasThumbnail = thumbnailUrl.isNotEmpty || pickedImage != null;
    final hasChannel = selectedChannel != null;
    final isChannelActive =
        selectedChannel != null &&
        selectedChannel.status == ChannelStatus.active;
    final hasValidTitle = _titleController.text.trim().length >= 5;
    final hasValidDesc = _descriptionController.text.trim().length >= 10;
    final hasCategory = selectedCategory.isNotEmpty;
    final isNotUploading = !isUploading;
    final isThumbnailApproved = finalStatus == 'APPROVED';

    final result =
        hasVideo &&
        hasThumbnail &&
        hasChannel &&
        isChannelActive &&
        hasValidTitle &&
        hasValidDesc &&
        hasCategory &&
        isNotUploading &&
        isThumbnailApproved;

    if (!result) {
      debugPrint('🚫 [_canPublishVideo] Validation failed:');
      if (!hasVideo) {
        debugPrint('   - Video URL is empty');
      }
      if (!hasThumbnail) {
        debugPrint('   - Thumbnail missing');
      }
      if (!hasChannel) {
        debugPrint('   - Channel not selected');
      }
      if (!hasValidTitle) {
        debugPrint('   - Title too short (<5): "${_titleController.text}"');
      }
      if (!hasValidDesc) {
        debugPrint('   - Description too short (<10)');
      }
      if (!hasCategory) {
        debugPrint('   - Category not selected');
      }
      if (!isNotUploading) {
        debugPrint('   - Still uploading');
      }
      if (!isThumbnailApproved) {
        debugPrint('   - Thumbnail status: $finalStatus');
      }
    }

    return result;
  }

  Widget _buildModerationStatusChip() {
    return Obx(() {
      final status = _uploadController.finalstatus.value;
      final reason = _uploadController.finalstatusReason.value;

      Color color;
      IconData icon;
      String label;

      switch (status) {
        case 'APPROVED':
          color = const Color(0xFF10B981);
          icon = Icons.check_circle_rounded;
          label = 'Approved';
        case 'REJECTED':
          color = const Color(0xFFEF4444);
          icon = Icons.error_rounded;
          label = 'Rejected';
        case 'FLAGGED':
          color = const Color(0xFFF59E0B);
          icon = Icons.warning_rounded;
          label = 'Review Needed';
        case 'PENDING':
          color = const Color(0xFF3B82F6);
          icon = Icons.sync_rounded;
          label = 'Verifying...';
        default:
          return const SizedBox.shrink();
      }

      final chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'PENDING')
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textPrimary,
                  ),
                ),
              )
            else
              Icon(icon, size: 14, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.themeTypography.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

      if (status == 'REJECTED') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxWidth: 160),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgPage.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Text(
                reason,
                style: context.themeTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }

      return chip;
    });
  }

  Widget _buildValidationSummaryRow({
    required String label,
    required String status,
    required String reason,
    required bool isDark,
  }) {
    final approved = status == 'APPROVED';
    final rejected = status == 'REJECTED';
    final pending = status == 'PENDING';

    final color = approved
        ? const Color(0xFF10B981)
        : rejected
        ? const Color(0xFFEF4444)
        : const Color(0xFF3B82F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved
                ? Icons.check_circle_rounded
                : rejected
                ? Icons.error_outline_rounded
                : Icons.hourglass_top_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label validation',
                  style: context.themeTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : (pending
                            ? 'Validation is in progress...'
                            : 'No validation details available.'),
                  style: context.themeTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textPrimary.withValues(alpha: 0.75)
                        : const Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canPublishCommunity() {
    return (_uploadController.pickedCommunityImage.value != null ||
            _uploadController.communityImageUrl.value.isNotEmpty) &&
        _uploadController.selectedChannel.value != null &&
        _communityTitleController.text.trim().isNotEmpty &&
        _communityDescriptionController.text.trim().isNotEmpty &&
        !_uploadController.isUploading.value &&
        !_uploadController.isCommunityPostUploading.value;
  }

  void _goToNextStep() {
    if (_uploadController.uploadStage.value < _totalSteps - 1) {
      final nextStage = _uploadController.uploadStage.value + 1;
      if (nextStage == 2) {
        _playlistController.refreshPlaylistsTick();
        _playlistController.refreshPublicPlaylists();
        _uploadController.fetchAvailableTopics();
      } else if (nextStage == 3) {
        _uploadController.refreshTitleDescriptionValidation(
          _titleController.text,
          _descriptionController.text,
        );
      }
      _uploadController.setUploadStage(nextStage);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _goToPreviousStep() {
    if (_uploadController.uploadStage.value > 0) {
      _uploadController.setUploadStage(_uploadController.uploadStage.value - 1);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _handleBackNavigation() {
    if (_uploadController.uploadStage.value > 0) {
      _goToPreviousStep();
    } else {
      _showExitConfirmation();
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard upload?'),
        content: const Text('Your progress will be lost if you leave now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectScheduleDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _uploadController.scheduledDate.value.isAfter(DateTime.now())
          ? _uploadController.scheduledDate.value
          : DateTime.now().add(const Duration(minutes: 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _uploadController.scheduledDate.value,
        ),
      );

      if (pickedTime != null) {
        final finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (finalDateTime.isBefore(DateTime.now())) {
          Get.snackbar(
            'Invalid Date',
            'Scheduled date cannot be in the past',
            backgroundColor: const Color(0xFFEF4444),
            colorText: AppColors.textPrimary,
          );
          _uploadController.isScheduled.value = false;
        } else {
          _uploadController.scheduledDate.value = finalDateTime;
        }
      }
    }
  }

  // ========== VIDEO/MEDIA PICKER METHODS ==========

  Future<void> _handleVideoUpload({bool isDraft = false}) async {
    debugPrint('--- Step 4: Publish Review (isDraft: $isDraft) ---');
    debugPrint('Initiating video upload process...');

    if (!isDraft) {
      // 1️⃣ Validation: Required fields
      final selectedChannel = _uploadController.selectedChannel.value;
      if (selectedChannel != null &&
          selectedChannel.status != ChannelStatus.active) {
        var message = 'Your channel is not active.';
        if (selectedChannel.status == ChannelStatus.underReview) {
          message =
              'Your channel details are currently under review by Gemini AI. You can publish videos once approved.';
        } else if (selectedChannel.status == ChannelStatus.verificationRejected) {
          message =
              selectedChannel.moderationReason != null &&
                  selectedChannel.moderationReason!.isNotEmpty
              ? 'Branding Rejected: ${selectedChannel.moderationReason!}'
              : 'Your channel details were rejected by Gemini AI. Please update your channel details in customization to re-verify.';
        } else if (selectedChannel.status == ChannelStatus.verificationPending) {
          message =
              'Your channel is currently verification pending. You can publish videos once your branding is verified.';
        } else if (selectedChannel.status == ChannelStatus.suspended) {
          message = 'Your channel is suspended. Publishing is disabled.';
        }
        Get.snackbar(
          'Verification Required',
          message,
          backgroundColor: const Color(0xFFEF4444),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      final canPublish = _canPublishVideo();
      if (!canPublish) {
        var errorMessage = 'Cannot publish. Validation checks:\n';
        if (_uploadController.videoUrl.value.isEmpty) {
          errorMessage += '- Video not uploaded yet.\n';
        }
        if (_uploadController.thumbnailUrl.value.isEmpty) {
          errorMessage += '- Thumbnail not uploaded yet.\n';
        }
        if (_titleController.text.trim().isEmpty) {
          errorMessage += '- Title is required.\n';
        }
        if (_titleController.text.length < 5) {
          errorMessage += '- Title must be at least 5 characters long.\n';
        }

        if (_uploadController.selectedCategory.value.isEmpty) {
          errorMessage += '- Category is required.\n';
        }
        if (_uploadController.selectedChannel.value == null) {
          errorMessage += '- Channel not selected.\n';
        }
        if (_uploadController.isUploading.value) {
          errorMessage += '- An upload is already in progress.\n';
        }

        Get.snackbar(
          'Cannot Publish',
          errorMessage.trim(),
          backgroundColor: const Color(0xFFEF4444),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // 2️⃣ Thumbnail moderation check
      final status = _uploadController.finalstatus.value;
      if (status == 'REJECTED') {
        Get.snackbar(
          'Thumbnail Rejected',
          'You cannot publish because the thumbnail was rejected: ${_uploadController.finalstatusReason.value}',
          backgroundColor: const Color(0xFFEF4444),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
        );
        return;
      }
      if (status != 'APPROVED') {
        Get.snackbar(
          'Verification Pending',
          'Your thumbnail is still being verified. Please wait a moment.',
          backgroundColor: const Color(0xFF3B82F6),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
        );
        return;
      }
    }

    // 4️⃣ Ensure channel is selected
    if (_uploadController.selectedChannel.value == null) {
      Get.snackbar(
        'Channel Required',
        'Please select a channel to publish to',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      _uploadController.isProcessing.value = true;
      _uploadController.processingMessage.value =
          isDraft ? 'Saving draft...' : 'Publishing video...';

      final channel = _uploadController.selectedChannel.value;
      if (channel == null) {
        throw Exception('Channel selection failed - please try again');
      }

      final rawTags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (rawTags.length > 5) {
        throw Exception('Maximum 5 tags allowed (currently ${rawTags.length})');
      }

      final tags = rawTags.take(5).toList();
      final selectedLanguages = _uploadController.aiTranslationLanguages
          .toList();

      // Upload video
      await _uploadController.uploadVideo(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        channel.channelName,
        channel.channelId,
        channel.avatarUrl,
        tags,
        selectedLanguages,
        isDraft: isDraft,
      );

      HapticFeedback.mediumImpact();
      Get.snackbar(
        isDraft ? 'Draft Saved' : 'Upload Started',
        isDraft
            ? 'Your video was saved as a draft successfully.'
            : 'Your video is being processed and will be available soon',
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
      );
      Get.offAllNamed('/studio');
    } catch (e) {
      var errorMessage = 'Failed to upload video. Please try again.';
      if (e is FirebaseException) {
        errorMessage = 'Firebase error: ${e.message}';
      } else if (e is io.IOException) {
        errorMessage = 'Network error: Check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please check your input.';
      }
      Get.snackbar(
        'Upload Error',
        errorMessage,
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      debugPrint('Video upload error: $e');
    } finally {
      _uploadController.isProcessing.value = false;
      _uploadController.processingMessage.value = '';
    }
  }

  Future<void> _handleCommunityUpload() async {
    if (!_canPublishCommunity()) {
      var errorMessage = '';
      if (_uploadController.communityImageUrl.value.isEmpty) {
        errorMessage += 'Image not added.\n';
      }
      if (_communityTitleController.text.trim().isEmpty) {
        errorMessage += 'Title is required.\n';
      }
      if (_communityDescriptionController.text.trim().isEmpty) {
        errorMessage += 'Description is required.\n';
      }
      if (_uploadController.selectedChannel.value == null) {
        errorMessage += 'Please select a channel.';
      }
      Get.snackbar(
        'Cannot Publish',
        errorMessage.trim(),
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      return;
    }

    if (!_communityDetailsFormKey.currentState!.validate()) {
      Get.snackbar(
        'Form Error',
        'Please fill in all required fields correctly',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      return;
    }

    if (_uploadController.selectedChannel.value == null) {
      Get.snackbar(
        'Channel Required',
        'Please select a channel to publish to',
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      return;
    }

    try {
      _uploadController.isProcessing.value = true;
      _uploadController.processingMessage.value =
          'Publishing community post...';

      final rawCommunityTags = _communityTagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (rawCommunityTags.length > 5) {
        throw Exception('Maximum 5 tags allowed (currently ${rawCommunityTags.length})');
      }

      final tags = rawCommunityTags.take(5).toList();

      await _uploadController.uploadCommunityPost(
        _communityTitleController.text.trim(),
        _communityDescriptionController.text.trim(),
        _uploadController.selectedChannel.value!.channelName,
        _uploadController.selectedChannel.value!.channelId,
        _uploadController.selectedChannel.value!.avatarUrl,
        tags,
      );

      HapticFeedback.mediumImpact();

      // Show success feedback
      Get.snackbar(
        'Post Published',
        'Your community post has been published successfully',
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
      );
      Get.offAllNamed('/studio');
    } catch (e) {
      // Enhanced error handling
      var errorMessage = 'Failed to publish community post. Please try again.';
      if (e is FirebaseException) {
        errorMessage = 'Firebase error: ${e.message}';
      } else if (e is io.IOException) {
        errorMessage = 'Network error: Check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please check your input.';
      }
      Get.snackbar(
        'Publish Error',
        errorMessage,
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
      );
      debugPrint('Community post upload error: $e');
    } finally {
      _uploadController.isProcessing.value = false;
      _uploadController.processingMessage.value = '';
    }
  }

  // Utility Methods
  IconData _getVisibilityIcon(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return Icons.public_rounded;
      case 'private':
        return Icons.lock_rounded;
      case 'members':
        return Icons.group_rounded;
      case 'subscribersonly':
        return Icons.people_alt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getVisibilityDescription(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return 'Anyone can search for and view';
      case 'private':
        return 'Only you can view';
      case 'members':
        return 'Only channel members can view';
      case 'subscribersonly':
        return 'Only your subscribers can view';
      default:
        return 'Select visibility option';
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      IntProperty('currentStep', _uploadController.uploadStage.value),
    );
    properties.add(IntProperty('totalSteps', _totalSteps));
    properties.add(
      FlagProperty('isProcessing', value: _uploadController.isProcessing.value),
    );
    properties.add(
      StringProperty(
        'processingMessage',
        _uploadController.processingMessage.value,
      ),
    );
    properties.add(
      DoubleProperty('overallProgress', _uploadController.overallProgress),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _handleBackNavigation,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Icon(
            Icons.arrow_back,
            size: 20,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsivePadding,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        children: [
          Obx(
            () => Row(
              children: List.generate(_totalSteps, (index) {
                final isActive = index == _uploadController.uploadStage.value;
                final isCompleted = index < _uploadController.uploadStage.value;
                final stepNames = ['Media', 'Details', 'Settings', 'Publish'];

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isCompleted || isActive
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF8B5CF6),
                                        ],
                                      )
                                    : null,
                                color: isCompleted || isActive
                                    ? null
                                    : isDark
                                    ? const Color(0xFF21262D)
                                    : const Color(0xFFE5E7EB),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF6366F1,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_rounded
                                    : _getStepIcon(index),
                                size: 18,
                                color: isCompleted || isActive
                                    ? AppColors.textPrimary
                                    : isDark
                                    ? AppColors.textPrimary.withValues(
                                        alpha: 0.3,
                                      )
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stepNames[index],
                              style: context.themeTypography.bodySmall.copyWith(
                                color: isActive
                                    ? (isDark
                                          ? AppColors.textPrimary
                                          : const Color(0xFF0F172A))
                                    : isCompleted
                                    ? (isDark
                                          ? AppColors.textSecondary
                                          : AppColors.textSecondary)
                                    : (isDark
                                          ? AppColors.textPrimary.withValues(
                                              alpha: 0.3,
                                            )
                                          : const Color(0xFF9CA3AF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < _totalSteps - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              color: isCompleted
                                  ? const Color(0xFF6366F1)
                                  : isDark
                                  ? const Color(0xFF21262D)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(int step) {
    switch (step) {
      case 0:
        return Icons.cloud_upload_rounded;
      case 1:
        return Icons.edit_rounded;
      case 2:
        return Icons.tune_rounded;
      case 3:
        return Icons.rocket_launch_rounded;
      default:
        return Icons.circle;
    }
  }

  Widget _buildVideoUploadFlow(bool isDark) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: _uploadController.setUploadStage,
      children: [
        _buildStep1MediaSelection(isDark),
        _buildStep2BasicInfo(isDark),
        _buildStep3AdvancedSettings(isDark),
        _buildStep4PublishReview(isDark),
      ],
    );
  }

  Widget _buildCommunityUploadFlow(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(responsivePadding),
      child: Form(
        key: _communityDetailsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommunityMediaSection(isDark),
            const SizedBox(height: 24),
            _buildCommunityDetailsSection(isDark),
            const SizedBox(height: 32),
            _buildCommunityPublishSection(isDark),
          ],
        ),
      ),
    );
  }

  // Step 1: Media Selection
  Widget _buildStep1MediaSelection(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            isDark: isDark,
            title: 'Upload Your Media',
            subtitle: 'Select video file and thumbnail',
            icon: Icons.cloud_upload_rounded,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 14),
          _buildEnhancedThumbnailUpload(isDark),
          const SizedBox(height: 32),
          _buildEnhancedVideoUpload(isDark),
          const SizedBox(height: 24),
          const SizedBox(height: 32),
          _buildStepNavigation(isDark: isDark, nextLabel: 'Add Details'),
        ],
      ),
    );
  }

  // Step 2: Basic Information
  Widget _buildStep2BasicInfo(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(responsivePadding),
      child: Form(
        key: _videoDetailsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              isDark: isDark,
              title: 'Video Details',
              subtitle: 'Tell viewers about your content',
              icon: Icons.edit_rounded,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 32),
            _buildEnhancedTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Add a title that describes your video',
              icon: Icons.title_rounded,
              isDark: isDark,
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                if (value.length < 5) {
                  return 'Title must be at least 5 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildEnhancedTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Tell viewers about your video',
              icon: Icons.description_rounded,
              isDark: isDark,
              maxLines: 6,
              maxLength: 5000,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description is required';
                }
                if (value.length < 10) {
                  return 'Description must be at least 10 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildVideoCategoryDropdown(isDark),
            const SizedBox(height: 20),
            _buildEnhancedTextField(
              controller: _tagsController,
              label: 'Tags (Max 5)',
              hint: 'Add tags separated by commas (max 5 tags)',
              icon: Icons.tag_rounded,
              isDark: isDark,
              maxLength: 500,
            ),
            const SizedBox(height: 32),
            _buildStepNavigation(
              isDark: isDark,
              nextLabel: 'Advanced Settings',
              showBack: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCategoryDropdown(bool isDark) {
    return Obx(() {
      final currentCategory = _uploadController.selectedCategory.value;
      final categories = _uploadController.videoCategories;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Category',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE6EDF3)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: categories.contains(currentCategory)
                ? currentCategory
                : categories.first,
            decoration: InputDecoration(
              hintText: 'Select video category',
              prefixIcon: const Icon(
                Icons.category_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF161B22) : AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            dropdownColor: isDark
                ? const Color(0xFF161B22)
                : AppColors.bgSurface,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            items: categories.map((cat) {
              final isNoFactCheck = !_uploadController
                  .isFactCheckNeededForCategory(cat);
              return DropdownMenuItem<String>(
                value: cat,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (isNoFactCheck) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B7280).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF6B7280,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'No Fact-Check',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _uploadController.selectCategory(value);
                HapticFeedback.lightImpact();
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a category';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          Obx(() {
            final cat = _uploadController.selectedCategory.value;
            final isNoFactCheck = !_uploadController
                .isFactCheckNeededForCategory(cat);
            if (isNoFactCheck) {
              return Text(
                'Note: Fact-checking is not needed for $cat content.',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      );
    });
  }

  // Step 3: Advanced Settings
  Widget _buildStep3AdvancedSettings(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            isDark: isDark,
            title: 'Advanced Settings',
            subtitle: 'Configure visibility and additional options',
            icon: Icons.tune_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          // ── AI Features Selection ──
          AIFeaturesSelector(
            transcriptEnabled: _uploadController.aiTranscriptEnabled,
            generateSubtitles: _uploadController.aiGenerateSubtitles,
            generateDubbing: _uploadController.aiGenerateDubbing,
            diarizationEnabled: _uploadController.aiDiarizationEnabled,
            summaryEnabled: _uploadController.aiSummaryEnabled,
            autoChaptersEnabled: _uploadController.aiChaptersEnabled,
            selectedLanguages: _uploadController.aiTranslationLanguages,
            ttsEnabled: _uploadController.aiTTSEnabled,
            ttsVoiceType: _uploadController.aiTTSVoiceType,
            factCheckEnabled: _uploadController.aiFactCheckEnabled,
            voiceSample: _uploadController.voiceSampleFile,
            selectedCategory: _uploadController.selectedCategory,
            providedSources: _uploadController.providedSources,
            onAddSource: _uploadController.addProvidedSource,
            onRemoveSource: _uploadController.removeProvidedSource,
            isPremiumUser:
                _uploadController.selectedChannel.value?.monetizationTier ==
                    MonetizationTier.premium ||
                _uploadController.selectedChannel.value?.monetizationTier ==
                    MonetizationTier.pro,
            onPickVoiceSample: _uploadController.pickVoiceSample,
          ),
          const SizedBox(height: 32),
          _buildVisibilitySettings(isDark),
          const SizedBox(height: 24),
          _buildAudienceSettings(isDark),
          const SizedBox(height: 24),
          _buildScheduleSettings(isDark),
          const SizedBox(height: 24),
          _buildPlaylistSelection(isDark),
          const SizedBox(height: 24),
          _buildTopicSelection(isDark),
          const SizedBox(height: 32),
          _buildStepNavigation(
            isDark: isDark,
            nextLabel: 'Review & Publish',
            showBack: true,
          ),
        ],
      ),
    );
  }

  // Step 4: Review & Publish
  Widget _buildStep4PublishReview(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            isDark: isDark,
            title: 'Review & Publish',
            subtitle: 'Final check before publishing your video',
            icon: Icons.preview_rounded,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 32),
          _buildChannelSelectionSection(isDark),
          const SizedBox(height: 24),
          _buildPublishPreview(isDark),
          const SizedBox(height: 32),
          _buildFinalPublishSection(isDark),
          const SizedBox(height: 24),
          _buildStepNavigation(
            isDark: isDark,
            showBack: true,
            customAction: _buildPublishActionRow(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.08),
                    color.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  width: 2,
                  color: color.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: isDark
                        ? AppColors.bgPage.withValues(alpha: 0.3)
                        : AppColors.textPrimary,
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 32, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.themeTypography.headline.copyWith(
                            color: isDark
                                ? AppColors.textPrimary
                                : const Color(0xFF111827),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: context.themeTypography.body.copyWith(
                            color: isDark
                                ? AppColors.textSecondary
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Step ${_uploadController.uploadStage.value + 1}/$_totalSteps',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedVideoUpload(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                size: 20,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video File',
                    style: context.themeTypography.headline.copyWith(
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select your video file to upload',
                    style: context.themeTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(() {
          final hasVideo = _uploadController.pickedVideo.value != null;
          final isUploading = _uploadController.isUploading.value;

          return InkWell(
            onTap: isUploading
                ? null
                : () {
                    _uploadController.pickVideo();
                    HapticFeedback.mediumImpact();
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isMobile ? 220 : 280,
              decoration: BoxDecoration(
                gradient: hasVideo
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          if (isDark)
                            const Color(0xFF1F2937)
                          else
                            const Color(0xFFF9FAFB),
                          if (isDark)
                            const Color(0xFF161B22)
                          else
                            AppColors.textPrimary,
                        ],
                      ),
                color: hasVideo
                    ? (isDark ? const Color(0xFF161B22) : AppColors.textPrimary)
                    : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasVideo
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                      : isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
                  width: hasVideo ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hasVideo
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                        : AppColors.bgPage.withValues(alpha: 0.05),
                    blurRadius: hasVideo ? 28 : 20,
                    offset: const Offset(0, 8),
                    spreadRadius: hasVideo ? 2 : 0,
                  ),
                ],
              ),
              child: hasVideo
                  ? _buildVideoPreviewEnhanced(isDark)
                  : _buildVideoUploadPlaceholder(isDark),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVideoPreviewEnhanced(bool isDark) {
    return Obx(() {
      final controller = _uploadController.videoPlayerController;
      final isUploading = _uploadController.isUploading.value;
      final progress = _uploadController.uploadProgress.value;

      return Stack(
        children: [
          // Video Player
          if (controller != null && controller.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                  HapticFeedback.lightImpact();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: MobileFriendlyVideoPlayer(
                            controller: controller,
                            looping: true,
                          ),
                        ),
                      ),
                    ),
                    if (!controller.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Upload Progress Overlay
          if (isUploading)
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgPage.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6),
                        ),
                        backgroundColor: AppColors.textPrimary.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading Video...',
                      style: context.themeTypography.title.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: context.themeTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Success Indicator
          if (_uploadController.isProcessing.value &&
              !_uploadController.isUploading.value)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Uploaded',
                      style: context.themeTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // File Info
          if (!isUploading)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPage.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadController.pickedVideo.value?.name ?? 'Video',
                        style: context.themeTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildVideoUploadPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_upload_rounded,
            size: 48,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Upload Video',
          style: context.themeTypography.headline.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag and drop or click to browse',
          style: context.themeTypography.body.copyWith(
            color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MP4, MOV, AVI • Max 500MB • Up to 10 minutes',
          style: context.themeTypography.bodySmall.copyWith(
            color: isDark ? AppColors.textTertiary : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedThumbnailUpload(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.image_rounded,
                size: 20,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thumbnail',
                    style: context.themeTypography.headline.copyWith(
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upload an eye-catching thumbnail image',
                    style: context.themeTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(() {
          final hasImage = _uploadController.pickedImage.value != null;
          final isUploading = _uploadController.isUploading.value;

          return Center(
            child: SizedBox(
              height: isMobile ? 320 : 360,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: InkWell(
                  onTap: isUploading
                      ? null
                      : () {
                          _uploadController.pickImage(forCommunity: false);
                          HapticFeedback.mediumImpact();
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: hasImage
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                if (isDark)
                                  const Color(0xFF1F2937)
                                else
                                  const Color(0xFFF9FAFB),
                                if (isDark)
                                  const Color(0xFF161B22)
                                else
                                  AppColors.textPrimary,
                              ],
                            ),
                      color: hasImage
                          ? (isDark ? const Color(0xFF161B22) : AppColors.textPrimary)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF30363D)
                            : const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bgPage.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: hasImage
                        ? _buildThumbnailPreview(isDark)
                        : _buildThumbnailPlaceholder(isDark),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildThumbnailPreview(bool isDark) {
    return Obx(() {
      final file = _uploadController.pickedImage.value!;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed responsive 9:16 Thumbnail Image
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: kIsWeb
                ? Image.memory(
                    file.bytes!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  )
                : Image.file(
                    io.File(file.path!),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
          ),

          // Gradient overlay for action button contrast
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          // Top Left: Moderation Status Indicator
          Positioned(
            top: 12,
            left: 12,
            child: _buildModerationStatusChip(),
          ),

          // Top Right: Quick Action Controls (Re-crop, Change, Remove)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Crop / Re-crop Button
                if (!kIsWeb && file.path != null)
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        try {
                          final cropped =
                              await ImageCropperService.cropVideoThumbnail(
                            imagePath: file.path!,
                            context: context,
                          );
                          if (cropped != null) {
                            final bytes = await cropped.readAsBytes();
                            _uploadController.pickedImage.value = PlatformFile(
                              name: file.name,
                              size: bytes.length,
                              path: cropped.path,
                              bytes: bytes,
                            );
                          }
                        } catch (e) {
                          debugPrint('Crop error: $e');
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.crop_rounded,
                          color: Colors.white, // Rule: Icons must be white
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                if (!kIsWeb && file.path != null) const SizedBox(width: 6),

                // Change Image Button
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _uploadController.pickImage(forCommunity: false);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.white, // Rule: Icons must be white
                        size: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Remove Image Button
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _uploadController.pickedImage.value = null;
                      _uploadController.thumbnailUrl.value = '';
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white, // Rule: Icons must be white
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// Helper function to get image dimensions
  Future<Size> _getImageSize(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes!;
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    } else {
      final decodedImage = await decodeImageFromList(
        await io.File(file.path!).readAsBytes(),
      );
      return Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
    }
  }

  Widget _buildThumbnailPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF262C36)
                : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_rounded,
            size: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add Thumbnail',
          style: context.themeTypography.title.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'JPEG, PNG • 9:16 ratio recommended',
            textAlign: TextAlign.center,
            style: context.themeTypography.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: context.themeTypography.title.copyWith(
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            validator: validator,
            style: context.themeTypography.body.copyWith(
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: context.themeTypography.body.copyWith(
                color: isDark
                    ? AppColors.textPrimary.withValues(alpha: 0.3)
                    : const Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF161B22)
                  : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: maxLines > 1 ? 16 : 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilitySettings(bool isDark) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visibility',
            style: AppTextStyles.titleMedium.copyWith(
              color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...['Public', 'Private', 'Members', 'SubscribersOnly'].map((
            visibility,
          ) {
            final isSelected =
                _uploadController.selectedVisibility.value == visibility;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _uploadController.selectedVisibility.value = visibility;
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brand.withValues(alpha: 0.1)
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.brand : AppColors.bgDivider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getVisibilityIcon(visibility),
                        size: 20,
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visibility,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.brand
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _getVisibilityDescription(visibility),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _buildAudienceSettings(bool isDark) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.child_care_rounded,
                size: 20,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Made for kids',
                    style: context.themeTypography.body.copyWith(
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Content designed for viewers under 13',
                    style: context.themeTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _uploadController.isKidFriendly.value,
              onChanged: (value) {
                _uploadController.isKidFriendly.value = value;
                HapticFeedback.lightImpact();
              },
              activeThumbColor: const Color(0xFF10B981),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildScheduleSettings(bool isDark) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule for later',
                        style: context.themeTypography.body.copyWith(
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Publish automatically at a specific time',
                        style: context.themeTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _uploadController.isScheduled.value,
                  onChanged: (value) {
                    _uploadController.isScheduled.value = value;
                    if (value) {
                      _selectScheduleDateTime();
                    }
                    HapticFeedback.lightImpact();
                  },
                  activeThumbColor: const Color(0xFF8B5CF6),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (_uploadController.isScheduled.value) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scheduled: ${DateFormat("MMM d, yyyy 'at' h:mm a").format(_uploadController.scheduledDate.value)}',
                        style: context.themeTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _selectScheduleDateTime,
                      child: Text(
                        'Change',
                        style: context.themeTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildPlaylistSelection(bool isDark) {
    return Obx(() {
      final playlists = _playlistController.publicPlaylists.toList();

      if (playlists.isEmpty) {
        return _buildNoPublicPlaylistsMessage(isDark);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add to Public Playlist',
                style: context.themeTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () async {
                  _playlistController.refreshPlaylistsTick();
                  await _playlistController.refreshPublicPlaylists();
                  Get.snackbar(
                    'Refreshing',
                    'Loading public playlists...',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 1),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                  padding: const EdgeInsets.all(8),
                ),
                tooltip: 'Refresh public playlists',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPlaylistDropdownFromModels(playlists, isDark),
        ],
      );
    });
  }

  Widget _buildNoPublicPlaylistsMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.public_rounded,
            size: 32,
            color: isDark ? AppColors.textTertiary : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          Text(
            'No public playlists',
            style: context.themeTypography.body.copyWith(
              color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Public playlists will appear here',
            style: context.themeTypography.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _playlistController.refreshPlaylistsTick();
                    _playlistController.refreshPublicPlaylists();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondary,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE5E7EB),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCreatePublicPlaylistDialog(isDark),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreatePublicPlaylistDialog(bool isDark) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF161B22)
            : AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create Public Playlist',
          style: context.themeTypography.headline.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playlist Name',
              style: context.themeTypography.label.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              autofocus: true,
              style: context.themeTypography.body.copyWith(
                color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: 'Enter playlist name',
                hintStyle: context.themeTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textTertiary
                      : const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0D1117)
                    : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: context.themeTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                // Create as public playlist
                final playlist = await _playlistController.createPlayList(
                  name,
                  isPublic: true,
                  videoIds: _uploadController.currentVideoId != null
                      ? [_uploadController.currentVideoId!]
                      : [],
                );

                if (playlist != null) {
                  // Select the newly created playlist
                  _uploadController.selectPlaylist(playlist.id);
                  // Refresh public playlists list
                  _playlistController.refreshPublicPlaylists();
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Create',
              style: context.themeTypography.button,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistDropdownFromModels(
    List<PlaylistModel> playlists,
    bool isDark,
  ) {
    return Obx(() {
      final currentPlaylistId = _uploadController.selectedPlaylist.value;

      final items = playlists.map((playlist) {
        return DropdownMenuItem<String>(
          key: ValueKey('playlist_${playlist.id}'),
          value: playlist.id,
          child: Text(playlist.playlistName, overflow: TextOverflow.ellipsis),
        );
      }).toList();

      items.insert(
        0,
        const DropdownMenuItem<String>(
          value: '',
          child: Text("None (don't add to playlist)"),
        ),
      );

      items.add(
        const DropdownMenuItem<String>(
          value: 'create_new',
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 16, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text(
                'Create new playlist',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      return DropdownButtonFormField<String>(
        key: ValueKey(
          'playlist_dropdown_${playlists.length}_$currentPlaylistId',
        ),
        initialValue: items.any((item) => item.value == currentPlaylistId)
            ? currentPlaylistId
            : '',
        decoration: InputDecoration(
          hintText: 'Select playlist',
          prefixIcon: const Icon(
            Icons.playlist_play_rounded,
            size: 20,
            color: Color(0xFF3B82F6),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        dropdownColor: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
        style: context.themeTypography.body.copyWith(
          color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
        ),
        items: items,
        onChanged: (value) {
          if (value == 'create_new') {
            showCreatePlaylistModal(isDark);
          } else {
            _uploadController.selectPlaylist(value ?? '');
            HapticFeedback.lightImpact();
          }
        },
      );
    });
  }

  Widget _buildTopicSelection(bool isDark) {
    return Obx(() {
      final selectedSlug = _uploadController.selectedTopicId.value;
      final hasDraft = _uploadController.newTopicData.isNotEmpty;
      final topics = _uploadController.availableTopics;

      Topic? selectedTopic;
      if (selectedSlug.isNotEmpty && selectedSlug != 'new_topic_draft') {
        for (final t in topics) {
          if (t.slug == selectedSlug) {
            selectedTopic = t;
            break;
          }
        }
      }

      final draftTitle = hasDraft
          ? (_uploadController.newTopicData['title'] as String? ?? 'New Draft')
          : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add to Topic',
                style: context.themeTypography.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (_uploadController.isTopicsLoading.value)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: () => _showCreateTopicModal(isDark),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ New Topic'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Selected Topic Trigger Card
          InkWell(
            onTap: () => TopicSelectionBottomSheet.show(
              context,
              _uploadController,
              onCreateNewTopic: _showCreateTopicModal,
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (selectedTopic != null || hasDraft)
                      ? const Color(0xFF3B82F6)
                      : (isDark
                            ? const Color(0xFF30363D)
                            : const Color(0xFFE5E7EB)),
                  width: (selectedTopic != null || hasDraft) ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bgPage.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Topic Thumbnail or Icon
                  if (hasDraft)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        color: Colors.white,
                        size: 22,
                      ),
                    )
                  else if (selectedTopic != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 46,
                        height: 46,
                        color: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB),
                        child:
                            (selectedTopic.thumbnailUrl ??
                                        selectedTopic.coverImage) !=
                                    null &&
                                (selectedTopic.thumbnailUrl ??
                                        selectedTopic.coverImage)!
                                    .isNotEmpty
                            ? Image.network(
                                (selectedTopic.thumbnailUrl ??
                                    selectedTopic.coverImage)!,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              )
                            : ColoredBox(
                                color: const Color(
                                  0xFF3B82F6,
                                ).withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.topic_rounded,
                                  color: Color(0xFF3B82F6),
                                  size: 22,
                                ),
                              ),
                      ),
                    )
                  else
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.topic_rounded,
                        color: isDark
                            ? AppColors.textSecondary
                            : const Color(0xFF6B7280),
                        size: 22,
                      ),
                    ),

                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDraft) ...[
                          Text(
                            'Draft: $draftTitle',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandHover,
                            ),
                          ),
                          Text(
                            'Will be created upon upload',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ] else if (selectedTopic != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedTopic.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (selectedTopic.visibilityType ==
                                  TopicVisibilityType.private)
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: AppColors.warning,
                                )
                              else if (selectedTopic.visibilityType ==
                                  TopicVisibilityType.channelOnly)
                                const Icon(
                                  Icons.group_rounded,
                                  size: 14,
                                  color: AppColors.info,
                                )
                              else
                                const Icon(
                                  Icons.public_rounded,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${FormatUtils.formatCount(selectedTopic.followerCount)} followers • ${FormatUtils.formatCount(selectedTopic.videoCount)} videos',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'Select Topic knowledge hub',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to search and select a topic or create new',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Action Chevron / Clear button
                  if (selectedTopic != null || hasDraft)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _uploadController.selectTopic('');
                        _uploadController.newTopicData.clear();
                        HapticFeedback.lightImpact();
                      },
                      tooltip: 'Remove topic',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.all(4),
                      ),
                    )
                  else
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showCreateTopicModal(bool isDark) {
    final currentChannelId = _uploadController.selectedChannel.value?.id ?? '';
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDark,
      channelVideosFuture: currentChannelId.isNotEmpty
          ? FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('channelId', isEqualTo: currentChannelId)
                .get()
                .then(
                  (snap) => snap.docs
                      .map((doc) => {'id': doc.id, ...doc.data()})
                      .toList(),
                )
          : Future.value([]),
      onCreateTopicSubmitted: (createCtrl) async {
        final title = createCtrl.titleController.text.trim();
        var rawHandle = createCtrl.handleController.text.trim();
        if (rawHandle.startsWith('T/') || rawHandle.startsWith('t/')) {
          rawHandle = rawHandle.substring(2);
        }
        final cleanHandle = rawHandle
            .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
            .replaceAll(RegExp('-+'), '-');
        final finalHandle = 'T/$cleanHandle';
        final finalHandleLowercase = finalHandle.toLowerCase();

        // Check handle uniqueness in Firestore
        final existingHandle = await FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isEqualTo: finalHandleLowercase)
            .limit(1)
            .get();

        if (existingHandle.docs.isNotEmpty) {
          Get.snackbar(
            'Error',
            'Topic handle is already taken. Please choose a different one.',
          );
          throw Exception('Handle already taken');
        }

        _uploadController.newTopicData.value = {
          'title': title,
          'handle': finalHandle,
          'description': createCtrl.descriptionController.text.trim(),
          'category': createCtrl.categoryController.text,
          'visibilityType': createCtrl.selectedVisibility.value,
          'accessCode': createCtrl.accessCodeController.text.trim(),
          'thumbnailSource': createCtrl.thumbnailSource.value,
          'customThumbnailBytes': createCtrl.pickedCustomImageBytes.value,
          'customThumbnailName': createCtrl.pickedCustomImageName.value,
        };

        _uploadController.selectedTopicId.value = 'new_topic_draft';
        Get.snackbar(
          'Success',
          'Topic draft created! It will be published along with your video.',
        );
      },
    );
  }

  Widget _buildChannelSelectionSection(bool isDark) {
    return Obx(() {
      if (_uploadController.channels.isEmpty) {
        return _buildNoChannelsCard();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publishing channel',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildChannelDropdown(isDark),
        ],
      );
    });
  }

  Widget _buildChannelDropdown(bool isDark) {
    return Obx(() {
      return DropdownButtonFormField<String>(
        initialValue: _uploadController.selectedChannel.value?.channelId,
        decoration: InputDecoration(
          hintText: 'Select a channel',
          prefixIcon: const Icon(
            Icons.account_circle_rounded,
            size: 20,
            color: Color(0xFF3B82F6),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        dropdownColor: AppColors.bgSurface,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        items: _uploadController.channels.map((channel) {
          return DropdownMenuItem<String>(
            value: channel.channelId,
            child: Text(channel.channelName),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            final selected = _uploadController.channels.firstWhere(
              (channel) => channel.channelId == value,
            );
            _uploadController.selectChannel(selected);
            HapticFeedback.lightImpact();
          }
        },
      );
    });
  }

  void showCreatePlaylistModal(bool isDark) {
    final playListNameController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) {
        const isPublic = true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: const Border(
              top: BorderSide(
                color: AppColors.bgDivider,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: isTablet ? 32 : 24,
              right: isTablet ? 32 : 24,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1DB954).withValues(alpha: 0.2),
                            const Color(0xFF106E3A).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.playlist_add_rounded,
                        color: Color(0xFF1DB954),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Playlist',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontSize: isTablet ? 26 : 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Name your new collection',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: playListNameController,
                    style: AppTextStyles.inputText,
                    decoration: InputDecoration(
                      labelText: 'Playlist Name',
                      labelStyle: AppTextStyles.inputHint,
                      hintText: 'Enter a descriptive name...',
                      hintStyle: AppTextStyles.inputHint,
                      prefixIcon: const Icon(
                        Icons.title_rounded,
                        color: AppColors.textTertiary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppColors.bgDivider,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppColors.bgDivider,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF1DB954),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1DB954), Color(0xFF106E3A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 20 : 18,
                        horizontal: 24,
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    label: Text(
                      'CREATE PLAYLIST',
                      style: AppTextStyles.buttonText.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isTablet ? 17 : 16,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () async {
                      final playlistName = playListNameController.text.trim();
                      if (playlistName.isEmpty) {
                        Get.snackbar(
                          'Missing Information',
                          'Please enter a playlist name',
                          snackPosition: SnackPosition.TOP,
                          backgroundColor: const Color(0xFFEF4444),
                          colorText: AppColors.textPrimary,
                          borderRadius: 12,
                          margin: const EdgeInsets.all(16),
                          icon: const Icon(
                            Icons.error_outline,
                            color: AppColors.textPrimary,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      // Create the playlist and get the result
                      final createdPlaylist = await _playlistController
                          .createPlayList(
                            playlistName,
                            isPublic: isPublic,
                            videoIds: _uploadController.currentVideoId != null
                                ? [_uploadController.currentVideoId!]
                                : [],
                          );

                      playListNameController.clear();

                      if (createdPlaylist != null) {
                        // Refresh playlists to get the latest data
                        _playlistController.refreshPlaylistsTick();
                        await _playlistController.refreshPlaylists();

                        // Select the newly created playlist using the returned object
                        _uploadController.selectPlaylist(createdPlaylist.id);
                        debugPrint(
                          '✅ Selected newly created playlist: ${createdPlaylist.playlistName} (${createdPlaylist.id})',
                        );
                      } else {
                        debugPrint('❌ Failed to create playlist');
                      }

                      Get.snackbar(
                        'Success',
                        'Playlist created successfully!',
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: const Color(0xFF1DB954),
                        colorText: AppColors.textPrimary,
                        borderRadius: 12,
                        margin: const EdgeInsets.all(16),
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Deferred loading support
Future<void> loadLibrary() => Future.value();
