import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/create_content_components.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_channel_selector.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_community_flow.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_ai_section.dart';
export 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_copyright_section.dart';
export 'package:truthworld/features/video/presentation/views/upload/widgets/create_playlist_modal.dart';

/// Create Content Screen - Declarative single-page studio view for Video and Community uploads
class CreateContentScreen extends StatelessWidget {
  const CreateContentScreen({
    required this.uploadType,
    this.existingVideo,
    this.tag,
    super.key,
  });

  final UploadType uploadType;
  final Video? existingVideo;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final createContentTag = tag ?? uploadType.name;
    final contentController = Get.put(
      CreateContentController(
        uploadType: uploadType,
        existingVideo: existingVideo,
      ),
      tag: createContentTag,
    );
    final uploadController = contentController.uploadController;

    return Obx(() {
      if (uploadController.isChannelsLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (uploadController.channels.isEmpty) {
        final authChannel = AuthService.to.userChannel;
        if (authChannel != null && authChannel.status != ChannelStatus.deleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (uploadController.channels.isEmpty) {
              uploadController.channels.value = [authChannel];
              uploadController.selectedChannel.value = authChannel;
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: CreateContentNoChannelsCard(),
            ),
          ),
        );
      }

      final channel = uploadController.selectedChannel.value;
      if (channel == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (channel.status != ChannelStatus.active) {
        return Scaffold(
          backgroundColor: context.colors.background,
          body: Center(
            child: SingleChildScrollView(
              child: CreateContentBlockedUploadCard(channel: channel),
            ),
          ),
        );
      }

      if (uploadType == UploadType.video) {
        return CreateContentVideoLayout(
          uploadController: uploadController,
          contentController: contentController,
          isDark: isDark,
        );
      }

      final isMobile = MediaQuery.of(context).size.width < 768;

      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: const Text('Community Post'),
          backgroundColor: context.colors.appBarSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: Get.back,
          ),
        ),
        body: SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: context.layoutTokens.contentMaxWidth,
            ),
            margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
            child: CreateContentCommunityFlow(
              uploadController: uploadController,
              communityTitleController: contentController.communityTitleController,
              communityDescriptionController: contentController.communityDescriptionController,
              communityTagsController: contentController.communityTagsController,
              onPublishCommunity: contentController.handleCommunityUpload,
              isDark: isDark,
              isMobile: isMobile,
            ),
          ),
        ),
      );
    });
  }
}

// Deferred loading support for route splitting
Future<void> loadLibrary() => Future.value();
