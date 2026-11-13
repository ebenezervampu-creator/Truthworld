import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/create_content_footer_actions.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/create_content_page_header.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_ai_section.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_category_visibility_sections.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_media_sections.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_metadata_sections.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_playlist_topic_sections.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Full Video Upload Studio Single-Page Layout (Desktop 2-Column, Mobile 1-Column)
class CreateContentVideoLayout extends StatelessWidget {
  const CreateContentVideoLayout({
    required this.contentController,
    required this.uploadController,
    required this.isDark,
    super.key,
  });

  final CreateContentController contentController;
  final UploadController uploadController;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: Column(
              children: [
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
                            CreateContentPageHeader(
                              uploadController: uploadController,
                              isDesktop: isWide,
                            ),
                            const SizedBox(height: 24),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column (Sections 1-5: Thumbnail, Video File, Title, Description, Tags)
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CreateContentThumbnailSection(
                                          uploadController: uploadController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentVideoFileSection(
                                          uploadController: uploadController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentTitleSection(
                                          titleController: contentController.titleController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentDescriptionSection(
                                          descriptionController: contentController.descriptionController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentTagsSection(
                                          tagsController: contentController.tagsController,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 32),

                                  // Right Column (Sections 6-10: Category, Visibility, Playlist, Topic, AI Features & Intelligence)
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CreateContentCategorySection(
                                          uploadController: uploadController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentVisibilitySection(
                                          uploadController: uploadController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentPlaylistSection(
                                          uploadController: uploadController,
                                          playlistController: contentController.playlistController,
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentTopicSection(
                                          uploadController: uploadController,
                                          onCreateNewTopic: (isDark) =>
                                              contentController.showCreateTopicModal(context, isDark),
                                        ),
                                        const SizedBox(height: 20),
                                        CreateContentUnifiedAiSection(
                                          uploadController: uploadController,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CreateContentThumbnailSection(
                                    uploadController: uploadController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentVideoFileSection(
                                    uploadController: uploadController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentTitleSection(
                                    titleController: contentController.titleController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentDescriptionSection(
                                    descriptionController: contentController.descriptionController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentTagsSection(
                                    tagsController: contentController.tagsController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentCategorySection(
                                    uploadController: uploadController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentVisibilitySection(
                                    uploadController: uploadController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentPlaylistSection(
                                    uploadController: uploadController,
                                    playlistController: contentController.playlistController,
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentTopicSection(
                                    uploadController: uploadController,
                                    onCreateNewTopic: (isDark) =>
                                        contentController.showCreateTopicModal(context, isDark),
                                  ),
                                  const SizedBox(height: 20),
                                  CreateContentUnifiedAiSection(
                                    uploadController: uploadController,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 32),
                            if (isWide)
                              CreateContentDesktopFooterActions(
                                contentController: contentController,
                                uploadController: uploadController,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isWide)
                  CreateContentMobileFooterActions(
                    contentController: contentController,
                    uploadController: uploadController,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
