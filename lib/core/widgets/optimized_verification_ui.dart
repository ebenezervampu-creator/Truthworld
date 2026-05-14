import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/image_verification_service.dart';

/// ============================================================================
/// OPTIMIZED VERIFICATION UI WIDGET - INSTANT FEEDBACK
/// ============================================================================
/// Industry Standard UI for instant image verification feedback
/// - Zero animation delay for status changes
/// - RepaintBoundary optimization for smooth rendering
/// - Auto-scroll on status update
/// - Real-time visual indicators

class OptimizedVerificationStatusWidget extends StatelessWidget {
  final VerificationResult result;
  final bool isDark;
  final VoidCallback? onApproved;
  final VoidCallback? onRetry;
  final bool autoScroll;

  const OptimizedVerificationStatusWidget({
    super.key,
    required this.result,
    required this.isDark,
    this.onApproved,
    this.onRetry,
    this.autoScroll = true,
  });

  Color _getStatusColor() {
    switch (result.status) {
      case VerificationStatus.approved:
        return const Color(0xFF10B981); // Green
      case VerificationStatus.rejected:
        return const Color(0xFFEF4444); // Red
      case VerificationStatus.flagged:
        return const Color(0xFFF59E0B); // Amber
      case VerificationStatus.pending:
        return const Color(0xFF3B82F6); // Blue
      case VerificationStatus.error:
        return const Color(0xFFEF4444); // Red
      case VerificationStatus.timeout:
        return const Color(0xFF9CA3AF); // Gray
    }
  }

  IconData _getStatusIcon() {
    switch (result.status) {
      case VerificationStatus.approved:
        return Icons.verified_rounded;
      case VerificationStatus.rejected:
        return Icons.block_rounded;
      case VerificationStatus.flagged:
        return Icons.warning_rounded;
      case VerificationStatus.pending:
        return Icons.hourglass_bottom_rounded;
      case VerificationStatus.error:
        return Icons.error_outline_rounded;
      case VerificationStatus.timeout:
        return Icons.schedule_rounded;
    }
  }

  String _getStatusLabel() {
    switch (result.status) {
      case VerificationStatus.approved:
        return 'Image Approved';
      case VerificationStatus.rejected:
        return 'Image Rejected';
      case VerificationStatus.flagged:
        return 'Flagged for Review';
      case VerificationStatus.pending:
        return 'Verifying...';
      case VerificationStatus.error:
        return 'Error Processing';
      case VerificationStatus.timeout:
        return 'Verification Timeout';
    }
  }

  bool _isLoading() => result.status == VerificationStatus.pending;
  bool _isApproved() => result.status == VerificationStatus.approved;
  bool _isRejected() =>
      result.status == VerificationStatus.rejected ||
      result.status == VerificationStatus.error;

  @override
  Widget build(BuildContext context) {
    // Trigger auto-scroll and callback on status change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isApproved() && onApproved != null) {
        onApproved!();
      }
      if (autoScroll && !_isLoading()) {
        _scrollIntoView(context);
      }
    });

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon with animation
                    _buildStatusIcon(),
                    const SizedBox(width: 14),
                    // Status Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusLabel(),
                            style: GoogleFonts.roboto(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(),
                            ),
                          ),
                          if (result.reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              result.reason,
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white60
                                    : AppColors.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Quick Action Button
                    if (_isRejected() && onRetry != null)
                      Tooltip(
                        message: 'Try another image',
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getStatusColor().withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onRetry,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: _getStatusColor(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Score breakdown (if available and approved)
              if (_isApproved() && result.score != null) ...[
                Container(
                  height: 1,
                  color: _getStatusColor().withValues(alpha: 0.15),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildScoreIndicator(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_isLoading()) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getStatusColor().withValues(alpha: 0.12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getStatusColor().withValues(alpha: 0.15),
      ),
      child: Icon(
        _getStatusIcon(),
        color: _getStatusColor(),
        size: 20,
      ),
    );
  }

  Widget _buildScoreIndicator() {
    final score = result.score ?? 0.0;
    final scoreLabel = '${(score * 100).toStringAsFixed(0)}% confidence';

    return Row(
      children: [
        Icon(
          Icons.trending_up_rounded,
          size: 14,
          color: _getStatusColor(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            scoreLabel,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: _getStatusColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 60 * score,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollIntoView(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

/// ============================================================================
/// REAL-TIME VERIFICATION LISTENER WIDGET
/// ============================================================================
/// Automatically displays verification status in real-time
/// Perfect for integrating into upload/channel screens

class VerificationStatusListenerWidget extends StatelessWidget {
  final String docId;
  final bool isDark;
  final VoidCallback? onApproved;
  final VoidCallback? onRetry;
  final bool autoScroll;

  const VerificationStatusListenerWidget({
    super.key,
    required this.docId,
    required this.isDark,
    this.onApproved,
    this.onRetry,
    this.autoScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final imageService = ImageVerificationService();

    return RepaintBoundary(
      child: StreamBuilder<VerificationResult>(
        stream: imageService.streamVerificationStatus(docId),
        initialData: VerificationResult(
          status: VerificationStatus.pending,
          reason: 'Initializing verification...',
        ),
        builder: (context, snapshot) {
          // Handle errors instantly
          if (snapshot.hasError) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Error',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Failed to connect to verification service',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          return OptimizedVerificationStatusWidget(
            result: snapshot.data!,
            isDark: isDark,
            onApproved: onApproved,
            onRetry: onRetry,
            autoScroll: autoScroll,
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// VERIFICATION RESULT BADGE - FOR QUICK DISPLAY
/// ============================================================================
/// Compact badge showing verification status
/// Ideal for preview cards and list items

class VerificationBadge extends StatelessWidget {
  final VerificationStatus status;
  final bool compact;

  const VerificationBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color _getStatusColor() {
    switch (status) {
      case VerificationStatus.approved:
        return const Color(0xFF10B981);
      case VerificationStatus.rejected:
        return const Color(0xFFEF4444);
      case VerificationStatus.flagged:
        return const Color(0xFFF59E0B);
      case VerificationStatus.pending:
        return const Color(0xFF3B82F6);
      case VerificationStatus.error:
        return const Color(0xFFEF4444);
      case VerificationStatus.timeout:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case VerificationStatus.approved:
        return Icons.check_circle_rounded;
      case VerificationStatus.rejected:
        return Icons.cancel_rounded;
      case VerificationStatus.flagged:
        return Icons.priority_high_rounded;
      case VerificationStatus.pending:
        return Icons.schedule_rounded;
      case VerificationStatus.error:
        return Icons.error_rounded;
      case VerificationStatus.timeout:
        return Icons.more_time_rounded;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.flagged:
        return 'Flagged';
      case VerificationStatus.pending:
        return 'Verifying';
      case VerificationStatus.error:
        return 'Error';
      case VerificationStatus.timeout:
        return 'Timeout';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStatusIcon(),
              size: 12,
              color: _getStatusColor(),
            ),
            const SizedBox(width: 4),
            Text(
              _getStatusLabel(),
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 14,
            color: _getStatusColor(),
          ),
          const SizedBox(width: 6),
          Text(
            _getStatusLabel(),
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }
}







