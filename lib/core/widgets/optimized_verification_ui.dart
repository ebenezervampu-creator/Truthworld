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

  Color _getStatusColor(BuildContext context) {
    final twColors = context.colors;
    switch (result.status) {
      case VerificationStatus.approved:
        return twColors.success;
      case VerificationStatus.rejected:
        return twColors.error;
      case VerificationStatus.flagged:
        return twColors.warning;
      case VerificationStatus.pending:
        return twColors.info;
      case VerificationStatus.error:
        return twColors.error;
      case VerificationStatus.timeout:
        return twColors.textTertiary;
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
    final statusColor = _getStatusColor(context);
    final twSpacing = context.spacing;
    final twRadius = context.radius;

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
        margin: EdgeInsets.symmetric(vertical: twSpacing.sm),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.08),
          borderRadius: twRadius.circularLg,
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
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
                padding: EdgeInsets.all(twSpacing.md),
                child: Row(
                  children: [
                    // Icon with animation
                    _buildStatusIcon(context),
                    SizedBox(width: twSpacing.sm + 4),
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
                              color: statusColor,
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
                                    : context.colors.textSecondary,
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
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: twRadius.circularSm,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onRetry,
                              borderRadius: twRadius.circularSm,
                              child: Padding(
                                padding: EdgeInsets.all(twSpacing.sm),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: statusColor,
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
                  color: statusColor.withValues(alpha: 0.15),
                ),
                Padding(
                  padding: EdgeInsets.all(twSpacing.sm + 4),
                  child: _buildScoreIndicator(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final statusColor = _getStatusColor(context);
    if (_isLoading()) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: statusColor.withValues(alpha: 0.12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
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
        color: statusColor.withValues(alpha: 0.15),
      ),
      child: Icon(
        _getStatusIcon(),
        color: statusColor,
        size: 20,
      ),
    );
  }

  Widget _buildScoreIndicator(BuildContext context) {
    final score = result.score ?? 0.0;
    final scoreLabel = '${(score * 100).toStringAsFixed(0)}% confidence';
    final statusColor = _getStatusColor(context);
    final twSpacing = context.spacing;

    return Row(
      children: [
        Icon(
          Icons.trending_up_rounded,
          size: 14,
          color: statusColor,
        ),
        SizedBox(width: twSpacing.sm),
        Expanded(
          child: Text(
            scoreLabel,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
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
                    color: statusColor,
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
    final twColors = context.colors;
    final twSpacing = context.spacing;
    final twRadius = context.radius;

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
              margin: EdgeInsets.symmetric(vertical: twSpacing.sm),
              padding: EdgeInsets.all(twSpacing.md),
              decoration: BoxDecoration(
                color: twColors.errorContainer,
                borderRadius: twRadius.circularLg,
                border: Border.all(
                  color: twColors.error.withValues(alpha: 0.3),
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
                      color: twColors.error.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: twColors.error,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: twSpacing.sm + 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Error',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: twColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Failed to connect to verification service',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : twColors.textSecondary,
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

  Color _getStatusColor(BuildContext context) {
    final twColors = context.colors;
    switch (status) {
      case VerificationStatus.approved:
        return twColors.success;
      case VerificationStatus.rejected:
        return twColors.error;
      case VerificationStatus.flagged:
        return twColors.warning;
      case VerificationStatus.pending:
        return twColors.info;
      case VerificationStatus.error:
        return twColors.error;
      case VerificationStatus.timeout:
        return twColors.textTertiary;
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
    final statusColor = _getStatusColor(context);
    final twSpacing = context.spacing;
    final twRadius = context.radius;

    if (compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: twSpacing.sm, vertical: twSpacing.xs),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: twRadius.circularSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStatusIcon(),
              size: 12,
              color: statusColor,
            ),
            const SizedBox(width: 4),
            Text(
              _getStatusLabel(),
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: twSpacing.sm + 4, vertical: twSpacing.xs + 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: twRadius.circularMd,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 14,
            color: statusColor,
          ),
          SizedBox(width: twSpacing.xs + 2),
          Text(
            _getStatusLabel(),
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}







