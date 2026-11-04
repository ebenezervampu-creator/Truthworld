import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Underline tab bar for Subtitles workspace matching Audio & Video design.
class SubtitlesNavTabs extends StatelessWidget {
  const SubtitlesNavTabs({
    required this.controller,
    super.key,
  });

  final SubtitlesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeTab = controller.selectedMainTab.value;

      return Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.bgSurface)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTab(
                title: 'Subtitles',
                isActive: activeTab == 0,
                onTap: () => controller.selectedMainTab.value = 0,
              ),
              const SizedBox(width: 24),
              _buildTab(
                title: 'Transcripts',
                isActive: activeTab == 1,
                onTap: () => controller.selectedMainTab.value = 1,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.info : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
