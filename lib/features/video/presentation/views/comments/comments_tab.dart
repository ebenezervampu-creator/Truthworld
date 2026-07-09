import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/views/comments/comment_input.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/views/replies/reply_input.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/components/ui/user_avatar.dart';

Widget buildCommentsTab({
  required Video video,
  required ThemeData theme,
  required MainController mainController,
}) {
  return ModernCommentsTab(
    video: video,
    theme: theme,
    mainController: mainController,
  );
}

class ModernCommentsTab extends StatefulWidget {
  final Video video;
  final ThemeData theme;
  final MainController mainController;

  const ModernCommentsTab({
    super.key,
    required this.video,
    required this.theme,
    required this.mainController,
  });

  @override
  State<ModernCommentsTab> createState() => _ModernCommentsTabState();
}

class _ModernCommentsTabState extends State<ModernCommentsTab>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final RxInt _retryTrigger = 0.obs;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOutCubic),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1000;
    final isDesktop = size.width >= 1000;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.theme.colorScheme.surface,
                    widget.theme.colorScheme.surface.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Comment Input Section
                  _buildCommentInputSection(isMobile, isTablet, isDesktop),

                  // Comment Count and Sort Section
                  _buildCommentHeaderSection(isMobile, isTablet, isDesktop),

                  // Comments List
                  Expanded(
                    child: _buildCommentsList(isMobile, isTablet, isDesktop),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentInputSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
        ? 24.0
        : 32.0;
    final verticalPadding = isMobile
        ? 16.0
        : isTablet
        ? 20.0
        : 24.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: isMobile
                ? 8
                : isTablet
                ? 12
                : 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: ModernCommentInput(
          videoId: widget.video.id,
          enableComments: widget.video.enableComments,
        ),
      ),
    );
  }

  Widget _buildCommentHeaderSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
        ? 24.0
        : 32.0;

    return Obx(() {
      final _ = _retryTrigger.value;
      return Container(
        margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("videos")
                .doc(widget.video.id)
                .collection('comments')
                .snapshots(),
            builder: (context, snapshot) {
              int commentCount = snapshot.hasData
                  ? snapshot.data!.docs.length
                  : 0;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(commentCount),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile
                        ? 12
                        : isTablet
                        ? 16
                        : 20,
                    vertical: isMobile
                        ? 8
                        : isTablet
                        ? 10
                        : 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.theme.colorScheme.primary.withValues(alpha: 0.1),
                        widget.theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      isMobile
                          ? 20
                          : isTablet
                          ? 24
                          : 28,
                    ),
                    border: Border.all(
                      color: widget.theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: isMobile
                            ? 16
                            : isTablet
                            ? 18
                            : 20,
                        color: widget.theme.colorScheme.primary,
                      ),
                      SizedBox(
                        width: isMobile
                            ? 6
                            : isTablet
                            ? 8
                            : 10,
                      ),
                      Text(
                        '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile
                              ? 14
                              : isTablet
                              ? 15
                              : 16,
                          color: widget.theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: widget.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sort by',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  });
}

  Widget _buildCommentsList(bool isMobile, bool isTablet, bool isDesktop) {
    return Obx(() {
      final _ = _retryTrigger.value;
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("videos")
            .doc(widget.video.id)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isMobile, isTablet, isDesktop);
        }

        if (snapshot.hasError) {
          return _buildErrorState(isMobile, isTablet, isDesktop);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isMobile, isTablet, isDesktop);
        }

        final comments = snapshot.data!.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc))
            .toList();

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: ModernCommentItem(
                      comment: comment,
                      theme: widget.theme,
                      mainController: widget.mainController,
                      video: widget.video,
                      isMobile: isMobile,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  });
}

  Widget _buildLoadingState(bool isMobile, bool isTablet, bool isDesktop) {
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
        ? 24.0
        : 32.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
      child: Column(
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(
              isMobile
                  ? 16
                  : isTablet
                  ? 20
                  : 24,
            ),
            decoration: BoxDecoration(
              color: widget.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(
                isMobile
                    ? 16
                    : isTablet
                    ? 20
                    : 24,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.theme.colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildShimmerEffect(isMobile, isTablet, isDesktop),
          );
        }),
      ),
    );
  }

  Widget _buildShimmerEffect(bool isMobile, bool isTablet, bool isDesktop) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.3, end: 1.0),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile
                    ? 36
                    : isTablet
                    ? 40
                    : 44,
                height: isMobile
                    ? 36
                    : isTablet
                    ? 40
                    : 44,
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 
                    0.5,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(
                width: isMobile
                    ? 12
                    : isTablet
                    ? 16
                    : 20,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: isMobile
                          ? 12
                          : isTablet
                          ? 14
                          : 16,
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: isMobile
                          ? 10
                          : isTablet
                          ? 12
                          : 14,
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(bool isMobile, bool isTablet, bool isDesktop) {
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
        ? 24.0
        : 32.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 48),
      padding: EdgeInsets.all(
        isMobile
            ? 24
            : isTablet
            ? 32
            : 40,
      ),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        border: Border.all(
          color: widget.theme.colorScheme.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: isMobile
                ? 48
                : isTablet
                ? 56
                : 64,
            color: widget.theme.colorScheme.error.withValues(alpha: 0.7),
          ),
          SizedBox(
            height: isMobile
                ? 16
                : isTablet
                ? 20
                : 24,
          ),
          Text(
            'Failed to load comments',
            style: GoogleFonts.roboto(
              fontSize: isMobile
                  ? 16
                  : isTablet
                  ? 18
                  : 20,
              fontWeight: FontWeight.w500,
              color: widget.theme.colorScheme.error,
            ),
          ),
          SizedBox(
            height: isMobile
                ? 8
                : isTablet
                ? 10
                : 12,
          ),
          Text(
            'Please check your connection and try again',
            style: GoogleFonts.roboto(
              fontSize: isMobile
                  ? 14
                  : isTablet
                  ? 15
                  : 16,
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: isMobile
                ? 20
                : isTablet
                ? 24
                : 28,
          ),
          ElevatedButton.icon(
            onPressed: () {
              _retryTrigger.value++; // Trigger rebuild to retry
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.theme.colorScheme.primary,
              foregroundColor: widget.theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile
                    ? 20
                    : isTablet
                    ? 24
                    : 28,
                vertical: isMobile
                    ? 12
                    : isTablet
                    ? 14
                    : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  isMobile
                      ? 12
                      : isTablet
                      ? 14
                      : 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile, bool isTablet, bool isDesktop) {
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
        ? 24.0
        : 32.0;
    final bool isUserSignedIn = FirebaseAuth.instance.currentUser != null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 48),
      padding: EdgeInsets.all(
        isMobile
            ? 24
            : isTablet
            ? 32
            : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            widget.theme.colorScheme.secondaryContainer.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        border: Border.all(
          color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: EdgeInsets.all(
                    isMobile
                        ? 16
                        : isTablet
                        ? 20
                        : 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.theme.colorScheme.primary.withValues(alpha: 0.2),
                        widget.theme.colorScheme.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: isMobile
                        ? 48
                        : isTablet
                        ? 56
                        : 64,
                    color: widget.theme.colorScheme.primary,
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: isMobile
                ? 20
                : isTablet
                ? 24
                : 28,
          ),
          Text(
            isUserSignedIn ? 'Be the first to comment!' : 'No comments yet',
            style: GoogleFonts.roboto(
              fontSize: isMobile
                  ? 18
                  : isTablet
                  ? 20
                  : 22,
              fontWeight: FontWeight.w500,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(
            height: isMobile
                ? 8
                : isTablet
                ? 10
                : 12,
          ),
          Text(
            isUserSignedIn
                ? 'Share your thoughts about this video'
                : 'Sign in to join the conversation',
            style: GoogleFonts.roboto(
              fontSize: isMobile
                  ? 14
                  : isTablet
                  ? 15
                  : 16,
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isUserSignedIn) ...[
            SizedBox(
              height: isMobile
                  ? 20
                  : isTablet
                  ? 24
                  : 28,
            ),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Get.toNamed('/login');
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.theme.colorScheme.primary,
                foregroundColor: widget.theme.colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile
                      ? 24
                      : isTablet
                      ? 28
                      : 32,
                  vertical: isMobile
                      ? 14
                      : isTablet
                      ? 16
                      : 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    isMobile
                        ? 12
                        : isTablet
                        ? 14
                        : 16,
                  ),
                ),
                elevation: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modern Comment Item with enhanced UI/UX
class ModernCommentItem extends StatefulWidget {
  final Comment comment;
  final ThemeData theme;
  final MainController mainController;
  final Video video;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  const ModernCommentItem({
    super.key,
    required this.comment,
    required this.theme,
    required this.mainController,
    required this.video,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  State<ModernCommentItem> createState() => _ModernCommentItemState();
}

class _ModernCommentItemState extends State<ModernCommentItem>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  final RxBool _isHovered = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (widget.isDesktop) {
      _isHovered.value = isHovered;

      if (isHovered) {
        _hoverController.forward();
      } else {
        _hoverController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = widget.isMobile
        ? 16.0
        : widget.isTablet
        ? 24.0
        : 32.0;
    final verticalPadding = widget.isMobile
        ? 12.0
        : widget.isTablet
        ? 16.0
        : 20.0;
    final avatarRadius = widget.isMobile
        ? 18.0
        : widget.isTablet
        ? 20.0
        : 22.0;

    return AnimatedBuilder(
      animation: _hoverAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _hoverAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: Obx(() {
              final isHovered = _isHovered.value;
              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding / 2,
                ),
                padding: EdgeInsets.all(
                  widget.isMobile
                      ? 16
                      : widget.isTablet
                      ? 20
                      : 24,
                ),
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    widget.isMobile
                        ? 16
                        : widget.isTablet
                        ? 20
                        : 24,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.theme.colorScheme.shadow.withValues(alpha: 
                        isHovered ? 0.15 : 0.08,
                      ),
                      blurRadius: isHovered ? 16 : 8,
                      offset: Offset(0, isHovered ? 6 : 2),
                    ),
                  ],
                  border: Border.all(
                    color: widget.theme.colorScheme.outline.withValues(alpha: 
                      isHovered ? 0.3 : 0.1,
                    ),
                    width: 1,
                  ),
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserAvatar(avatarRadius),
                      SizedBox(
                        width: widget.isMobile
                            ? 12
                            : widget.isTablet
                            ? 16
                            : 20,
                      ),
                      Expanded(child: _buildCommentContent()),
                    ],
                  ),
                  SizedBox(
                    height: widget.isMobile
                        ? 12
                        : widget.isTablet
                        ? 16
                        : 20,
                  ),
                  _buildRepliesSection(),
                ],
              ),
            );
          }),
        ),
      );
    },
  );
}

  Widget _buildUserAvatar(double radius) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            widget.theme.colorScheme.primary.withValues(alpha: 0.2),
            widget.theme.colorScheme.primary.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: widget.theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: UserAvatar(
        radius: radius,
        photoUrl: widget.comment.userProfilePicUrl,
        displayName: widget.comment.userName,
        backgroundColor: Colors.transparent,
        textColor: widget.theme.colorScheme.primary,
        fontSize: widget.isMobile
            ? 14
            : widget.isTablet
            ? 16
            : 18,
        showBorder: false,
      ),
    );
  }

  Widget _buildCommentContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.comment.userName,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: widget.isMobile
                    ? 13
                    : widget.isTablet
                    ? 14
                    : 15,
                color: widget.theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(
              width: widget.isMobile
                  ? 8
                  : widget.isTablet
                  ? 10
                  : 12,
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile
                    ? 6
                    : widget.isTablet
                    ? 8
                    : 10,
                vertical: widget.isMobile
                    ? 2
                    : widget.isTablet
                    ? 3
                    : 4,
              ),
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(
                  widget.isMobile
                      ? 8
                      : widget.isTablet
                      ? 10
                      : 12,
                ),
              ),
              child: Text(
                timeago.format(widget.comment.createdAt.toDate()),
                style: GoogleFonts.roboto(
                  color: widget.theme.colorScheme.onSurfaceVariant,
                  fontSize: widget.isMobile
                      ? 11
                      : widget.isTablet
                      ? 12
                      : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: widget.isMobile
              ? 8
              : widget.isTablet
              ? 10
              : 12,
        ),
        Text(
          widget.comment.text,
          style: GoogleFonts.roboto(
            fontSize: widget.isMobile
                ? 14
                : widget.isTablet
                ? 15
                : 16,
            color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.9),
            height: 1.4,
          ),
        ),
        SizedBox(
          height: widget.isMobile
              ? 12
              : widget.isTablet
              ? 14
              : 16,
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    final bool isUserSignedIn = FirebaseAuth.instance.currentUser != null;
    final tag = 'video_${widget.video.id}';
    final hasCommentsCtrl = Get.isRegistered<CommentsController>(tag: tag);
    final commentsController = hasCommentsCtrl
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: widget.video), tag: tag);
    final isLiked = commentsController.isCommentLikedByUser(widget.comment);
    final isDisliked = commentsController.isCommentDislikedByUser(widget.comment);

    return Row(
      children: [
        // Like Icon
        IconButton(
          icon: Icon(
            isLiked
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            size: 18,
            color: widget.theme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (!isUserSignedIn) {
              _showSignInPrompt();
              return;
            }
            HapticFeedback.lightImpact();
            commentsController.toggleCommentLike(
              commentId: widget.comment.id,
              likeAsChannel: false,
            );
          },
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
        if (widget.comment.likeCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            widget.comment.likeCount.toString(),
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(width: 16),
        // Dislike Icon
        IconButton(
          icon: Icon(
            isDisliked
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            size: 18,
            color: widget.theme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (!isUserSignedIn) {
              _showSignInPrompt();
              return;
            }
            HapticFeedback.lightImpact();
            commentsController.toggleCommentDislike(
              commentId: widget.comment.id,
              dislikeAsChannel: false,
            );
          },
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 16),
        // Creator Heart Avatar Badge (Overlay Style)
        if (widget.comment.isHeartedByCreator)
          GestureDetector(
            onTap: (isUserSignedIn && FirebaseAuth.instance.currentUser!.uid == widget.video.ownerId)
                ? () {
                    HapticFeedback.mediumImpact();
                    widget.mainController.heartComment(
                      videoId: widget.video.id,
                      commentId: widget.comment.id,
                      isHearted: false,
                    );
                  }
                : null,
            child: Stack(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: UserAvatar(
                    radius: 12,
                    photoUrl: widget.video.thumbnailUrl,
                    displayName: widget.video.channelName,
                    backgroundColor: widget.theme.colorScheme.surface,
                    fontSize: 12,
                    showBorder: false,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 16),
        // Reply Text
        InkWell(
          onTap: () {
            if (!isUserSignedIn) {
              _showSignInPrompt();
              return;
            }
            HapticFeedback.lightImpact();
            _showReplyInput(widget.comment.id);
          },
          child: Text(
            'Reply',
            style: GoogleFonts.roboto(
              color: widget.theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepliesSection() {
    return ModernRepliesSection(
      commentId: widget.comment.id,
      theme: widget.theme,
      video: widget.video,
      mainController: widget.mainController,
      isMobile: widget.isMobile,
      isTablet: widget.isTablet,
      isDesktop: widget.isDesktop,
    );
  }

  void _showReplyInput(String commentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ModernReplyInput(videoId: widget.video.id, commentId: commentId),
      ),
    );
  }

  void _showSignInPrompt() {
    Get.snackbar(
      'Sign in required',
      'Please sign in to perform this action.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: widget.theme.colorScheme.surfaceContainerHighest,
      colorText: widget.theme.colorScheme.onSurfaceVariant,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          Get.toNamed('/login');
        },
        child: Text(
          'Sign In',
          style: TextStyle(
            color: widget.theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Modern Action Button for comments
class ModernActionButton extends StatefulWidget {
  final IconData icon;
  final int? count;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final bool isActive;
  final Color? activeColor;

  const ModernActionButton({
    super.key,
    required this.icon,
    this.count,
    required this.onTap,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    this.isActive = false,
    this.activeColor,
  });

  @override
  State<ModernActionButton> createState() => _ModernActionButtonState();
}

class _ModernActionButtonState extends State<ModernActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCol = widget.activeColor ?? widget.theme.colorScheme.primary;
    final color = widget.isActive ? activeCol : widget.theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile
                    ? 8
                    : widget.isTablet
                    ? 10
                    : 12,
                vertical: widget.isMobile
                    ? 4
                    : widget.isTablet
                    ? 6
                    : 8,
              ),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? activeCol.withValues(alpha: 0.15)
                    : widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(
                  widget.isMobile
                      ? 8
                      : widget.isTablet
                      ? 10
                      : 12,
                ),
                border: Border.all(
                  color: widget.isActive
                      ? activeCol.withValues(alpha: 0.4)
                      : widget.theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: widget.isMobile
                        ? 14
                        : widget.isTablet
                        ? 16
                        : 18,
                    color: color,
                  ),
                  if (widget.count != null && widget.count! > 0) ...[
                    SizedBox(
                      width: widget.isMobile
                          ? 4
                          : widget.isTablet
                          ? 6
                          : 8,
                    ),
                    Text(
                      '${widget.count}',
                      style: GoogleFonts.roboto(
                        color: color,
                        fontSize: widget.isMobile
                            ? 11
                            : widget.isTablet
                            ? 12
                            : 13,
                        fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Modern Replies Section
class ModernRepliesSection extends StatefulWidget {
  final String commentId;
  final ThemeData theme;
  final Video video;
  final MainController mainController;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  const ModernRepliesSection({
    super.key,
    required this.commentId,
    required this.theme,
    required this.video,
    required this.mainController,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  State<ModernRepliesSection> createState() => _ModernRepliesSectionState();
}

class _ModernRepliesSectionState extends State<ModernRepliesSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  final RxBool _isExpanded = false.obs;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repliesRef = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.video.id)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs
            .map((doc) => Reply.fromDocumentSnapshot(doc))
            .toList();

        return Stack(
          children: [
            // L-shaped connecting line
            Positioned(
              left: widget.isMobile ? -15 : -20,
              top: -10,
              bottom: 12,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    height: 2,
                    width: 15,
                    color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(
                left: widget.isMobile ? 10 : 20,
                top: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      _isExpanded.value = !_isExpanded.value;
                      if (_isExpanded.value) {
                        _expansionController.forward();
                      } else {
                        _expansionController.reverse();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Obx(() {
                        final isExpanded = _isExpanded.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Small Creator Avatar
                            UserAvatar(
                              radius: 10,
                              photoUrl: widget.video.thumbnailUrl,
                              displayName: widget.video.channelName,
                              backgroundColor: widget.theme.colorScheme.primary.withValues(alpha: 0.2),
                              fontSize: 10,
                              showBorder: false,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                              style: GoogleFonts.roboto(
                                color: widget.theme.colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: widget.theme.colorScheme.primary,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  SizeTransition(
                sizeFactor: _expansionAnimation,
                child: Container(
                  margin: EdgeInsets.only(
                    top: widget.isMobile
                        ? 12
                        : widget.isTablet
                        ? 16
                        : 20,
                  ),
                  child: Column(
                    children: replies.map((reply) {
                      return ModernReplyItem(
                        reply: reply,
                        theme: widget.theme,
                        video: widget.video,
                        mainController: widget.mainController,
                        isMobile: widget.isMobile,
                        isTablet: widget.isTablet,
                        isDesktop: widget.isDesktop,
                      );
                    }).toList(),
                  ),
                ),
              ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Modern Reply Item
class ModernReplyItem extends StatelessWidget {
  final Reply reply;
  final ThemeData theme;
  final Video video;
  final MainController mainController;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  const ModernReplyItem({
    super.key,
    required this.reply,
    required this.theme,
    required this.video,
    required this.mainController,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final avatarRadius = isMobile
        ? 14.0
        : isTablet
        ? 16.0
        : 18.0;

    final tag = 'video_${video.id}';
    final hasCommentsCtrl = Get.isRegistered<CommentsController>(tag: tag);
    final commentsController = hasCommentsCtrl
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: video), tag: tag);

    return Obx(() {
      final isLiked = commentsController.isReplyLikedByUser(reply.id);
      final isDisliked = commentsController.isReplyDislikedByUser(reply.id);

      return Container(
        margin: EdgeInsets.only(
          bottom: isMobile
              ? 12
              : isTablet
              ? 16
              : 20,
        ),
        padding: EdgeInsets.all(
          isMobile
              ? 12
              : isTablet
              ? 16
              : 20,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(
            isMobile
                ? 12
                : isTablet
                ? 16
                : 20,
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.2),
                    theme.colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: UserAvatar(
                radius: avatarRadius,
                photoUrl: reply.userProfilePicUrl,
                displayName: reply.userName,
                backgroundColor: Colors.transparent,
                textColor: theme.colorScheme.secondary,
                fontSize: isMobile
                    ? 10
                    : isTablet
                    ? 12
                    : 14,
                showBorder: false,
              ),
            ),
            SizedBox(
              width: isMobile
                  ? 10
                  : isTablet
                  ? 12
                  : 16,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reply.userName,
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile
                              ? 12
                              : isTablet
                              ? 13
                              : 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? 6
                            : isTablet
                            ? 8
                            : 10,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile
                              ? 4
                              : isTablet
                              ? 6
                              : 8,
                          vertical: isMobile
                              ? 2
                              : isTablet
                              ? 3
                              : 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 
                            0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            isMobile
                                ? 6
                                : isTablet
                                ? 8
                                : 10,
                          ),
                        ),
                        child: Text(
                          timeago.format(reply.createdAt.toDate()),
                          style: GoogleFonts.roboto(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: isMobile
                                ? 10
                                : isTablet
                                ? 11
                                : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: isMobile
                        ? 6
                        : isTablet
                        ? 8
                        : 10,
                  ),
                  Text(
                    reply.text,
                    style: GoogleFonts.roboto(
                      fontSize: isMobile
                          ? 13
                          : isTablet
                          ? 14
                          : 15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  SizedBox(
                    height: isMobile
                        ? 8
                        : isTablet
                        ? 10
                        : 12,
                  ),
                  Row(
                    children: [
                      ModernActionButton(
                        icon: isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                        count: reply.likeCount,
                        isActive: isLiked,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          commentsController.toggleReplyLike(
                            commentId: reply.commentId,
                            replyId: reply.id,
                            likeAsChannel: false,
                          );
                        },
                        theme: theme,
                        isMobile: isMobile,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(
                        width: isMobile
                            ? 12
                            : isTablet
                            ? 16
                            : 20,
                      ),
                      ModernActionButton(
                        icon: isDisliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
                        count: reply.dislikeCount,
                        isActive: isDisliked,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          commentsController.toggleReplyDislike(
                            commentId: reply.commentId,
                            replyId: reply.id,
                            dislikeAsChannel: false,
                          );
                        },
                        theme: theme,
                        isMobile: isMobile,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Show modernized reply input modal sheet
void showReplyInput(String commentId, {required Video video}) {
  showModalBottomSheet(
    context: Get.context!,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ModernReplyInput(videoId: video.id, commentId: commentId),
    ),
  );
}

/// Show sign-in prompt with modern styling
void showSignInPrompt(BuildContext context) {
  Get.snackbar(
    'Sign in required',
    'Please sign in to perform this action.',
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    colorText: Theme.of(context).colorScheme.onSurfaceVariant,
    borderRadius: 12,
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 4),
    mainButton: TextButton(
      onPressed: () {
        Get.back();
        Get.toNamed('/login');
      },
      child: Text(
        'Sign In',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}






