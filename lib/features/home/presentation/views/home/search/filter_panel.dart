import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/home/presentation/views/home/search/search.dart';

class FilterPanel extends StatelessWidget {
  final ColorScheme colorScheme;
  final BoxConstraints constraints;
  final ModernSearchController controller;

  const FilterPanel({
    super.key,
    required this.colorScheme,
    required this.constraints,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = constraints.maxWidth < 600;

    return Obx(() {
      if (!controller.showFilters.value) return const SizedBox.shrink();

      return Positioned(
        top: 0,
        right: 0,
        bottom: 0,
        width: isMobile ? constraints.maxWidth * 0.85 : 300,
        child: AnimatedBuilder(
          animation: controller.filterAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                (1 - controller.filterAnimation.value) *
                    (isMobile ? constraints.maxWidth * 0.85 : 300),
                0,
              ),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(kBorderRadius),
                bottomLeft: Radius.circular(kBorderRadius),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(height: 1, color: Colors.white12),
                Expanded(child: _buildFilterList()),
                const Divider(height: 1, color: Colors.white12),
                _buildButtons(),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(kMediumPadding),
      child: Row(
        children: [
          Text(
            'Filters',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: controller.toggleFilters,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterList() {
    return ListView(
      padding: EdgeInsets.all(kMediumPadding),
      children: [
        _buildFilterSection('Date', [
          'Today',
          'This Week',
          'This Month',
          'This Year',
        ], controller.selectedDateFilter),
        const SizedBox(height: kMediumPadding),
        _buildFilterSection('Views', [
          'Under 1K',
          '1K-10K',
          '10K-100K',
          '100K-1M',
          'Over 1M',
        ], controller.selectedViewsFilter),
        const SizedBox(height: kMediumPadding),
        _buildFilterSection('Duration', [
          'Short',
          'Medium',
          'Long',
        ], controller.selectedDurationFilter),
        const SizedBox(height: kMediumPadding),
        _buildFilterSection('Type', [
          'Video',
          'Channel',
          'Playlist',
        ], controller.selectedTypeFilter),
      ],
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    RxString selectedValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: kSmallPadding),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return Obx(() {
              final isSelected = selectedValue.value == option;
              return FilterChip(
                selected: isSelected,
                label: Text(option),
                onSelected: (selected) {
                  selectedValue.value = selected ? option : '';
                },
                selectedColor: kPrimaryColor,
                checkmarkColor: Colors.white,
                backgroundColor: AppTheme.colors.surfaceContainerHighest,
                labelStyle: GoogleFonts.roboto(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kBorderRadius - 4),
                ),
              );
            });
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: EdgeInsets.all(kMediumPadding),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                controller.selectedDateFilter.value = '';
                controller.selectedViewsFilter.value = '';
                controller.selectedDurationFilter.value = '';
                controller.selectedTypeFilter.value = '';
                controller.searchContent();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colors.surfaceContainerHighest,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kBorderRadius),
                ),
              ),
              child: Text(
                'Clear All',
                style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: kMediumPadding),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                controller.searchContent();
                controller.toggleFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kBorderRadius),
                ),
              ),
              child: Text(
                'Apply',
                style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}





