import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart' as search;
import 'package:truthworld/theme/app_theme.dart';

class AdvancedFilterSheet extends StatelessWidget {
  final search.SearchController controller = Get.find<search.SearchController>();

  AdvancedFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(color: Colors.white10),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Sort By'),
                  _buildOptionsRow([
                    _Option('Relevance', 'relevance', controller.selectedSortBy),
                    _Option('Upload Date', 'date', controller.selectedSortBy),
                    _Option('View Count', 'views', controller.selectedSortBy),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Upload Date'),
                  _buildOptionsWrap([
                    _Option('Any time', 'any', controller.selectedUploadDate),
                    _Option('Today', 'today', controller.selectedUploadDate),
                    _Option('This week', 'week', controller.selectedUploadDate),
                    _Option('This month', 'month', controller.selectedUploadDate),
                    _Option('This year', 'year', controller.selectedUploadDate),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Type'),
                  _buildOptionsRow([
                    _Option('All', 'all', controller.selectedSearchType),
                    _Option('Video', 'video', controller.selectedSearchType),
                    _Option('Channel', 'channel', controller.selectedSearchType),
                    _Option('Playlist', 'playlist', controller.selectedSearchType),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Duration'),
                  _buildOptionsWrap([
                    _Option('Any', 'any', controller.selectedDuration),
                    _Option('Short (< 4m)', 'short', controller.selectedDuration),
                    _Option('Medium (4-20m)', 'medium', controller.selectedDuration),
                    _Option('Long (> 20m)', 'long', controller.selectedDuration),
                  ]),
                  const SizedBox(height: 32),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Search Filters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () => controller.resetFilters(),
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildOptionsRow(List<_Option> options) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) => _buildOptionChip(opt)).toList(),
      ),
    );
  }

  Widget _buildOptionsWrap(List<_Option> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) => _buildOptionChip(opt)).toList(),
    );
  }

  Widget _buildOptionChip(_Option opt) {
    return Obx(() {
      final isSelected = opt.observable.value == opt.value;
      return GestureDetector(
        onTap: () {
          if (opt.observable == controller.selectedSortBy) controller.updateSortBy(opt.value);
          if (opt.observable == controller.selectedUploadDate) controller.updateUploadDate(opt.value);
          if (opt.observable == controller.selectedSearchType) controller.updateSearchType(opt.value);
          if (opt.observable == controller.selectedDuration) controller.updateDuration(opt.value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white10,
              width: 1,
            ),
          ),
          child: Text(
            opt.label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildActionButtons(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Get.back(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _Option {
  final String label;
  final String value;
  final RxString observable;

  _Option(this.label, this.value, this.observable);
}
