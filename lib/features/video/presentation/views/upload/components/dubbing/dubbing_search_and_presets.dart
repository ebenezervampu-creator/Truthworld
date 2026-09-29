import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Search, category filters, and quick language presets.
class DubbingSearchAndPresets extends StatelessWidget {
  const DubbingSearchAndPresets({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchAndFilters(controller),
        const SizedBox(height: 14),
        _buildPresetsRow(controller),
      ],
    );
  }

  Widget _buildSearchAndFilters(UploadDubbingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (val) => controller.searchQuery.value = val,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search 70+ dubbing languages (e.g. Hindi, Spanish, French)...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12.5,
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.white, size: 18),
            fillColor: const Color(0xFF141418),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Category Filter Chips
        Obx(() {
          final current = controller.selectedCategoryFilter.value;
          final selectedCount = controller.selectedLanguages.length;
          final categories = [
            {'id': 'all', 'label': 'All (70+)'},
            if (selectedCount > 0)
              {'id': 'selected', 'label': 'Selected ($selectedCount)'},
            {'id': 'popular', 'label': 'Popular'},
            {'id': 'indic', 'label': 'Indian (Indic)'},
            {'id': 'european', 'label': 'European'},
            {'id': 'asian', 'label': 'Asian & Pacific'},
            {'id': 'middle_east_africa', 'label': 'Middle East & Africa'},
          ];

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = current == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(
                      cat['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      controller.selectedCategoryFilter.value = cat['id']!;
                    },
                    selectedColor: Colors.white,
                    backgroundColor: const Color(0xFF141418),
                    checkmarkColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPresetsRow(UploadDubbingController controller) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildPresetButton(
          title: '+ Top 5 Global',
          onTap: controller.selectTopGlobal,
        ),
        _buildPresetButton(
          title: '+ Top Indic',
          onTap: controller.selectTopIndic,
        ),
        _buildPresetButton(
          title: '+ Top European',
          onTap: controller.selectTopEuropean,
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}
