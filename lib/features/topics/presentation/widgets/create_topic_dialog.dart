import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic/create_topic_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'create_topic/create_topic_widgets.dart';

/// Topic Creation Component matching Create Playlist Screen Design System 1:1
class CreateTopicDialog extends StatelessWidget {
  const CreateTopicDialog({
    required this.isDarkMode,
    required this.channelVideosFuture,
    required this.onCreateTopicSubmitted,
    this.isFromUpload = false,
    super.key,
  });

  final bool isDarkMode;
  final Future<List<Map<String, dynamic>>> channelVideosFuture;
  final Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted;
  final bool isFromUpload;

  /// Helper launcher method for opening Topic Creation as a full-screen page route.
  static Future<void> show({
    required BuildContext context,
    required bool isDarkMode,
    required Future<List<Map<String, dynamic>>> channelVideosFuture,
    required Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted,
    bool isFromUpload = false,
  }) async {
    final controller = Get.isRegistered<CreateTopicController>()
        ? Get.find<CreateTopicController>()
        : Get.put(CreateTopicController());
    controller.resetForm();
    controller.isFromUpload.value = isFromUpload;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: CreateTopicDialog(
              isDarkMode: isDarkMode,
              isFromUpload: isFromUpload,
              channelVideosFuture: channelVideosFuture,
              onCreateTopicSubmitted: onCreateTopicSubmitted,
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> availableCategories = AppCategories.allCategories;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CreateTopicController>()
        ? Get.find<CreateTopicController>()
        : Get.put(CreateTopicController());

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48.0 : 16.0,
                  vertical: 24.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Form(
                      key: controller.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildCreateTopicPageHeader(context, isDesktop: isDesktop),
                          const SizedBox(height: 24),
                          buildCreateTopicProfanityAlert(controller),
                          if (isDesktop)
                            _buildDesktopTwoColumnLayout(context, controller, isFromUpload)
                          else
                            _buildMobileSingleColumnLayout(context, controller, isFromUpload),
                          const SizedBox(height: 24),
                          buildSection9TopicImage(context, controller, channelVideosFuture, isFromUpload: isFromUpload),
                          const SizedBox(height: 32),
                          if (isDesktop)
                            buildCreateTopicDesktopFooterActions(
                              context,
                              controller,
                              onCreateTopicSubmitted,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!isDesktop)
              buildCreateTopicMobileStickyFooter(
                context,
                controller,
                onCreateTopicSubmitted,
              ),
          ],
        ),
      ),
    );
  }

  // ================= Desktop 2-Column Layout =================
  Widget _buildDesktopTwoColumnLayout(
    BuildContext context,
    CreateTopicController controller,
    bool isFromUpload,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Sections 1 to 3)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSection1TopicName(context, controller),
              const SizedBox(height: 24),
              buildSection2Handle(context, controller),
              const SizedBox(height: 24),
              buildSection3Description(context, controller, isDesktop: true),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right Column (Sections 4 to 7)
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSection5Category(context, controller, availableCategories),
              const SizedBox(height: 24),
              buildSection6TopicType(context, controller),
              const SizedBox(height: 24),
              buildSection7Tags(context, controller),
              const SizedBox(height: 24),
              buildSection8AddVideos(context, controller, channelVideosFuture, isFromUpload: isFromUpload),
            ],
          ),
        ),
      ],
    );
  }

  // ================= Mobile Single Column Layout =================
  Widget _buildMobileSingleColumnLayout(
    BuildContext context,
    CreateTopicController controller,
    bool isFromUpload,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection1TopicName(context, controller),
        const SizedBox(height: 20),
        buildSection2Handle(context, controller),
        const SizedBox(height: 20),
        buildSection3Description(context, controller),
        const SizedBox(height: 20),
        buildSection5Category(context, controller, availableCategories),
        const SizedBox(height: 20),
        buildSection6TopicType(context, controller),
        const SizedBox(height: 20),
        buildSection7Tags(context, controller),
        const SizedBox(height: 20),
        buildSection8AddVideos(context, controller, channelVideosFuture, isFromUpload: isFromUpload),
      ],
    );
  }
}
