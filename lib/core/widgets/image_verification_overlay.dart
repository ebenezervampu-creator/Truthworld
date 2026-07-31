import 'package:flutter/material.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Extracts the unique image verification docId from a Firebase Storage URL.
String? getVerificationDocId(String url) {
  if (url.isEmpty) return null;
  try {
    // A typical Firebase Storage URL contains the encoded path in the URL query/segments.
    // E.g. .../o/thumbnails%2FuserId%2Ffilename.jpg?...
    final decoded = Uri.decodeComponent(url);
    final uri = Uri.parse(decoded);
    final path = uri.path;
    final lastSegment = path.split('/').last;
    if (lastSegment.contains('.')) {
      return lastSegment;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// A premium, non-blocking overlay that overlays image verification status on any widget.
class ImageVerificationOverlay extends StatelessWidget {
  const ImageVerificationOverlay({
    required this.imageUrl,
    required this.child,
    super.key,
    this.borderRadius = 8.0,
  });
  final String imageUrl;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final docId = getVerificationDocId(imageUrl);
    if (docId == null) {
      return child;
    }

    final imageService = ImageVerificationService();
    final twColors = context.colors;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: StreamBuilder<VerificationResult>(
            stream: imageService.streamVerificationStatus(docId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final result = snapshot.data!;

              if (result.status == VerificationStatus.pending) {
                return _buildOverlay(
                  context: context,
                  color: twColors.info,
                  icon: Icons.hourglass_empty_rounded,
                  label: 'Verifying...',
                  isPending: true,
                );
              } else if (result.status == VerificationStatus.rejected ||
                  result.status == VerificationStatus.error) {
                return _buildOverlay(
                  context: context,
                  color: twColors.error,
                  icon: Icons.block_rounded,
                  label: 'Rejected: ${result.reason}',
                  isPending: false,
                );
              } else if (result.status == VerificationStatus.flagged) {
                return _buildOverlay(
                  context: context,
                  color: twColors.warning,
                  icon: Icons.warning_rounded,
                  label: 'Flagged: ${result.reason}',
                  isPending: false,
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
    required bool isPending,
  }) {
    final twSpacing = context.spacing;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: isPending
            ? AppColors.bgPage.withValues(alpha: 0.3)
            : AppColors.bgPage.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(twSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPending)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textPrimary,
                      ),
                    ),
                  )
                else
                  Icon(icon, size: 12, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
