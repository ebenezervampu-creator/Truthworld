import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    super.key,
  });

  final bool isDarkMode;
  final Future<List<Map<String, dynamic>>> channelVideosFuture;
  final Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted;

  /// Helper launcher method for opening Topic Creation as a full-screen page route.
  static Future<void> show({
    required BuildContext context,
    required bool isDarkMode,
    required Future<List<Map<String, dynamic>>> channelVideosFuture,
    required Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted,
  }) async {
    final controller = Get.isRegistered<CreateTopicController>()
        ? Get.find<CreateTopicController>()
        : Get.put(CreateTopicController());
    controller.resetForm();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: CreateTopicDialog(
              isDarkMode: isDarkMode,
              channelVideosFuture: channelVideosFuture,
              onCreateTopicSubmitted: onCreateTopicSubmitted,
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> availableCategories = [
    'Science & Technology',
    'Technology',
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion',
  ];

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
            if (isDesktop) buildCreateTopicDesktopTopHeader(context),
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
                            _buildDesktopTwoColumnLayout(context, controller)
                          else
                            _buildMobileSingleColumnLayout(context, controller),
                          const SizedBox(height: 24),
                          buildSection9TopicImage(context, controller, channelVideosFuture),
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
  Widget _buildDesktopTwoColumnLayout(BuildContext context, CreateTopicController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Sections 1 to 5)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSection1TopicName(context, controller),
              const SizedBox(height: 24),
              buildSection2Handle(context, controller),
              const SizedBox(height: 24),
              buildSection3Title(context, controller),
              const SizedBox(height: 24),
              buildSection4Description(context, controller),
              const SizedBox(height: 24),
              buildSection5Tags(context, controller),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right Column (Sections 6 to 8)
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSection6Category(context, controller, availableCategories),
              const SizedBox(height: 24),
              buildSection7TopicType(context, controller),
              const SizedBox(height: 24),
              buildSection8AddVideos(context, controller, channelVideosFuture),
            ],
          ),
        ),
      ],
    );
  }

  // ================= Mobile Single Column Layout =================
  Widget _buildMobileSingleColumnLayout(BuildContext context, CreateTopicController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection1TopicName(context, controller),
        const SizedBox(height: 20),
        buildSection2Handle(context, controller),
        const SizedBox(height: 20),
        buildSection3Title(context, controller),
        const SizedBox(height: 20),
        buildSection4Description(context, controller),
        const SizedBox(height: 20),
        buildSection5Tags(context, controller),
        const SizedBox(height: 20),
        buildSection6Category(context, controller, availableCategories),
        const SizedBox(height: 20),
        buildSection7TopicType(context, controller),
        const SizedBox(height: 20),
        buildSection8AddVideos(context, controller, channelVideosFuture),
      ],
    );
  }
}
