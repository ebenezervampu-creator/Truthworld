import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart' as search;
import 'package:truthworld/theme/app_theme.dart';

class SearchFilterChips extends StatelessWidget {
  final search.SearchController controller = Get.find<search.SearchController>();

  SearchFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip('All', 'all'),
          _buildChip('Videos', 'video'),
          _buildChip('Channels', 'channel'),
          _buildChip('Playlists', 'playlist'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Obx(() {
      final isSelected = controller.selectedSearchType.value == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              controller.updateSearchType(value);
            }
          },
          selectedColor: Colors.white,
          backgroundColor: AppColors.bgSurfaceHover,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: isSelected ? 4 : 0,
          pressElevation: 8,
        ),
      );
    });
  }
}
