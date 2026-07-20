import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/components/ui/user_avatar.dart';

/// Modern, responsive, and adaptive CommentInput with enhanced UI/UX
/// Preserves all original backend functionality while providing premium user experience
class ModernCommentInput extends StatefulWidget {
  final String videoId;
  final bool enableComments;

  const ModernCommentInput({
    required this.videoId,
    super.key,
    required this.enableComments,
  });

  @override
  State<ModernCommentInput> createState() => _ModernCommentInputState();
}

class _ModernCommentInputState extends State<ModernCommentInput>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final MainController _mainController = Get.find();
  final FocusNode _focusNode = FocusNode();

  // Animation Controllers
  late AnimationController _submitAnimationController;
  late AnimationController _focusAnimationController;
  late AnimationController _typingAnimationController;
  late AnimationController _successAnimationController;

  // Animations
  late Animation<double> _submitAnimation;
  late Animation<double> _focusAnimation;
  late Animation<double> _typingAnimation;
  late Animation<double> _successAnimation;
  Animation<Color?>? _borderColorAnimation;
  late Animation<double> _elevationAnimation;

  // State Variables
  final RxBool _isFocused = false.obs;
  final RxBool _hasText = false.obs;
  final RxBool _isSubmitting = false.obs;
  final RxBool _isHovering = false.obs;
  final RxInt _characterCount = 0.obs;

  @override
  void initState() {
    super.initState();
    // Initialize animations that don't depend on context
    _initializeBasicAnimations();
    _setupListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _borderColorAnimation = ColorTween(
      begin: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
      end: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
    ).animate(_focusAnimation);
  }

  void _initializeBasicAnimations() {
    // Submit Animation (for send button)
    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _submitAnimation = CurvedAnimation(
      parent: _submitAnimationController,
      curve: Curves.elasticOut,
    );

    // Focus Animation (for container transformation)
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // Typing Animation (for character counter)
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _typingAnimation = CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    );

    // Success Animation (for submission feedback)
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );

    // Elevation Animation (no context dependency)
    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(_focusAnimation);
  }

  void _setupListeners() {
    _commentController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final text = _commentController.text;
    final hasText = text.isNotEmpty;
    final characterCount = text.length;

    if (hasText != _hasText.value) {
      _hasText.value = hasText;

      if (hasText) {
        _submitAnimationController.forward();
        _typingAnimationController.forward();
      } else {
        _submitAnimationController.reverse();
        _typingAnimationController.reverse();
      }
    }

    if (characterCount != _characterCount.value) {
      _characterCount.value = characterCount;
    }
  }

  void _onFocusChanged() {
    final isFocused = _focusNode.hasFocus;
    if (isFocused != _isFocused.value) {
      _isFocused.value = isFocused;

      if (isFocused) {
        _focusAnimationController.forward();
      } else {
        _focusAnimationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _commentController.dispose();
    _focusNode.dispose();

    _submitAnimationController.dispose();
    _focusAnimationController.dispose();
    _typingAnimationController.dispose();
    _successAnimationController.dispose();

    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty ||
        !widget.enableComments ||
        _isSubmitting.value) {
      return;
    }

    _isSubmitting.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Add haptic feedback
      HapticFeedback.mediumImpact();

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value && authService.userChannel != null;
      final finalUserName = hasChannel ? authService.userChannel!.name : (user.displayName ?? 'Anonymous User');
      final finalUserProfilePicUrl = hasChannel ? authService.userChannel!.avatarUrl : (user.photoURL ?? '');

      // Submit comment (preserved original functionality)
      await _mainController.addComment(
        videoId: widget.videoId,
        userId: user.uid,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        text: _commentController.text,
      );

      // Success animation
      _successAnimationController.forward().then((_) {
        _successAnimationController.reverse();
      });

      // Clear input
      _commentController.clear();
      _focusNode.unfocus();

      // Show success feedback
      _showSuccessSnackBar();
    } catch (e) {
      // Error handling
      _showErrorSnackBar();
    } finally {
      _isSubmitting.value = false;
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Comment posted successfully',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Failed to post comment. Please try again.',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red.shade600,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _submitComment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUserSignedIn = FirebaseAuth.instance.currentUser != null;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // Responsive breakpoints
    final bool isMobile = size.width < 600;
    final bool isTablet = size.width >= 600 && size.width < 1000;
    final bool isDesktop = size.width >= 1000;

    // Responsive dimensions
    final double horizontalPadding = isMobile
        ? 12.0
        : isTablet
        ? 16.0
        : 20.0;
    final double verticalPadding = isMobile
        ? 12.0
        : isTablet
        ? 16.0
        : 20.0;
    final double avatarRadius = isMobile
        ? 20.0
        : isTablet
        ? 24.0
        : 28.0;
    final double iconSize = isMobile
        ? 20.0
        : isTablet
        ? 22.0
        : 24.0;

    if (!isUserSignedIn) {
      return _buildSignInPrompt(
        theme,
        isMobile,
        isTablet,
        horizontalPadding,
        verticalPadding,
        iconSize,
      );
    }

    return _buildCommentInput(
      theme,
      isMobile,
      isTablet,
      isDesktop,
      horizontalPadding,
      verticalPadding,
      avatarRadius,
      iconSize,
    );
  }

  Widget _buildSignInPrompt(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    double horizontalPadding,
    double verticalPadding,
    double iconSize,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: verticalPadding / 2),
      child: MouseRegion(
        onEnter: (_) => _isHovering.value = true,
        onExit: (_) => _isHovering.value = false,
        child: Obx(() {
          final isHovering = _isHovering.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scaleByDouble(isHovering ? 1.02 : 1.0, isHovering ? 1.02 : 1.0, 1.0, 1.0),
            child: Card(
              elevation: isHovering ? 8 : 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                padding: EdgeInsets.all(horizontalPadding),
                child: Row(
                  children: [
                    Container(
                      height: isMobile ? 48 : 52,
                      width: isMobile ? 48 : 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.2),
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join the conversation',
                            style: GoogleFonts.roboto(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sign in to share your thoughts',
                            style: GoogleFonts.roboto(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Get.toNamed('/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 20,
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              isMobile ? 16 : 20,
                            ),
                          ),
                        ),
                        icon: Icon(Icons.login_rounded, size: iconSize - 2),
                        label: Text(
                          'Sign In',
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCommentInput(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    double horizontalPadding,
    double verticalPadding,
    double avatarRadius,
    double iconSize,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: verticalPadding / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildUserAvatar(theme, avatarRadius),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: _buildInputContainer(
              theme,
              isMobile,
              isTablet,
              horizontalPadding,
              iconSize,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          _buildSubmitButton(theme, iconSize),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(ThemeData theme, double radius) {
    final user = FirebaseAuth.instance.currentUser!;

    return Hero(
      tag: 'user_avatar_${user.uid}',
      child: Material(
        elevation: 0,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.3),
                theme.colorScheme.primary.withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: UserAvatar(
            radius: radius,
            photoUrl: user.photoURL,
            displayName: user.displayName,
            backgroundColor: Colors.transparent,
            textColor: theme.colorScheme.primary,
            fontSize: radius * 0.6,
            showBorder: false,
          ),
        ),
      ),
    );
  }

  Widget _buildInputContainer(
    ThemeData theme,
    bool isMobile,
    bool isTablet,
    double horizontalPadding,
    double iconSize,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _focusAnimation,
        _typingAnimation,
        _elevationAnimation,
        ...[_borderColorAnimation].nonNulls,
      ]),
      builder: (context, child) {
        return Obx(() {
          final isFocused = _isFocused.value;
          final hasText = _hasText.value;
          final characterCount = _characterCount.value;

          return Container(
            constraints: BoxConstraints(
              maxHeight: isMobile ? 150 : 200, // Constrain max height
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                isFocused ? 16 : (isMobile ? 20 : 24),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isFocused
                    ? [
                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      ]
                    : [
                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      ],
              ),
              border: Border.all(
                color: _borderColorAnimation?.value ??
                    theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isFocused ? 2 : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: _elevationAnimation.value,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 1,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 14 : 15,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: isFocused
                          ? 'What are your thoughts?'
                          : 'Share your thoughts...',
                      hintStyle: GoogleFonts.roboto(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isMobile ? 12 : 14,
                      ),
                      counterText: '',
                      suffixIcon: hasText
                          ? ScaleTransition(
                              scale: _typingAnimation,
                              child: IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: iconSize - 2,
                                ),
                                onPressed: () {
                                  _commentController.clear();
                                  HapticFeedback.lightImpact();
                                },
                                color: theme.colorScheme.onSurfaceVariant,
                                tooltip: 'Clear',
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (isFocused && characterCount > 0)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.only(
                        left: horizontalPadding,
                        right: horizontalPadding,
                        bottom: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Press Enter to send',
                            style: GoogleFonts.roboto(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            '$characterCount/500',
                            style: GoogleFonts.roboto(
                              color: characterCount > 450
                                  ? Colors.orange
                                  : characterCount > 480
                                      ? Colors.red
                                      : theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildSubmitButton(ThemeData theme, double iconSize) {
    return ScaleTransition(
      scale: _submitAnimation,
      child: AnimatedBuilder(
        animation: _successAnimation,
        builder: (context, child) {
          return Obx(() {
            final hasText = _hasText.value;
            final isSubmitting = _isSubmitting.value;

            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasText
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        ],
                      ),
                boxShadow: hasText
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: RotationTransition(turns: animation, child: child),
                    );
                  },
                  child: hasText
                      ? Icon(
                          Icons.send_rounded,
                          key: const ValueKey('send'),
                          color: Colors.white,
                          size: iconSize,
                        )
                          : Icon(
                              Icons.emoji_emotions_outlined,
                              key: const ValueKey('emoji'),
                              color: theme.colorScheme.primary,
                              size: iconSize,
                            ),
                ),
                onPressed: hasText && !isSubmitting
                    ? _submitComment
                    : () {
                        // Could implement emoji picker here
                        HapticFeedback.lightImpact();
                      },
                tooltip: hasText ? 'Send comment' : 'Add emoji',
              ),
            );
          });
        },
      ),
    );
  }
}






