import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';

/// In-line input widget for drafting and posting a reply to a comment.
class CommunityCommentReplyInput extends StatelessWidget {
  const CommunityCommentReplyInput({
    required this.userName,
    required this.replyController,
    required this.onCancel,
    required this.onSubmit,
    super.key,
  });

  final String userName;
  final TextEditingController replyController;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 44, top: 8, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to ${userName.startsWith('@') ? userName.substring(1) : userName}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  maxLength: ContentValidator.defaultMaxReplyLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(
                    ContentValidator.defaultMaxReplyLength,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add a reply...',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
