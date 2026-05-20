import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoReportDialog extends StatefulWidget {
  final Video video;

  const VideoReportDialog({
    required this.video,
    super.key,
  });

  static void show({
    required BuildContext context,
    required Video video,
  }) {
    showDialog(
      context: context,
      builder: (_) => VideoReportDialog(video: video),
    );
  }

  @override
  State<VideoReportDialog> createState() => _VideoReportDialogState();
}

class _VideoReportDialogState extends State<VideoReportDialog> {
  final _mainController = Get.find<MainController>();
  
  String? _selectedReason;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Sexual content',
    'Violent or repulsive content',
    'Hateful or abusive content',
    'Harassment or bullying',
    'Harmful or dangerous acts',
    'Spam or misleading',
    'Infringes my rights',
    'Other',
  ];

  @override
  void dispose() {
    _commentController.dispose();
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

      await _mainController.reportVideo(
        context: context,
        videoId: widget.video.id,
        channelId: widget.video.channelId,
        reason: _selectedReason!,
        comment: _commentController.text,
      );

      if (mounted) {
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
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Report Video',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Help us understand what\'s wrong with this video. We will review it shortly.',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _reasons.length,
                itemBuilder: (context, index) {
                  final reason = _reasons[index];
                  final isSelected = _selectedReason == reason;
                  return InkWell(
                    onTap: () => setState(() => _selectedReason = reason),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.brand : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            reason,
                            style: GoogleFonts.roboto(
                              fontSize: 15,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Additional details (optional)',
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
