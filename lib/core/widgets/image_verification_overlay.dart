import 'package:flutter/material.dart';
import 'package:truthworld/core/services/image_verification_service.dart';

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
  final String imageUrl;
  final Widget child;
  final double borderRadius;

  const ImageVerificationOverlay({
    super.key,
    required this.imageUrl,
    required this.child,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final docId = getVerificationDocId(imageUrl);
    if (docId == null) {
      return child;
    }

    final imageService = ImageVerificationService();

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
                  color: const Color(0xFF3B82F6),
                  icon: Icons.hourglass_empty_rounded,
                  label: 'Verifying...',
                  isPending: true,
                );
              } else if (result.status == VerificationStatus.rejected ||
                  result.status == VerificationStatus.error) {
                return _buildOverlay(
                  color: const Color(0xFFEF4444),
                  icon: Icons.block_rounded,
                  label: 'Rejected: ${result.reason}',
                  isPending: false,
                );
              } else if (result.status == VerificationStatus.flagged) {
                return _buildOverlay(
                  color: const Color(0xFFF59E0B),
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
    required Color color,
    required IconData icon,
    required String label,
    required bool isPending,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        color: isPending
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(8),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, size: 12, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
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
