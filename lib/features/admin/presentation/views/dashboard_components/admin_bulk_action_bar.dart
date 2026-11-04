import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminBulkActionBar extends StatelessWidget {
  const AdminBulkActionBar({required this.controller, super.key});
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.selectedItemIds.length;
      final tab = controller.currentTab.value;
      final contentType = tab == 'images'
          ? 'image'
          : (tab == 'topics'
              ? 'topic'
              : (tab == 'channels'
                  ? 'channel'
                  : 'video'));

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count selected',
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: controller.clearSelection,
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                label: const Text(
                  'Deselect All',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              // Reject Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: controller.isBulkActionSubmitting.value
                    ? null
                    : () => controller.bulkModerate(
                          contentType,
                          'reject',
                          'Bulk rejection by administrator',
                        ),
                icon: const Icon(Icons.block, color: Colors.white, size: 16),
                label: const Text(
                  'Bulk Reject',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              // Approve Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: controller.isBulkActionSubmitting.value
                    ? null
                    : () => controller.bulkModerate(
                          contentType,
                          'approve',
                          'Bulk approval by administrator',
                        ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text(
                  'Bulk Approve',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
