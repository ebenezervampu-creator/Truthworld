import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_video_player.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/admin/presentation/views/widgets/admin_video_player.dart';

/// Formatting helper for timestamps across admin tabs
String formatAdminTimestamp(dynamic val) {
  if (val == null) return 'N/A';
  DateTime? dt;
  if (val is Timestamp) {
    dt = val.toDate();
  } else if (val is String) {
    dt = DateTime.tryParse(val);
  }
  if (dt == null) return 'N/A';
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
}

/// Helper to render queue filter choice chips
class AdminFilterChip extends StatelessWidget {
  final AdminController controller;
  final String value;
  final String label;
  final RxString targetProperty;

  const AdminFilterChip({
    required this.controller,
    required this.value,
    required this.label,
    required this.targetProperty,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = targetProperty.value == value;
      return ChoiceChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: Colors.white,
        backgroundColor: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
        labelStyle: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: Colors.black,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
        onSelected: (selected) {
          if (selected) {
            targetProperty.value = value;
          }
        },
      );
    });
  }
}

/// Helper to render status badges across admin review queues
class AdminStatusBadge extends StatelessWidget {
  final String status;

  const AdminStatusBadge({
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var color = AppColors.textPrimary;
    final txt = status.toUpperCase();

    if (txt == 'APPROVED' ||
        txt == 'PUBLISHED' ||
        txt == 'ACTIVE' ||
        txt == 'PASSED' ||
        txt == 'SUCCESS' ||
        txt == 'RESOLVED_DISMISSED' ||
        txt == 'RESOLVED') {
      color = AppColors.success;
    } else if (txt == 'REJECTED' ||
        txt == 'ERROR' ||
        txt == 'FAILED' ||
        txt == 'RESOLVED_REJECTED') {
      color = AppColors.error;
    } else if (txt.contains('HOLD') ||
        txt == 'ONHOLD' ||
        txt == 'ON_HOLD' ||
        txt == 'HELD') {
      color = AppColors.warning;
    } else if (txt.contains('PENDING') ||
        txt.contains('FLAGGED') ||
        txt.contains('VERIFICATION') ||
        txt.contains('REVIEW') ||
        txt == 'PROCESSING' ||
        txt == 'UNDERREVIEW') {
      color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Helper to render SafeSearch score badges
class AdminSafeSearchChip extends StatelessWidget {
  final String label;
  final dynamic val;

  const AdminSafeSearchChip({
    required this.label,
    required this.val,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(val?.toString() ?? '0') ?? 0;
    var scoreColor = AppColors.success;
    if (score >= 3) scoreColor = AppColors.warning;
    if (score >= 5) scoreColor = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: scoreColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to render a key-value metadata table
class AdminMetadataTable extends StatelessWidget {
  final List<MetadataRow> rows;

  const AdminMetadataTable({
    required this.rows,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: rows.map((row) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
              child: Text(
                row.label,
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                row.value,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

String extractAdminImageUrl(Map<String, dynamic> img) {
  if (img['images'] is List && (img['images'] as List).isNotEmpty) {
    final first = (img['images'] as List).first;
    if (first != null && first.toString().trim().isNotEmpty) {
      return first.toString().trim();
    }
  }
  for (final key in [
    'imageUrl',
    'avatarUrl',
    'bannerUrl',
    'coverImageUrl',
    'coverUrl',
    'mediaUrl',
    'url',
    'image',
    'photoUrl',
    'thumbnailUrl',
    'thumbnail',
    'photo',
    'posterUrl',
    'downloadUrl',
    'processedUrl',
    'attachmentUrl',
    'gcsUri',
    'filePath',
    'gcsPath',
  ]) {
    final val = img[key];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
  }
  return '';
}

String getAdminImagePostStatusDisplay(
  AdminController controller,
  Map<String, dynamic> img,
) {
  if (controller.isImagePostRejected(img)) {
    return 'REJECTED';
  }
  if (controller.isImagePostPending(img)) {
    final s = (img['status'] ?? img['moderation']?['status'] ?? 'PENDING')
        .toString()
        .toUpperCase();
    if (s == 'VERIFICATIONREJECTED' || s == 'VERIFICATION_REJECTED') {
      return 'FLAGGED (AI)';
    }
    if (s == 'FLAGGED' || s == 'FLAGGED_FOR_REVIEW') {
      return 'FLAGGED';
    }
    return s;
  }
  if (controller.isImagePostApproved(img)) {
    return 'APPROVED';
  }
  return (img['status'] ?? 'PENDING').toString().toUpperCase();
}
