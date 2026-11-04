import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/credibility_chat_message.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/ai_credibility_chat_controller.dart';
import 'package:truthworld/features/video/presentation/views/ask_ai_screen.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// 💬 AiCredibilityChatSheet
///
/// Interactive conversational AI surface for inquiring about video credibility analysis
/// or deep-diving into a particular empirical claim.
class AiCredibilityChatSheet extends StatelessWidget {
  final Video video;
  final String scope; // 'video' | 'claim'
  final int? claimIndex;
  final String? claimText;
  final String? verdict;
  final List<dynamic>? allSources;
  final List<dynamic>? allClaims;
  final String? summary;
  final double? trustScore;
  final String? claimExplanation;
  final bool isEmbedded;
  final bool hideHeader;
  final VoidCallback? onClose;

  const AiCredibilityChatSheet({
    required this.video,
    this.scope = 'video',
    this.claimIndex,
    this.claimText,
    this.verdict,
    this.allSources,
    this.allClaims,
    this.summary,
    this.trustScore,
    this.claimExplanation,
    this.isEmbedded = false,
    this.hideHeader = false,
    this.onClose,
    super.key,
  });

  /// Opens the chat sheet smoothly as a modal bottom sheet
  static Future<T?> show<T>(
    BuildContext context, {
    required Video video,
    String scope = 'video',
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<dynamic>? allSources,
    List<dynamic>? allClaims,
    String? summary,
    double? trustScore,
    String? claimExplanation,
  }) async {
    final authService = Get.isRegistered<AuthService>() ? AuthService.to : null;
    final isSignedIn = authService?.isUserSignedIn ??
        (FirebaseAuth.instance.currentUser != null &&
            !FirebaseAuth.instance.currentUser!.isAnonymous);

    if (!isSignedIn) {
      AppSnackbar.info('Please sign in to access TruthWorld Ask AI.');
      await AuthService.prompt(context);
      return null;
    }

    final tag = '${video.id}_${scope}_${claimIndex ?? 'all'}';
    final ctrl = Get.put(AiCredibilityChatController(), tag: tag);
    ctrl.initScope(
      targetVideoId: video.id,
      targetScope: scope,
      video: video,
      targetClaimIndex: claimIndex,
      targetClaimText: claimText,
      targetVerdict: verdict,
      title: video.title,
      allSources: allSources,
      allClaims: allClaims,
      summary: summary,
      trustScore: trustScore,
      claimExplanation: claimExplanation,
    );

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiCredibilityChatSheet(
        video: video,
        scope: scope,
        claimIndex: claimIndex,
        claimText: claimText,
        verdict: verdict,
        allSources: allSources,
        allClaims: allClaims,
        summary: summary,
        trustScore: trustScore,
        claimExplanation: claimExplanation,
      ),
    );
  }

  AiCredibilityChatController get _ctrl {
    final tag = '${video.id}_${scope}_${claimIndex ?? 'all'}';
    final ctrl = Get.isRegistered<AiCredibilityChatController>(tag: tag)
        ? Get.find<AiCredibilityChatController>(tag: tag)
        : Get.put(AiCredibilityChatController(), tag: tag);

    if (ctrl.videoId.value != video.id || ctrl.scope.value != scope || ctrl.messages.isEmpty) {
      ctrl.initScope(
        targetVideoId: video.id,
        targetScope: scope,
        video: video,
        targetClaimIndex: claimIndex,
        targetClaimText: claimText,
        targetVerdict: verdict,
        title: video.title,
        allSources: allSources,
        allClaims: allClaims,
        summary: summary,
        trustScore: trustScore,
        claimExplanation: claimExplanation,
      );
    }
    return ctrl;
  }

  Future<void> _launchUrl(String? urlStr) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    await ClickableUrlText.launchUrlString(urlStr);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = MediaQuery.of(context).size.width >= TWBreakpoints.desktop;

    return Container(
      height: isEmbedded ? double.infinity : screenHeight * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure black canvas matching Image 1 & 2
        borderRadius: isEmbedded
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: isEmbedded ? null : Border.all(color: AppColors.bgDivider),
        boxShadow: isEmbedded
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
          child: Column(
            children: [
              _buildTopHandle(),
              _buildHeader(context),
              if (!hideHeader) const Divider(height: 1, color: AppColors.bgDivider),
              Expanded(child: _buildMessagesList()),
              _buildSuggestedChipsSection(),
              _buildInputBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHandle() {
    if (isEmbedded || hideHeader) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (hideHeader) return const SizedBox.shrink();
    final isClaim = scope == 'claim';
    final titleText = isClaim
        ? 'Truth AI • Claim #${(claimIndex ?? 0) + 1}'
        : 'Truth Intelligence AI';
    final subtitleText = isClaim && claimText != null && claimText!.isNotEmpty
        ? (claimText!.length > 60 ? '${claimText!.substring(0, 58)}…' : claimText!)
        : (video.title.isNotEmpty ? video.title : 'Credibility & Evidence Verification');

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 10 : 18, 6, isCompact ? 6 : 12, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 5 : 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
            ),
            child: TruthLottieAnimation.verifiedShield(size: isCompact ? 18 : 20),
          ),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 13.5 : 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isClaim && verdict != null && verdict!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            verdict!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 19, color: Colors.white70),
            tooltip: 'Clear conversation',
            padding: EdgeInsets.all(isCompact ? 2 : 5),
            constraints: BoxConstraints(minWidth: isCompact ? 26 : 30, minHeight: isCompact ? 26 : 30),
            visualDensity: VisualDensity.compact,
            onPressed: () => _ctrl.clearChat(),
          ),
          SizedBox(width: isCompact ? 1 : 2),
          IconButton(
            icon: const Icon(Icons.open_in_full_rounded, size: 18, color: Colors.white70),
            tooltip: 'Open as separate page',
            padding: EdgeInsets.all(isCompact ? 2 : 5),
            constraints: BoxConstraints(minWidth: isCompact ? 26 : 30, minHeight: isCompact ? 26 : 30),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (!isEmbedded && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              AskAiScreen.open(
                context,
                video: video,
                scope: scope,
                claimIndex: claimIndex,
                claimText: claimText,
                verdict: verdict,
                allSources: allSources,
                allClaims: allClaims,
                summary: summary,
                trustScore: trustScore,
                claimExplanation: claimExplanation,
              );
            },
          ),
          SizedBox(width: isCompact ? 1 : 2),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
            tooltip: 'Close',
            padding: EdgeInsets.all(isCompact ? 2 : 5),
            constraints: BoxConstraints(minWidth: isCompact ? 26 : 30, minHeight: isCompact ? 26 : 30),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Obx(() {
      final list = _ctrl.messages;

      return ListView.builder(
        controller: _ctrl.scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final msg = list[index];
          return _buildMessageItem(context, msg);
        },
      );
    });
  }

  Widget _buildMarkdownContent(String text, {required bool isStreaming}) {
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      final isHeader = line.trimLeft().startsWith('### ') ||
          line.trimLeft().startsWith('## ') ||
          line.trimLeft().startsWith('# ');

      if (isHeader) {
        final headerContent = line.trimLeft().replaceFirst(RegExp(r'^#{1,3}\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  ..._buildFormattedTextSpans(headerContent),
                  if (isLastLine && isStreaming) _buildStreamingCursorSpan(),
                ],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final isBullet = line.trimLeft().startsWith('•') ||
          line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ');

      if (isBullet) {
        final trimmed = line.trimLeft();
        final content = trimmed.startsWith('•')
            ? trimmed.substring(1).trimLeft()
            : trimmed.substring(2).trimLeft();

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        ..._buildFormattedTextSpans(content),
                        if (isLastLine && isStreaming) _buildStreamingCursorSpan(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  ..._buildFormattedTextSpans(line),
                  if (isLastLine && isStreaming) _buildStreamingCursorSpan(),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  InlineSpan _buildStreamingCursorSpan() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Obx(
        () => Opacity(
          opacity: _ctrl.cursorVisible.value ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            width: 7,
            height: 15,
            decoration: BoxDecoration(
              color: const Color(0xFF388BFD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildFormattedTextSpans(String text) {
    if (text.isEmpty) return const [];
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    var lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        spans.addAll(
          ClickableUrlText.parseSpans(
            segment,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white,
              height: 1.55,
              letterSpacing: 0.1,
            ),
          ),
        );
      }
      final boldContent = match.group(1) ?? '';
      spans.addAll(
        ClickableUrlText.parseSpans(
          boldContent,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.55,
            letterSpacing: 0.1,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.addAll(
        ClickableUrlText.parseSpans(
          text.substring(lastIndex),
          style: TextStyle(
            fontSize: 14.5,
            color: Colors.white,
            height: 1.55,
            letterSpacing: 0.1,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildMessageItem(BuildContext context, CredibilityChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1D58A7), // Truthworld blue pill matching Image 1 & 2
            borderRadius: BorderRadius.circular(22),
          ),
          child: ClickableUrlText(
            text: message.text,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    }

    // AI Message: If waiting for first token, show the pulsing blue dot (Image 1)
    if (message.text.isEmpty && message.isStreaming) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 24, left: 4),
          child: const _PulsingAiDot(),
        ),
      );
    }

    // AI Message with text: Render directly on black canvas (Image 2)
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMarkdownContent(message.text, isStreaming: message.isStreaming),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'VERIFIED CITATIONS (${message.sources.length})',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              ...message.sources.map(_buildSourcePill),
            ],
            if (message.disclaimer != null && message.disclaimer!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message.disclaimer!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePill(UISource source) {
    final domain = source.domain ?? SourceAvatarService.cleanDomain(source.url);
    final publisher = source.publisher ?? domain;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: ClipOval(
            child: Container(
              width: 26,
              height: 26,
              color: Colors.white.withValues(alpha: 0.08),
              child: SourceAvatarService.buildAvatar(
                domain: domain,
                publisher: publisher,
                url: source.url,
                avatarUrl: source.avatarUrl,
                size: 26,
              ),
            ),
          ),
          title: Text(
            source.title.isNotEmpty ? source.title : publisher,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            publisher,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: const Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: Colors.white70,
          ),
          onTap: () => _launchUrl(source.url),
        ),
      ),
    );
  }

  Widget _buildSuggestedChipsSection() {
    return Obx(() {
      final prompts = _ctrl.suggestedPrompts;
      if (prompts.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: prompts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final prompt = prompts[i];
            return ActionChip(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              avatar: const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white70),
              label: Text(
                prompt,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              onPressed: () => _ctrl.sendMessage(prompt),
            );
          },
        ),
      );
    });
  }

  Widget _buildInputBar(BuildContext context) {
    final isSignedIn = Get.isRegistered<AuthService>()
        ? AuthService.to.isUserSignedIn
        : (FirebaseAuth.instance.currentUser != null && !FirebaseAuth.instance.currentUser!.isAnonymous);

    if (!isSignedIn) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          border: Border(top: BorderSide(color: AppColors.bgDivider, width: 0.8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign in to ask questions about this video',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black, // Strictly black on white
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => AuthService.prompt(context),
              child: Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.black, // Strictly black on white
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() {
      final isSuspended = _ctrl.isSuspended.value;
      if (isSuspended) {
        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(top: BorderSide(color: Colors.redAccent, width: 0.8)),
          ),
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _ctrl.suspensionNotice.value.isNotEmpty
                      ? _ctrl.suspensionNotice.value
                      : 'Ask AI is temporarily restricted for your account.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          border: Border(top: BorderSide(color: AppColors.bgDivider, width: 0.8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                ),
                child: TextField(
                  controller: _ctrl.textController,
                  style: TextStyle(color: Colors.white, fontSize: 13.5),
                  maxLines: null,
                  maxLength: 600,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      currentLength > 500
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '$currentLength/$maxLength',
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            )
                          : null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ctrl.sendMessage(),
                  decoration: InputDecoration(
                    hintText: scope == 'claim'
                        ? 'Ask about this claim or sources…'
                        : 'Ask about video credibility or claims…',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Obx(() {
              final loading = _ctrl.isLoading.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  color: Colors.white, // Strictly white background
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: loading ? null : () => _ctrl.sendMessage(),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black, // Strictly black on white
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.black, // Strictly black on white (Zero white-on-white policy)
                          size: 20,
                        ),
                  tooltip: 'Send question',
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

/// 🔵 Pulsing Blue Dot - ChatGPT-style initial waiting state (Image 1)
class _PulsingAiDot extends StatefulWidget {
  const _PulsingAiDot();

  @override
  State<_PulsingAiDot> createState() => _PulsingAiDotState();
}

class _PulsingAiDotState extends State<_PulsingAiDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF388BFD),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66388BFD),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
