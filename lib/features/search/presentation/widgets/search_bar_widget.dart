import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_controller;
import 'package:truthworld/theme/app_theme.dart';
import 'search_widgets.dart';

class SearchBarWidget extends StatelessWidget {
  final search_controller.SearchController controller = Get.find<search_controller.SearchController>();
  final TextEditingController textController = TextEditingController();

  SearchBarWidget({super.key}) {
    // Sync text controller with Rx search query
    textController.text = controller.searchQuery.value;
    controller.searchQuery.listen((val) {
      if (textController.text != val) {
        textController.text = val;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: textController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search videos, creators...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: Obx(() => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        textController.clear();
                        controller.clearSearch();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
                    onPressed: () {
                      Get.bottomSheet(
                        AdvancedFilterSheet(),
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                      );
                    },
                  ),
                ],
              )),
        ),
        onChanged: (val) => controller.onSearchChanged(val),
        onSubmitted: (val) => controller.onSearchChanged(val),
      ),
    );
  }
}
