import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_popup_menu.dart';

/// Responsive grid layout rendering the channel's topics with cards and context menus.
class TopicGridView extends StatelessWidget {
  final List<Topic> topics;
  final TopicManagementController controller;

  const TopicGridView({
    required this.topics,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        final double childAspectRatio;

        if (width >= 1200) {
          crossAxisCount = 4;
          childAspectRatio = 0.95;
        } else if (width >= 800) {
          crossAxisCount = 3;
          childAspectRatio = 0.90;
        } else if (width >= 550) {
          crossAxisCount = 2;
          childAspectRatio = 0.85;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 1.25;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return TopicCardWidget(
              topic: topic,
              isDashboard: true,
              showEditOption: false,
              trailing: TopicPopupMenu(
                topic: topic,
                controller: controller,
              ),
            );
          },
        );
      },
    );
  }
}
