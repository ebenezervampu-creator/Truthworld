import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dashed border painter for the dropzone container.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double gap;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 12,
    this.gap = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = gap;
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += length * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.gap != gap;
  }
}

/// Image picker dropzone and preview card for community post media.
class CommunityImagePickerDropzone
    extends GetView<CommunityPostUploadController> {
  const CommunityImagePickerDropzone({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final images = controller.pickedImages;
      final imageUrls = controller.imageUrls;

      if (images.isNotEmpty || imageUrls.isNotEmpty) {
        return const SelectedImagePreviewCard();
      }

      return CustomPaint(
        painter: DashedBorderPainter(
          color: context.colors.divider,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: AppColors.textPrimary, // White icon only
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Drag & drop your image here',
                style: context.twTypography.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'or',
                style: context.twTypography.caption.copyWith(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: controller.pickImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.surfaceContainerHigh,
                  foregroundColor: context.colors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: context.colors.divider,
                    ),
                  ),
                ),
                child: Text(
                  'Choose file',
                  style: context.twTypography.button.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'JPG, PNG, WEBP up to 10MB',
                style: context.twTypography.caption.copyWith(
                  fontSize: 11,
                  color: context.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Preview card displaying the selected or uploaded image with status & remove button.
class SelectedImagePreviewCard
    extends GetView<CommunityPostUploadController> {
  const SelectedImagePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: context.colors.surfaceContainer,
                  child: _buildThumbnail(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.pickedImages.isNotEmpty
                          ? controller.pickedImages.first.name
                          : 'Uploaded Image',
                      style: context.twTypography.title.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.pickedImages.isNotEmpty
                          ? '${(controller.pickedImages.first.size / (1024 * 1024)).toStringAsFixed(2)} MB'
                          : 'Ready',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    _buildModerationStatus(),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => controller.removeImage(0),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary, // White icon
                  size: 20,
                ),
                tooltip: 'Remove image',
              ),
            ],
          ),
          Obx(() {
            if (!controller.isUploading.value) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: controller.overallProgress.value,
                  backgroundColor: context.colors.surfaceContainer,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (controller.pickedImages.isNotEmpty) {
      final path = controller.pickedImages.first.path;
      if (kIsWeb) {
        return CachedNetworkImage(
          imageUrl: path ?? '',
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const Icon(
            Icons.image_outlined,
            color: AppColors.textPrimary,
          ),
        );
      } else if (path != null) {
        return Image.file(
          io.File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(
            Icons.image_outlined,
            color: AppColors.textPrimary,
          ),
        );
      }
    } else if (controller.imageUrls.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: controller.imageUrls.first,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const Icon(
          Icons.image_outlined,
          color: AppColors.textPrimary,
        ),
      );
    }
    return const Icon(
      Icons.image_outlined,
      color: AppColors.textPrimary,
    );
  }

  Widget _buildModerationStatus() {
    return Obx(() {
      final status = controller.moderationStatuses[0];
      final reason = controller.moderationReasons[0] ?? '';
      if (status == 'REJECTED') {
        return Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Rejected: $reason',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else if (status == 'APPROVED') {
        return const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'Verified',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (status == 'PENDING') {
        return const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'Verifying in background...',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }
}
