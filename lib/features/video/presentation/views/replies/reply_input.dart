import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/presentation/controllers/reply_input_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ModernReplyInput extends StatefulWidget {
  const ModernReplyInput({
    required this.videoId,
    required this.commentId,
    this.initialText,
    super.key,
  });
  final String videoId;
  final String commentId;
  final String? initialText;

  @override
  State<ModernReplyInput> createState() => _ModernReplyInputState();
}

class _ModernReplyInputState extends State<ModernReplyInput>
    with SingleTickerProviderStateMixin {
  late final ReplyInputController _controller;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize controller locally for this specific widget instance
    _controller = Get.put(
      ReplyInputController(
        videoId: widget.videoId,
        commentId: widget.commentId,
        initialText: widget.initialText,
      ),
      tag: 'reply_${widget.commentId}',
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Listen for completion to trigger animations
    _controller.isSending.listen((sending) {
      if (!sending && _controller.replyText.value.isEmpty) {
        _animationController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    // Delete controller only if we are using Get.put (standard lifecycle)
    Get.delete<ReplyInputController>(tag: 'reply_${widget.commentId}');
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignedIn = AuthService.to.isAuthenticated.value;

    return Container(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Replying',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: Get.back,
                    iconSize: 20,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            if (!isSignedIn) ...[
              _buildSignInPrompt(theme),
            ] else ...[
              Obx(
                () => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    UserAvatar(
                      photoUrl: AuthService.to.activePhotoUrl,
                      displayName: AuthService.to.activeDisplayName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            _controller.isFocused.value ? 16 : 24,
                          ),
                          color: _controller.isFocused.value
                              ? AppTheme.colors.surfaceContainerHighest
                              : AppTheme.colors.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                          border: Border.all(
                            color: _controller.isFocused.value
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: _controller.isFocused.value ? 1.5 : 0,
                          ),
                          boxShadow: _controller.isFocused.value
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: TextField(
                          controller: _controller.textController,
                          focusNode: _controller.focusNode,
                          autofocus: true,
                          maxLines: 5,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a reply...',
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            suffixIcon: _controller.replyText.value.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => _controller.clearText(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendButton(theme),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return Obx(() {
      final canSend =
          _controller.replyText.value.trim().isNotEmpty &&
          !_controller.isSending.value;
      return ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canSend
                  ? LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: canSend ? null : AppTheme.colors.surfaceContainerHighest,
            ),
            child: IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: canSend
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: canSend ? () => _controller.sendReply() : null,
              tooltip: 'Send reply',
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSignInPrompt(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.login_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Sign in to reply to comments',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join the conversation by signing in with your account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              Get.back();
              await AuthService.to.signInWithGoogle();
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
            label: const Text(
              'Sign In',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
