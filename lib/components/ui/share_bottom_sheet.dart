import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/theme/app_theme.dart';

class ShareBottomSheet extends StatefulWidget {
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? subtitle;
  final String? avatarUrl;
  final int? durationMs;
  final int? videoCount;
  final int? subscriberCount;
  final int? followerCount;
  final String? handle;
  final Duration? currentPosition;
  final String? channelName;
  final String? type;

  const ShareBottomSheet({
    super.key,
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.subtitle,
    this.avatarUrl,
    this.durationMs,
    this.videoCount,
    this.subscriberCount,
    this.followerCount,
    this.handle,
    this.currentPosition,
    this.channelName,
    this.type,
  });

  static void show({
    required String title,
    required String url,
    String? thumbnailUrl,
    String? subtitle,
    String? avatarUrl,
    int? durationMs,
    int? videoCount,
    int? subscriberCount,
    int? followerCount,
    String? handle,
    Duration? currentPosition,
    String? channelName,
    String? type,
  }) {
    Get.bottomSheet(
      ShareBottomSheet(
        title: title,
        url: url,
        thumbnailUrl: thumbnailUrl,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
        durationMs: durationMs,
        videoCount: videoCount,
        subscriberCount: subscriberCount,
        followerCount: followerCount,
        handle: handle,
        currentPosition: currentPosition,
        channelName: channelName,
        type: type,
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 300),
      exitBottomSheetDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final RxBool _startAtChecked = false.obs;
  final RxBool _showEmbedPanel = false.obs;
  final RxBool _showControls = true.obs;
  final RxBool _privacyMode = false.obs;

  String _detectType() {
    if (widget.type != null) return widget.type!;
    if (widget.currentPosition != null || widget.durationMs != null || widget.url.contains('/watch')) {
      return 'video';
    }
    if (widget.subscriberCount != null || widget.url.contains('/channel/') || (widget.handle != null && widget.handle!.startsWith('@'))) {
      return 'channel';
    }
    if (widget.videoCount != null && (widget.url.contains('/playlist') || widget.subtitle?.toLowerCase().contains('playlist') == true)) {
      return 'playlist';
    }
    if (widget.followerCount != null || widget.url.contains('/topic/') || widget.url.contains('/T/')) {
      return 'topic';
    }
    return 'video'; // Default fallback
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatMsDuration(int ms) {
    return _formatDuration(Duration(milliseconds: ms));
  }

  String _formatCount(int count) {
    if (count < 0) return '0';
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return count.toString();
  }

  String _getShareUrl() {
    if (!_startAtChecked.value || widget.currentPosition == null) return widget.url;
    final seconds = widget.currentPosition!.inSeconds;
    if (widget.url.contains('?')) {
      return '${widget.url}&t=$seconds';
    } else {
      return '${widget.url}?t=$seconds';
    }
  }

  String _extractVideoId() {
    try {
      final uri = Uri.parse(widget.url);
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v']!;
      }
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    } catch (_) {}
    return 'video_id';
  }

  String _getIframeCode() {
    final videoId = _extractVideoId();
    var embedUrl = 'https://www.truthworld.in/embed/$videoId';
    final params = <String>[];
    if (!_showControls.value) params.add('controls=0');
    if (_privacyMode.value) params.add('privacy=1');
    if (_startAtChecked.value && widget.currentPosition != null) {
      params.add('start=${widget.currentPosition!.inSeconds}');
    }
    if (params.isNotEmpty) {
      embedUrl += '?${params.join('&')}';
    }
    return '<iframe width="560" height="315" src="$embedUrl" title="TruthWorld video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>';
  }

  @override
  Widget build(BuildContext context) {
    final contentType = _detectType();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Obx(() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showEmbedPanel.value
              ? _buildEmbedPanel(context)
              : _buildMainPanel(context, contentType),
        )),
      ),
    );
  }

  Widget _buildMainPanel(BuildContext context, String contentType) {
    return Column(
      key: const ValueKey('main_panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                'Share',
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Get.back(),
              ),
            ],
          ),
        ),

        const Divider(color: AppColors.bgDivider, height: 1),

        // 1. Preview Card
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: _buildPreviewCard(contentType),
        ),

        // 2. Start At Checkbox (Video Only)
        if (contentType == 'video' && widget.currentPosition != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _startAtChecked.value,
                    activeColor: AppColors.brand,
                    checkColor: Colors.white,
                    side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      _startAtChecked.value = val ?? false;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    _startAtChecked.value = !_startAtChecked.value;
                  },
                  child: Text(
                    'Start at ${_formatDuration(widget.currentPosition!)}',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 3. Social Icons Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              _buildSocialIcon(
                icon: Icons.chat_bubble_rounded,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () => _shareToSocial('whatsapp'),
              ),
              _buildSocialIcon(
                icon: Icons.facebook_rounded,
                color: const Color(0xFF1877F2),
                label: 'Facebook',
                onTap: () => _shareToSocial('facebook'),
              ),
              _buildSocialIcon(
                icon: Icons.alternate_email_rounded,
                color: const Color(0xFF1DA1F2),
                label: 'X',
                onTap: () => _shareToSocial('twitter'),
              ),
              _buildSocialIcon(
                icon: Icons.telegram_rounded,
                color: const Color(0xFF0088CC),
                label: 'Telegram',
                onTap: () => _shareToSocial('telegram'),
              ),
              _buildSocialIcon(
                icon: Icons.mail_rounded,
                color: const Color(0xFFEA4335),
                label: 'Email',
                onTap: () => _shareToSocial('email'),
              ),
              if (contentType == 'video')
                _buildSocialIcon(
                  icon: Icons.code_rounded,
                  color: const Color(0xFF90A4AE),
                  label: 'Embed',
                  onTap: () => _showEmbedPanel.value = true,
                ),
              _buildSocialIcon(
                icon: Icons.more_horiz_rounded,
                color: AppColors.textSecondary,
                label: 'More',
                onTap: () => _shareNative(),
              ),
            ],
          ),
        ),

        // 4. Link Copy Section
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy Link',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getShareUrl(),
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _copyToClipboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Copy'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmbedPanel(BuildContext context) {
    return Column(
      key: const ValueKey('embed_panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const BackSymbol(color: AppColors.textPrimary),
                onPressed: () => _showEmbedPanel.value = false,
              ),
              const SizedBox(width: 8),
              Text(
                'Embed Video',
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Get.back(),
              ),
            ],
          ),
        ),

        const Divider(color: AppColors.bgDivider, height: 1),

        // Embed Code Box
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Iframe Embed Code',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          _getIframeCode(),
                          style: GoogleFonts.robotoMono(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _getIframeCode()));
                        Get.back();
                        Get.snackbar(
                          'Copied',
                          'Embed code copied to clipboard',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.success,
                          colorText: Colors.white,
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Copy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Embed Settings Checklist
              Text(
                'Embed Options',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // Checkbox 1: Show player controls
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _showControls.value,
                      activeColor: AppColors.brand,
                      checkColor: Colors.white,
                      side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        _showControls.value = val ?? true;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _showControls.value = !_showControls.value,
                    child: Text(
                      'Show player controls',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Checkbox 2: Privacy-enhanced mode
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _privacyMode.value,
                      activeColor: AppColors.brand,
                      checkColor: Colors.white,
                      side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        _privacyMode.value = val ?? false;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _privacyMode.value = !_privacyMode.value,
                    child: Text(
                      'Enable privacy-enhanced mode',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              // Checkbox 3: Start at offset (if video timestamp is present)
              if (widget.currentPosition != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _startAtChecked.value,
                        activeColor: AppColors.brand,
                        checkColor: Colors.white,
                        side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          _startAtChecked.value = val ?? false;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _startAtChecked.value = !_startAtChecked.value,
                      child: Text(
                        'Start at ${_formatDuration(widget.currentPosition!)}',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(String contentType) {
    switch (contentType) {
      case 'channel':
        return _buildChannelCard();
      case 'playlist':
        return _buildPlaylistCard();
      case 'topic':
        return _buildTopicCard();
      case 'video':
      default:
        return _buildVideoCard();
    }
  }

  Widget _buildVideoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail + Duration Overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 120,
                  height: 120 * 9 / 16,
                  color: AppColors.bgInput,
                  child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppColors.bgInput),
                          errorWidget: (context, url, err) => const Icon(Icons.play_circle_fill_rounded, color: AppColors.textTertiary, size: 36),
                        )
                      : const Icon(Icons.play_circle_fill_rounded, color: AppColors.textTertiary, size: 36),
                ),
              ),
              if (widget.durationMs != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatMsDuration(widget.durationMs!),
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Video Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.channelName ?? 'TruthWorld Creator',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: GoogleFonts.roboto(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Channel Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.bgInput,
              child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.bgInput),
                      errorWidget: (context, url, err) => const Icon(Icons.person_rounded, color: AppColors.textTertiary, size: 32),
                    )
                  : const Icon(Icons.person_rounded, color: AppColors.textTertiary, size: 32),
            ),
          ),
          const SizedBox(width: 16),

          // Channel Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.handle != null && widget.handle!.isNotEmpty
                      ? (widget.handle!.startsWith('@') ? widget.handle! : '@${widget.handle!}')
                      : '@channel',
                  style: GoogleFonts.roboto(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle ??
                      '${widget.subscriberCount != null ? '${_formatCount(widget.subscriberCount!)} subscribers' : 'Channel'} • ${widget.videoCount != null ? '${widget.videoCount} videos' : 'TruthWorld'}',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Playlist Thumbnail + Overlay Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 120,
                  height: 120 * 9 / 16,
                  color: AppColors.bgInput,
                  child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppColors.bgInput),
                          errorWidget: (context, url, err) => const Icon(Icons.playlist_play_rounded, color: AppColors.textTertiary, size: 36),
                        )
                      : const Icon(Icons.playlist_play_rounded, color: AppColors.textTertiary, size: 36),
                ),
              ),
              // Right overlay bar
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.videoCount ?? 0}',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Playlist Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.channelName ?? 'TruthWorld Playlist',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle ?? 'Playlist • ${widget.videoCount ?? 0} videos',
                  style: GoogleFonts.roboto(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Thumbnail with purple border / topic badge overlay
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.5), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 120,
                    height: 120 * 9 / 16,
                    color: AppColors.bgInput,
                    child: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.bgInput),
                            errorWidget: (context, url, err) => const Icon(Icons.tag_rounded, color: AppColors.textTertiary, size: 36),
                          )
                        : const Icon(Icons.tag_rounded, color: AppColors.textTertiary, size: 36),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Topic Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.handle != null && widget.handle!.isNotEmpty
                      ? '#${widget.handle!}'
                      : '#topic',
                  style: GoogleFonts.roboto(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle ??
                      '${widget.followerCount != null ? '${_formatCount(widget.followerCount!)} followers' : 'Topic'} • ${widget.videoCount != null ? '${widget.videoCount} videos' : 'TruthWorld'}',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToSocial(String platform) async {
    // Standard social share using SharePlus
    _shareNative();
  }

  void _shareNative() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Check this out on TruthWorld: ${widget.title}\n${_getShareUrl()}',
        subject: widget.title,
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _getShareUrl()));
    Get.back();
    Get.snackbar(
      'Copied',
      'Link copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }
}
