import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/comment_report.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Premium report dialog for comments and replies
class CommentReportDialog extends StatefulWidget {
  final Comment comment;
  final String videoId;
  final String? replyId;

  const CommentReportDialog({
    required this.comment,
    required this.videoId,
    this.replyId,
    super.key,
  });

  static void show({
    required BuildContext context,
    required Comment comment,
    required String videoId,
    String? replyId,
  }) {
    showDialog(
      context: context,
      builder: (_) => CommentReportDialog(
        comment: comment,
        videoId: videoId,
        replyId: replyId,
      ),
    );
  }

  @override
  State<CommentReportDialog> createState() => _CommentReportDialogState();
}

class _CommentReportDialogState extends State<CommentReportDialog> {
  final _commentService = CommentService();
  final _authService = FirebaseAuth.instance;

  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      Get.snackbar(
        'Error',
        'Please select a reason',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        Get.snackbar('Error', 'You must be logged in to report',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      await _commentService.reportComment(
        commentId: widget.comment.id,
        replyId: widget.replyId,
        videoId: widget.videoId,
        reporterId: currentUser.uid,
        reporterName: currentUser.displayName ?? 'Anonymous',
        reason: _selectedReason!,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
      );

      if (mounted) {
        Get.snackbar(
          'Success',
          'Thank you for reporting. Our team will review this.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to submit report: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Colors.red[400],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report ${widget.replyId != null ? 'Reply' : 'Comment'}',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reason text
                Text(
                  'Why are you reporting this?',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),

                // Reason selection
                ..._buildReasonOptions(isDark),

                const SizedBox(height: 16),

                // Description field
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 200,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)',
                    hintStyle: GoogleFonts.roboto(
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                    filled: true,
                    fillColor:
                        isDark
                            ? AppColors.bgSurface
                            : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.bgDivider
                                : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.bgDivider
                                : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.brand,
                        width: 2,
                      ),
                    ),
                    counterStyle: GoogleFonts.roboto(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                  style: GoogleFonts.roboto(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Submit Report',
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReasonOptions(bool isDark) {
    return ReportReason.values.map((reason) {
      final isSelected = _selectedReason == reason;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => setState(() => _selectedReason = reason),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppColors.brand.withAlpha(30)
                      : isDark
                          ? AppColors.bgSurface
                          : Colors.grey[50],
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.brand
                        : isDark
                            ? AppColors.bgDivider
                            : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.brand : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.brand,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason.label,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}






