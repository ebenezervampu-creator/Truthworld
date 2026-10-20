import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_item_controller.dart';

/// Inline reply input box with text field, close action, and submit button.
class CommentReplyInputBox extends StatelessWidget {
  const CommentReplyInputBox({
    required this.commentId,
    required this.controller,
    required this.onSubmit,
    super.key,
  });

  final String commentId;
  final CommentItemController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('reply_box_$commentId'),
      padding: const EdgeInsets.only(left: 52, top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.replyController,
              focusNode: controller.replyFocusNode,
              maxLength: ContentValidator.defaultMaxReplyLength,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(
                ContentValidator.defaultMaxReplyLength,
              ),
              decoration: InputDecoration(
                hintText: 'Add a reply...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey.shade800,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey.shade800,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: controller.cancelReplying,
            icon: const Icon(
              Icons.close,
              size: 20,
              color: Colors.white70,
            ),
          ),
          IconButton(
            onPressed: onSubmit,
            icon: Obx(
              () => Icon(
                Icons.send,
                size: 20,
                color: controller.replyText.value.isNotEmpty
                    ? Colors.white
                    : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
