import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/community_post_upload_binding.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/community_post_upload_screen.dart';
import 'package:truthworld/features/dashboard/data/models/draft_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/pages/create_topic_screen.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
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
    _tagsController.addListener(_validateForm);
    _communityTitleController.addListener(_validateForm);
    _communityDescriptionController.addListener(_validateForm);
    _communityTagsController.addListener(_validateForm);

    // Initialize playlist controller and load public and user playlists
    _playlistController.fetchPlaylists();
    _playlistController.fetchPublicPlaylists();
    _uploadController.fetchAvailableTopics();
    debugPrint('🎵 Playlist & Topic controllers initialized');

    _loadDraftFromArguments();
  }

  void _loadDraftFromArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final videoArg = args['video'] ?? args['draftVideo'];
      final draftArg = args['draft'];
      final videoId = (args['videoId'] as String?) ?? (args['id'] as String?);

      if (videoArg is Video) {
        _uploadController.loadFromVideo(videoArg);
        _titleController.text = _uploadController.titleController.text;
        _descriptionController.text = _uploadController.descriptionController.text;
        _tagsController.text = videoArg.tags.join(', ');
        debugPrint('🎬 Resumed Video Draft from Video Object: ${videoArg.id}');
      } else if (videoId != null && videoId.isNotEmpty) {
        FirebaseFirestore.instance.collection('videos').doc(videoId).get().then((doc) {
          if (doc.exists && doc.data() != null) {
            final v = Video.fromMap(doc.data()!, doc.id);
            _uploadController.loadFromVideo(v);
            _titleController.text = _uploadController.titleController.text;
            _descriptionController.text = _uploadController.descriptionController.text;
            _tagsController.text = v.tags.join(', ');

            final rawFileName = doc.data()!['fileName'] as String?;
            final moderation = doc.data()!['moderation'] as Map<String, dynamic>?;

            if (_titleController.text.isEmpty &&
                rawFileName != null &&
                rawFileName.isNotEmpty) {
              final cleanName = rawFileName
                  .replaceAll(
                    RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false),
                    '',
                  )
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ');
              _titleController.text = cleanName;
              _uploadController.titleController.text = cleanName;
            }

            if (_descriptionController.text.isEmpty && moderation != null) {
              final summary = moderation['summary'] as String?;
              if (summary != null && summary.isNotEmpty) {
                _descriptionController.text = summary;
                _uploadController.descriptionController.text = summary;
              }
            }

            _uploadController.update();
            debugPrint('🎬 Resumed Video Draft from Firestore ID: $videoId');
          }
        }).catchError((e) {
          debugPrint('⚠️ Error loading video draft $videoId: $e');
        });
      } else if (draftArg is DraftModel) {
        _titleController.text = draftArg.title;
        _descriptionController.text = draftArg.content;
      }
    }
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
    final rawTitle = _titleController.text.trim();
    final rawDesc = _descriptionController.text.trim();
    final rawTags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final isTitleClean = ContentValidator.validate(
      rawTitle,
      fieldName: 'Title',
      minLength: 5,
      maxLength: 100,
    ).isValid;
    final isDescClean = ContentValidator.validate(
      rawDesc,
      fieldName: 'Description',
      minLength: 10,
      maxLength: 500,
    ).isValid;
    final isTagsClean = rawTags.isEmpty ||
        ContentValidator.validateTags(
          rawTags,
        ).isValid;

    final isValid = isTitleClean && isDescClean && isTagsClean;
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
    if (widget.uploadType == UploadType.communityPost) {
      if (!Get.isRegistered<CommunityPostUploadController>()) {
        CommunityPostUploadBinding().dependencies();
      }
      return const CommunityPostUploadScreen();
    }
    if (widget.uploadType == UploadType.playlist) {
      return const CreatePlaylistScreen();
    }
    if (widget.uploadType == UploadType.topic) {
      return const CreateTopicScreen();
    }

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
        final authChannel = AuthService.to.userChannel;
        if (authChannel != null && authChannel.status != ChannelStatus.deleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_uploadController.channels.isEmpty) {
              _uploadController.channels.value = [authChannel];
              _uploadController.selectedChannel.value = authChannel;
            }
          });
          return const Center(child: CircularProgressIndicator());
        }
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

      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (widget.uploadType == UploadType.video) {
        return _buildVideoUploadFlow(isDark);
      }

      return Column(
        children: [
          _buildEnhancedAppBar(),
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.layoutTokens.contentMaxWidth,
              ),
              margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
              child: _buildCommunityUploadFlow(isDark),
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
          'Your channel details are currently under review by our Verification System. You can publish videos once approved.';
    } else if (channel.status == ChannelStatus.verificationRejected) {
      statusColor = context.colors.error;
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected';
      subtitle =
          channel.moderationReason != null &&
              channel.moderationReason!.isNotEmpty
          ? channel.moderationReason!
          : 'Your channel details were rejected by our Verification System. Please update your name, description, or tags in customization to re-verify.';
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
              child: const Icon(
                Icons.video_library_outlined,
                size: 40,
                color: Colors.white,
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
            icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
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
        final authChannel = AuthService.to.userChannel;
        if (authChannel != null && authChannel.status != ChannelStatus.deleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_uploadController.channels.isEmpty) {
              _uploadController.channels.value = [authChannel];
              _uploadController.selectedChannel.value = authChannel;
            }
          });
          return const SizedBox.shrink();
        }
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
              const Icon(
                Icons.video_library_outlined,
                size: 32,
                color: Colors.white,
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
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
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

      final isStandard = channel.channelType == ChannelType.standard;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
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
                            ? (isStandard
                                ? 'Standard Channel (20m/day limit)'
                                : 'Custom Channel (Unlimited)')
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
            if (isStandard) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D1117)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _uploadController.isDailyLimitReached.value
                        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                        : (isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.timelapse_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Daily Upload Limit',
                              style: context.themeTypography.label.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _uploadController.isDailyLimitReached.value
                                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _uploadController.isDailyLimitReached.value
                                ? 'Limit Reached (0m left)'
                                : '${_uploadController.remainingDailyDurationFormatted} remaining',
                            style: context.themeTypography.label.copyWith(
                              fontSize: 11,
                              color: _uploadController.isDailyLimitReached.value
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadController.dailyQuotaUsedRatio,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _uploadController.isDailyLimitReached.value
                              ? const Color(0xFFEF4444)
                              : (_uploadController.dailyQuotaUsedRatio > 0.75
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_uploadController.todayUploadedDurationFormatted} / 20 min used today',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textTertiary
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Resets daily at 00:00',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textTertiary
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                          ),
                        ),
                      ],
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
                            image: (kIsWeb && image.bytes != null)
                                ? MemoryImage(image.bytes!) as ImageProvider
                                : (image.path != null
                                    ? FileImage(io.File(image.path!))
                                    : (image.bytes != null
                                        ? MemoryImage(image.bytes!)
                                        : const AssetImage('assets/images/logo.png') as ImageProvider)),
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
      final isProcessing = _uploadController.isProcessing.value;

      if (isProcessing) {
        return _buildProcessingButton(
          isDark,
          _uploadController.processingMessage.value.isNotEmpty
              ? _uploadController.processingMessage.value
              : 'Publishing Video...',
        );
      }

      if (isUploading && !canPublish) {
        return _buildUploadingButton(isDark);
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
                        : (isUploading
                            ? Icons.cloud_sync_rounded
                            : Icons.cloud_upload_rounded),
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
                        : (isUploading
                            ? 'Publish (Uploading in background)'
                            : 'Publish Now'),
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
      final hasVideo = _uploadController.videoUrl.value.isNotEmpty ||
          _uploadController.pickedVideo.value != null ||
          _uploadController.resumedVideoDraft.value != null;
      final hasTitle = _titleController.text.trim().isNotEmpty;
      final canSaveDraft = hasVideo && hasTitle;

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
                  image: (kIsWeb && file.bytes != null)
                      ? MemoryImage(file.bytes!) as ImageProvider
                      : (file.path != null
                          ? FileImage(io.File(file.path!))
                          : (file.bytes != null
                              ? MemoryImage(file.bytes!)
                              : const AssetImage('assets/images/logo.png') as ImageProvider)),
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
                    ? AppColors.textTertiary
                    : const Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
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
                  color: Color(0xFF3B82F6),
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
    final pickedVideo = _uploadController.pickedVideo.value;
    final selectedChannel = _uploadController.selectedChannel.value;
    final selectedCategory = _uploadController.selectedCategory.value;
    final finalStatus = _uploadController.finalstatus.value.toUpperCase();

    final hasVideo = videoUrl.isNotEmpty ||
        pickedVideo != null ||
        _uploadController.resumedVideoDraft.value != null;
    final hasThumbnail = thumbnailUrl.isNotEmpty || pickedImage != null;
    final hasChannel = selectedChannel != null;
    final isChannelActive =
        selectedChannel != null &&
        selectedChannel.status == ChannelStatus.active;
    final rawTitle = _titleController.text.trim();
    final rawDesc = _descriptionController.text.trim();
    final rawTags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final isTitleValid = ContentValidator.validate(
      rawTitle,
      fieldName: 'Title',
      minLength: 5,
      maxLength: 100,
    ).isValid;

    final isDescValid = ContentValidator.validate(
      rawDesc,
      fieldName: 'Description',
      minLength: 10,
      maxLength: 500,
      checkPhoneNumbers: true,
    ).isValid;

    final isTagsValid = rawTags.isEmpty ||
        ContentValidator.validateTags(
          rawTags,
        ).isValid;

    final hasCategory = selectedCategory.isNotEmpty;
    final isThumbnailApproved =
        (thumbnailUrl.isNotEmpty && pickedImage == null) ||
            finalStatus == 'APPROVED' ||
            finalStatus.isEmpty;
    final isDailyLimitValid = !(selectedChannel != null &&
        selectedChannel.channelType == ChannelType.standard &&
        _uploadController.isDailyLimitReached.value);
    final isCopyrightConfirmed =
        _uploadController.hasConfirmedCopyrightDeclaration.value;

    final result = hasVideo &&
        hasThumbnail &&
        hasChannel &&
        isChannelActive &&
        isTitleValid &&
        isDescValid &&
        isTagsValid &&
        hasCategory &&
        isThumbnailApproved &&
        isDailyLimitValid &&
        isCopyrightConfirmed;

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
              'Your channel details are currently under review by our Verification System. You can publish videos once approved.';
        } else if (selectedChannel.status == ChannelStatus.verificationRejected) {
          message =
              selectedChannel.moderationReason != null &&
                  selectedChannel.moderationReason!.isNotEmpty
              ? 'Branding Rejected: ${selectedChannel.moderationReason!}'
              : 'Your channel details were rejected by our Verification System. Please update your channel details in customization to re-verify.';
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

      if (!_uploadController.hasConfirmedCopyrightDeclaration.value) {
        Get.snackbar(
          'Copyright Declaration Required',
          'Please confirm and check the copyright ownership declaration before publishing your video.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      final rawTitle = _titleController.text.trim();
      final rawDesc = _descriptionController.text.trim();
      final rawTags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final titleValidation = ContentValidator.validate(
        rawTitle,
        fieldName: 'Title',
        minLength: 5,
        maxLength: 100,
      );
      if (!titleValidation.isValid) {
        Get.snackbar(
          'Profanity / Invalid Title',
          titleValidation.message,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        );
        return;
      }

      final descValidation = ContentValidator.validate(
        rawDesc,
        fieldName: 'Description',
        minLength: 10,
        maxLength: 500,
        checkPhoneNumbers: true,
      );
      if (!descValidation.isValid) {
        Get.snackbar(
          'Profanity / Invalid Description',
          descValidation.message,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        );
        return;
      }

      if (rawTags.isNotEmpty) {
        final tagsValidation = ContentValidator.validateTags(
          rawTags,
        );
        if (!tagsValidation.isValid) {
          Get.snackbar(
            'Profanity / Invalid Tags',
            tagsValidation.message,
            backgroundColor: const Color(0xFFEF4444),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
          );
          return;
        }
      }

      final canPublish = _canPublishVideo();
      if (!canPublish) {
        var errorMessage = 'Cannot publish. Validation checks:\n';
        if (_uploadController.videoUrl.value.isEmpty &&
            _uploadController.pickedVideo.value == null &&
            _uploadController.resumedVideoDraft.value == null) {
          errorMessage += '- Video file or draft is required.\n';
        }
        if (_uploadController.thumbnailUrl.value.isEmpty &&
            _uploadController.pickedImage.value == null) {
          errorMessage += '- Thumbnail image is required.\n';
        }
        if (_uploadController.selectedCategory.value.isEmpty) {
          errorMessage += '- Category is required.\n';
        }
        if (_uploadController.selectedChannel.value == null) {
          errorMessage += '- Channel not selected.\n';
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
        throw Exception('Channel selection failed - please select a channel');
      }

      final rawTags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (rawTags.length > ContentValidator.defaultMaxTags) {
        throw Exception(
          'Maximum ${ContentValidator.defaultMaxTags} tags allowed (currently ${rawTags.length})',
        );
      }

      final tags = rawTags.take(ContentValidator.defaultMaxTags).toList();
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
        errorMessage = 'Firebase error: ${e.message ?? e.code}';
      } else if (e is io.IOException) {
        errorMessage = 'Network error: Check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please check your input.';
      } else {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
        if (cleanMsg.isNotEmpty) {
          errorMessage = cleanMsg;
        }
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

      if (rawCommunityTags.length > ContentValidator.defaultMaxTags) {
        throw Exception(
          'Maximum ${ContentValidator.defaultMaxTags} tags allowed (currently ${rawCommunityTags.length})',
        );
      }

      final tags = rawCommunityTags.take(ContentValidator.defaultMaxTags).toList();

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
        errorMessage = 'Firebase error: ${e.message ?? e.code}';
      } else if (e is io.IOException) {
        errorMessage = 'Network error: Check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid data format. Please check your input.';
      } else {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
        if (cleanMsg.isNotEmpty) {
          errorMessage = cleanMsg;
        }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: Column(
              children: [
                if (isWide) _buildPlaylistStyleTopHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 48.0 : 16.0,
                      vertical: 24.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlaylistStylePageHeader(context, isWide),
                            const SizedBox(height: 24),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column (Sections 1-5)
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSection1Title(context),
                                        const SizedBox(height: 20),
                                        _buildSection2Description(context),
                                        const SizedBox(height: 20),
                                        _buildSection3Tags(context),
                                        const SizedBox(height: 20),
                                        _buildSection4Category(context),
                                        const SizedBox(height: 20),
                                        _buildSection5Visibility(context),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 32),

                                  // Right Column (Sections 6-10)
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSection6VideoFile(context),
                                        const SizedBox(height: 20),
                                        _buildSection7Thumbnail(context),
                                        const SizedBox(height: 20),
                                        _buildSection8Playlist(context),
                                        const SizedBox(height: 20),
                                        _buildSection9Topic(context),
                                        const SizedBox(height: 20),
                                        _buildSection10AIFeatures(context),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSection1Title(context),
                                  const SizedBox(height: 20),
                                  _buildSection2Description(context),
                                  const SizedBox(height: 20),
                                  _buildSection3Tags(context),
                                  const SizedBox(height: 20),
                                  _buildSection4Category(context),
                                  const SizedBox(height: 20),
                                  _buildSection5Visibility(context),
                                  const SizedBox(height: 20),
                                  _buildSection6VideoFile(context),
                                  const SizedBox(height: 20),
                                  _buildSection7Thumbnail(context),
                                  const SizedBox(height: 20),
                                  _buildSection8Playlist(context),
                                  const SizedBox(height: 20),
                                  _buildSection9Topic(context),
                                  const SizedBox(height: 20),
                                   _buildSection10AIFeatures(context),
                                  const SizedBox(height: 20),
                                  _buildSection11CopyrightDeclaration(context),
                                ],
                              ),
                            if (isWide) ...[
                              const SizedBox(height: 24),
                              _buildSection11CopyrightDeclaration(context),
                            ],
                            const SizedBox(height: 32),
                            if (isWide) _buildPlaylistStyleFooterActions(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isWide) _buildPlaylistStyleMobileFooter(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // Top Bar for Desktop matching Create Playlist
  Widget _buildPlaylistStyleTopHeader(BuildContext context) {
    final selectedChannel = _uploadController.selectedChannel.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              const AppLogo(
                size: 26,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Text(
                'TRUTHWORLD',
                style: context.themeTypography.logo.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (selectedChannel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    photoUrl: selectedChannel.avatarUrl,
                    displayName: selectedChannel.channelName,
                    radius: 12,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedChannel.channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Page Header matching Create Playlist
  Widget _buildPlaylistStylePageHeader(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Text(
              'Upload Video',
              style: context.themeTypography.display.copyWith(
                fontSize: isDesktop ? 26 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            'Upload and organize videos on your channel.',
            style: context.themeTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
      ],
    );
  }

  // Section 1: Video Title
  Widget _buildSection1Title(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Video Title',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _titleController,
            builder: (context, value, _) {
              final text = value.text.trim();
              final validation = text.isNotEmpty
                  ? ContentValidator.validate(
                      text,
                      fieldName: 'Title',
                      minLength: 5,
                      maxLength: 100,
                    )
                  : null;
              final hasError = validation != null &&
                  !validation.isValid &&
                  (text.length >= 5 ||
                      validation.message.contains('inappropriate') ||
                      validation.message.contains('offensive') ||
                      validation.message.contains('prohibited'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextField(
                        controller: _titleController,
                        maxLength: 100,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter video title',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          counterText: '',
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 14, 60, 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        child: Text(
                          '${value.text.length}/100',
                          style: TextStyle(
                            color: hasError
                                ? const Color(0xFFEF4444)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            validation.message,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Give your video a clear and catchy title.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Section 2: Description
  Widget _buildSection2Description(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Description',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _descriptionController,
            builder: (context, value, _) {
              final text = value.text.trim();
              final validation = text.isNotEmpty
                  ? ContentValidator.validate(
                      text,
                      fieldName: 'Description',
                      minLength: 10,
                      maxLength: 500,
                      checkPhoneNumbers: true,
                    )
                  : null;
              final hasError = validation != null &&
                  !validation.isValid &&
                  (text.length >= 10 ||
                      validation.message.contains('inappropriate') ||
                      validation.message.contains('offensive') ||
                      validation.message.contains('prohibited'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: 500,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Describe your video',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          counterText: '',
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 14, 16, 30),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 10,
                        child: Text(
                          '${value.text.length}/500',
                          style: TextStyle(
                            color: hasError
                                ? const Color(0xFFEF4444)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            validation.message,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Tell viewers what your video is about.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Section 3: Tags
  Widget _buildSection3Tags(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. Tags',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _tagsController,
            builder: (context, value, _) {
              final rawTags = value.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              final validation = rawTags.isNotEmpty
                  ? ContentValidator.validateTags(
                      rawTags,
                    )
                  : null;
              final hasError = validation != null && !validation.isValid;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tagsController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Add tags separated by commas (e.g. Space, Tech, Science)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      fillColor: const Color(0xFF0F0F11),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: hasError
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color:
                              hasError ? const Color(0xFFEF4444) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            validation.message,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Add relevant tags to help others find your video.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Section 4: Category
    Widget _buildSection4Category(BuildContext context) {
    return Obx(() {
      final currentCategory = _uploadController.selectedCategory.value;
      final categories = _uploadController.videoCategories;
      final selectedVal = categories.contains(currentCategory) ? currentCategory : categories.first;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Category',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedVal,
              decoration: InputDecoration(
                fillColor: const Color(0xFF0F0F11),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              dropdownColor: const Color(0xFF161618),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  _uploadController.selectCategory(val);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the category that best fits your video.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    });
  }

  // Section 5: Visibility
    Widget _buildSection5Visibility(BuildContext context) {
    return Obx(() {
      final currentVisibility = _uploadController.selectedVisibility.value;

      final options = <Map<String, dynamic>>[
        {
          'value': 'Public',
          'title': 'Public',
          'subtitle': 'Anyone can view this video',
          'icon': Icons.public,
        },
        {
          'value': 'Private',
          'title': 'Private',
          'subtitle': 'Only you can view this video',
          'icon': Icons.lock_outline,
        },
        {
          'value': 'Unlisted',
          'title': 'Unlisted',
          'subtitle': 'Anyone with the link can view this video',
          'icon': Icons.link,
        },
        {
          'value': 'Members only',
          'title': 'Members only',
          'subtitle': 'Only channel members can view this video',
          'icon': Icons.card_membership_rounded,
        },
        {
          'value': 'Subscribers only',
          'title': 'Subscribers only',
          'subtitle': 'Only channel subscribers can view this video',
          'icon': Icons.people_alt_rounded,
        },
      ];

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5. Visibility',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose who can view this video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final isSelected = currentVisibility.toLowerCase() == (opt['value'] as String).toLowerCase();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _uploadController.selectedVisibility.value = opt['value'] as String,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(opt['icon'] as IconData, color: Colors.white, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                opt['subtitle'] as String,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  // Section 6: Video File Upload
      Widget _buildSection6VideoFile(BuildContext context) {
    return Obx(() {
      final pickedVideo = _uploadController.pickedVideo.value;
      final videoUrl = _uploadController.videoUrl.value;
      final isUploading = _uploadController.isUploading.value;
      final progressPercent = _uploadController.uploadProgressPercent;
      final playerCtrl = _uploadController.videoPlayerController;
      final hasVideo = pickedVideo != null || videoUrl.isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '6. Video File',
                  style: context.themeTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _uploadController.pickVideo(),
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: Text(
                    hasVideo ? 'Change video' : 'Select video',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasVideo)
              InkWell(
                onTap: () => _uploadController.pickVideo(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Select video to upload',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Click or drag video file to upload (MP4, MOV, MKV, WEBM)',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    if (playerCtrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: MobileFriendlyVideoPlayer(
                            controller: playerCtrl,
                            showControls: true,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              pickedVideo?.name ?? 'Video File Ready',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.video_library, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedVideo?.name ?? 'Video File Ready',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isUploading)
                                  Text(
                                    'Uploading: $progressPercent',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUploading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _uploadController.uploadProgress.value,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            color: Colors.white,
                            minHeight: 4,
                          ),
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

  // Section 7: Thumbnail Image
    Widget _buildSection7Thumbnail(BuildContext context) {
    return Obx(() {
      final pickedImage = _uploadController.pickedImage.value;
      final thumbnailUrl = _uploadController.thumbnailUrl.value;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7. Thumbnail',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose or upload a YouTube 16:9 thumbnail for your video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            if (pickedImage != null && ((kIsWeb && pickedImage.bytes != null) || (pickedImage.path != null && pickedImage.path!.isNotEmpty) || pickedImage.bytes != null))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (kIsWeb && pickedImage.bytes != null)
                        ? Image.memory(pickedImage.bytes!, fit: BoxFit.cover)
                        : (pickedImage.path != null
                            ? Image.file(io.File(pickedImage.path!), fit: BoxFit.cover)
                            : (pickedImage.bytes != null
                                ? Image.memory(pickedImage.bytes!, fit: BoxFit.cover)
                                : const SizedBox.shrink())),
                  ),
                ),
              )
            else if (thumbnailUrl.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (ctx, url, err) => const ColoredBox(
                        color: Color(0xFF0F0F11),
                        child: Icon(Icons.image, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
            InkWell(
              onTap: () => _uploadController.pickImage(forCommunity: false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_upload_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickedImage != null || thumbnailUrl.isNotEmpty ? 'Change Thumbnail' : 'Upload custom image',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '16:9 Aspect Ratio (1280x720). PNG, JPG or WEBP.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showCreatePlaylistModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isPublic = false.obs;
    final isSubmitting = false.obs;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create New Playlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Playlist Name *',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        hintText: 'Enter playlist title',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        fillColor: const Color(0xFF0F0F11),
                        filled: true,
                        prefixIcon: const Icon(Icons.playlist_add, color: Colors.white, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a playlist name';
                        }
                        final res = ContentValidator.validate(val.trim(), fieldName: 'Playlist Name', minLength: 2, maxLength: 80);
                        if (!res.isValid) return res.message;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        hintText: 'Enter playlist description',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        fillColor: const Color(0xFF0F0F11),
                        filled: true,
                        prefixIcon: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Obx(() => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: SwitchListTile(
                        value: isPublic.value,
                        onChanged: (val) => isPublic.value = val,
                        title: const Text('Public Playlist', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isPublic.value ? 'Anyone can view this playlist' : 'Only you can view this playlist',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        ),
                        activeColor: Colors.white,
                        secondary: Icon(
                          isPublic.value ? Icons.public : Icons.lock_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    )),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        Obx(() => ElevatedButton(
                          onPressed: isSubmitting.value
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  isSubmitting.value = true;
                                  try {
                                    final created = await _playlistController.createPlayList(
                                      nameCtrl.text.trim(),
                                      isPublic: isPublic.value,
                                      description: descCtrl.text.trim(),
                                    );
                                    if (created != null) {
                                      _uploadController.selectedPlaylist.value = created.id;
                                      await _playlistController.refreshPlaylists();
                                      await _playlistController.refreshPublicPlaylists();
                                      if (dialogCtx.mounted) {
                                        Navigator.of(dialogCtx).pop();
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint('Error creating inline playlist: $e');
                                  } finally {
                                    isSubmitting.value = false;
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: isSubmitting.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text('Create Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Section 8: Playlist
  Widget _buildSection8Playlist(BuildContext context) {
    return Obx(() {
      final selectedPlaylistId = _uploadController.selectedPlaylist.value;

      // Combine playlists from user's playlists and public playlists without duplicates
      final combinedMap = <String, PlaylistModel>{};
      for (final p in _playlistController.allUserPlaylists) {
        combinedMap[p.id] = p;
      }
      for (final p in _playlistController.playlists) {
        combinedMap[p.id] = p;
      }
      for (final p in _playlistController.publicPlaylists) {
        combinedMap[p.id] = p;
      }
      final playlists = combinedMap.values.toList();
      final currentPlaylist = playlists.firstWhereOrNull((p) => p.id == selectedPlaylistId);

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '8. Playlist',
                  style: context.themeTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showCreatePlaylistModal(context),
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text(
                    'Create Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: playlists.any((p) => p.id == selectedPlaylistId) ? selectedPlaylistId : '',
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select Playlist to save video (Optional)',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
                fillColor: const Color(0xFF0F0F11),
                filled: true,
                prefixIcon: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 20),
                suffixIcon: selectedPlaylistId.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () => _uploadController.selectedPlaylist.value = '',
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              dropdownColor: const Color(0xFF161618),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    'None (Do not save to playlist)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                ...playlists.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Row(
                      children: [
                        Icon(
                          p.isPublic ? Icons.public : Icons.lock_outline,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.playlistName,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.videoCount > 0)
                          Text(
                            ' ${p.videoCount}v',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                _uploadController.selectedPlaylist.value = val ?? '';
              },
            ),
            if (currentPlaylist != null) ...[
              const SizedBox(height: 8),
              Text(
                '✓ Video will be automatically added to "${currentPlaylist.playlistName}" upon publishing.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // Section 9: Topic
  Widget _buildSection9Topic(BuildContext context) {
    return Obx(() {
      final selectedTopicId = _uploadController.selectedTopicId.value;
      final newTopicData = _uploadController.newTopicData;
      final hasNewTopicDraft = newTopicData.isNotEmpty;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Look up selected topic model if any
      Topic? selectedTopic;
      if (selectedTopicId.isNotEmpty && !hasNewTopicDraft && selectedTopicId != 'new_topic_draft') {
        selectedTopic = _uploadController.availableTopics.firstWhereOrNull(
          (t) => t.slug == selectedTopicId || t.id == selectedTopicId,
        );
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '9. Topic',
                  style: context.themeTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showCreateTopicModal(isDark),
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text(
                    'Create Topic',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasNewTopicDraft)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                newTopicData['title'] ?? 'New Topic Draft',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Draft',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${newTopicData['handle'] ?? ''} • ${newTopicData['category'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                      tooltip: 'Change Topic',
                      onPressed: () {
                        TopicSelectionBottomSheet.show(
                          context,
                          _uploadController,
                          onCreateNewTopic: _showCreateTopicModal,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      tooltip: 'Remove Topic',
                      onPressed: () {
                        _uploadController.newTopicData.clear();
                        _uploadController.selectedTopicId.value = '';
                      },
                    ),
                  ],
                ),
              )
            else if (selectedTopic != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    if (selectedTopic.thumbnailUrl != null && selectedTopic.thumbnailUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: selectedTopic.thumbnailUrl!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 42,
                            height: 42,
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(Icons.topic, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.topic, color: Colors.white, size: 20),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedTopic.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedTopic.handle} • ${FormatUtils.formatCount(selectedTopic.followerCount)} followers • ${FormatUtils.formatCount(selectedTopic.videoCount)} videos',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                      tooltip: 'Change Topic',
                      onPressed: () {
                        TopicSelectionBottomSheet.show(
                          context,
                          _uploadController,
                          onCreateNewTopic: _showCreateTopicModal,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      tooltip: 'Remove Topic',
                      onPressed: () {
                        _uploadController.selectedTopicId.value = '';
                      },
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () {
                  TopicSelectionBottomSheet.show(
                    context,
                    _uploadController,
                    onCreateNewTopic: _showCreateTopicModal,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.topic, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedTopicId.isNotEmpty ? selectedTopicId : 'Select Topic (Optional)',
                              style: TextStyle(
                                color: selectedTopicId.isNotEmpty
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            if (selectedTopicId.isEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Connect your video to a topic hub or category community',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (selectedTopicId.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 16),
                          onPressed: () => _uploadController.selectedTopicId.value = '',
                        )
                      else
                        const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  // Section 10: AI Features
  Widget _buildSection10AIFeatures(BuildContext context) {
    final subtitleSearchQuery = ''.obs;
    final dubbingSearchQuery = ''.obs;

    final allSubtitleLangs = supportedLanguages.map((l) => l.name).toList();

    final allDubbingLangs = [
      'English', 'Spanish', 'French', 'German', 'Hindi', 'Japanese', 'Chinese (Mandarin)',
      'Portuguese', 'Italian', 'Arabic', 'Russian', 'Korean', 'Turkish', 'Dutch', 'Swedish', 'Polish',
      'Bengali', 'Telugu', 'Tamil', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Urdu',
      'Indonesian', 'Thai', 'Vietnamese', 'Czech', 'Greek', 'Hebrew', 'Hungarian', 'Danish', 'Finnish',
      'Norwegian', 'Slovak', 'Bulgarian', 'Catalan', 'Croatian', 'Lithuanian', 'Slovenian', 'Afrikaans',
      'Tagalog', 'Malay', 'Persian', 'Romanian', 'Ukrainian', 'Estonian', 'Latvian', 'Serbian', 'Albanian',
      'Azerbaijani', 'Basque', 'Belarusian', 'Bosnian', 'Galician', 'Georgian', 'Icelandic', 'Irish',
      'Macedonian', 'Maltese', 'Nepali', 'Somali', 'Swahili', 'Welsh', 'Yiddish', 'Zulu', 'Kazakh', 'Uzbek'
    ];

    return Obx(() {
      final isFactCheck = _uploadController.aiFactCheckEnabled.value;
      final isSubtitles = _uploadController.aiGenerateSubtitles.value;
      final isDubbing = _uploadController.aiGenerateDubbing.value;
      final isDiarization = _uploadController.aiDiarizationEnabled.value;
      final isChapters = _uploadController.aiChaptersEnabled.value;
      final isSummary = _uploadController.aiSummaryEnabled.value;

      final selectedSubLangs = _uploadController.aiTranslationLanguages;
      final selectedDubLangs = _uploadController.aiDubbingLanguages;

      final filteredSubLangs = subtitleSearchQuery.value.isEmpty
          ? allSubtitleLangs
          : allSubtitleLangs.where((l) => l.toLowerCase().contains(subtitleSearchQuery.value.toLowerCase())).toList();

      final filteredDubLangs = dubbingSearchQuery.value.isEmpty
          ? allDubbingLangs
          : allDubbingLangs.where((l) => l.toLowerCase().contains(dubbingSearchQuery.value.toLowerCase())).toList();

      return Material(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '10. AI Features',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              // Auto-Generate Subtitles (100+ Languages)
              SwitchListTile(
                value: isSubtitles,
                onChanged: (val) => _uploadController.aiGenerateSubtitles.value = val,
                title: const Text('Auto-Generate Subtitles (100+ Languages)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Google Cloud Translation supported caption languages', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.subtitles, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              if (isSubtitles) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: (v) => subtitleSearchQuery.value = v,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search 100+ subtitle languages...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: filteredSubLangs.map((lang) {
                              final isSelected = selectedSubLangs.contains(lang);
                              return FilterChip(
                                selected: isSelected,
                                label: Text(lang, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
                                selectedColor: Colors.white,
                                backgroundColor: const Color(0xFF0F0F11),
                                onSelected: (_) {
                                  _uploadController.toggleSubtitleLanguage(lang);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: Colors.white10),

              // AI Audio Translation & Dubbing (70+ Languages)
              SwitchListTile(
                value: isDubbing,
                onChanged: (val) => _uploadController.aiGenerateDubbing.value = val,
                title: const Text('AI Audio Translation & Dubbing (70+ Languages)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Natural AI voice dubbing (Selecting dubbing auto-enables subtitles)', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.translate, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              if (isDubbing) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: (v) => dubbingSearchQuery.value = v,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search 70+ dubbing languages...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: filteredDubLangs.map((lang) {
                              final isSelected = selectedDubLangs.contains(lang);
                              return FilterChip(
                                selected: isSelected,
                                label: Text(lang, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
                                selectedColor: Colors.white,
                                backgroundColor: const Color(0xFF0F0F11),
                                onSelected: (_) {
                                  _uploadController.toggleDubbingLanguage(lang);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: Colors.white10),

              // Speaker Diarization
              SwitchListTile(
                value: isDiarization,
                onChanged: (val) => _uploadController.aiDiarizationEnabled.value = val,
                title: const Text('Speaker Diarization', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Identify and label multiple speakers', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.record_voice_over, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // Auto Chapters
              SwitchListTile(
                value: isChapters,
                onChanged: (val) => _uploadController.aiChaptersEnabled.value = val,
                title: const Text('Auto Chapters', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Generate smart video timestamp chapters', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.video_label, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // AI Summary
              SwitchListTile(
                value: isSummary,
                onChanged: (val) => _uploadController.aiSummaryEnabled.value = val,
                title: const Text('AI Video Summary', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Generate smart key takeaways overview', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(color: Colors.white10),

              // Truth Verification
              SwitchListTile(
                value: isFactCheck,
                onChanged: (val) => _uploadController.aiFactCheckEnabled.value = val,
                title: const Text('Truth Verification Analysis', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Enable automated fact-checking & claim verification', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                activeColor: Colors.white,
                secondary: const Icon(Icons.verified, color: Colors.white, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      );
    });
  }

  // Section 11: Creator Copyright & Rights Declaration
  Widget _buildSection11CopyrightDeclaration(BuildContext context) {
    return Obx(() {
      final isConfirmed = _uploadController.hasConfirmedCopyrightDeclaration.value;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isConfirmed
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConfirmed
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.12),
            width: isConfirmed ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '11. Creator Copyright & Rights Declaration',
                        style: context.themeTypography.title.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mandatory statutory confirmation before publishing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                _uploadController.hasConfirmedCopyrightDeclaration.value =
                    !_uploadController.hasConfirmedCopyrightDeclaration.value;
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isConfirmed
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isConfirmed,
                      onChanged: (val) {
                        _uploadController.hasConfirmedCopyrightDeclaration.value =
                            val ?? false;
                      },
                      activeColor: const Color(0xFF10B981),
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    "I confirm and declare that I own all rights to this video or have obtained all necessary statutory licenses, permissions, and authorizations to publish it. This video does not infringe upon any third-party copyright, trademark, privacy, or proprietary rights, and strictly complies with Truthworld's ",
                              ),
                              WidgetSpan(
                                child: InkWell(
                                  onTap: () => Get.toNamed('/terms'),
                                  child: const Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              WidgetSpan(
                                child: InkWell(
                                  onTap: () => Get.toNamed('/community-guidelines'),
                                  child: const Text(
                                    'Community Guidelines',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Footer Actions for Desktop matching Create Playlist
  Widget _buildPlaylistStyleFooterActions(BuildContext context) {
    return Obx(() {
      final isUploading = _uploadController.isUploading.value;
      final canPublish = _canPublishVideo();

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: Get.back,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _handleVideoUpload(isDraft: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save Draft'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: canPublish ? _handleVideoUpload : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _uploadController.isProcessing.value
                  ? 'Publishing...'
                  : (isUploading
                      ? 'Publish (Uploading...)'
                      : 'Publish Video'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    });
  }

  // Footer Actions for Mobile matching Create Playlist
  Widget _buildPlaylistStyleMobileFooter(BuildContext context) {
    return Obx(() {
      final isUploading = _uploadController.isUploading.value;
      final canPublish = _canPublishVideo();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: canPublish ? _handleVideoUpload : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _uploadController.isProcessing.value
                  ? 'Publishing...'
                  : (isUploading
                      ? 'Publish (Uploading...)'
                      : 'Publish Video'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    });
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
        AppSnackbar.show(
          'Success',
          'Topic draft created! It will be published along with your video.',
          backgroundColor: AppColors.success,
          colorText: AppColors.textPrimary,
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
            final selected = _uploadController.channels.firstWhereOrNull(
              (channel) => channel.channelId == value,
            );
            if (selected != null) {
              _uploadController.selectChannel(selected);
              HapticFeedback.lightImpact();
            }
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
