import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium comment input with enhanced UI and onSubmit callback
class PremiumCommentInput extends StatefulWidget {
  final String videoId;
  final bool isReply;
  final Function(String text, bool postAsChannel, String? channelId) onSubmit;
  final VoidCallback? onCancel;

  const PremiumCommentInput({
    super.key,
    required this.videoId,
    this.isReply = false,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<PremiumCommentInput> createState() => _PremiumCommentInputState();
}

class _PremiumCommentInputState extends State<PremiumCommentInput>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSubmitting = false;
  final bool _postAsChannel = false;
  String? _selectedChannelId;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      HapticFeedback.mediumImpact();
      await widget.onSubmit(text, _postAsChannel, _selectedChannelId);
      _commentController.clear();
      _focusNode.unfocus();
    } catch (e) {
      debugPrint('Error submitting comment: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text input
          TextField(
            controller: _commentController,
            focusNode: _focusNode,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitComment(),
            style: GoogleFonts.roboto(
              fontSize: isMobile ? 14 : 15,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              hintStyle: GoogleFonts.roboto(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 8),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.roboto(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitComment,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Icon(Icons.send, size: 18),
                label: Text(_isSubmitting ? 'Posting...' : 'Comment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}





