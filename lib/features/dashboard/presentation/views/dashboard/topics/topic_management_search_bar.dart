import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio search input bar for searching topics by title, handle, or category.
class TopicManagementSearchBar extends StatelessWidget {
  final TopicManagementController controller;

  const TopicManagementSearchBar({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final query = controller.searchQuery.value;
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: query.isNotEmpty ? AppColors.brand : AppColors.bgDivider,
            width: query.isNotEmpty ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          maxLength: ContentValidator.defaultMaxSearchLength,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: TruthworldTextInputFormatters.withLimit(
            ContentValidator.defaultMaxSearchLength,
          ),
          onChanged: (val) => controller.searchQuery.value = val,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search topics by title, handle, or category...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 20,
            ),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white),
                    onPressed: () => controller.searchQuery.value = '',
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    });
  }
}
