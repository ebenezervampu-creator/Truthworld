import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/components/ui/share/panels/share_embed_panel.dart';
import 'package:truthworld/components/ui/share/share_preview_cards.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/clip_share_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:truthworld/components/ui/share/panels/share_embed_panel.dart';
export 'package:truthworld/components/ui/share/share_preview_cards.dart';

class ShareBottomSheet extends StatefulWidget {
  const ShareBottomSheet({
    required this.title,
    required this.url,
    super.key,
    this.thumbnailUrl,
    this.bannerUrl,
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
    this.clipStartTime,
    this.clipEndTime,
    this.videoUrl,
    this.videoId,
    this.videoTitle,
  });
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? bannerUrl;
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
  final double? clipStartTime;
  final double? clipEndTime;
  final String? videoUrl;
  final String? videoId;
  final String? videoTitle;

  static void show({
    required String title,
    required String url,
    String? thumbnailUrl,
    String? bannerUrl,
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
    double? clipStartTime,
    double? clipEndTime,
    String? videoUrl,
    String? videoId,
    String? videoTitle,
  }) {
    Get.bottomSheet(
      ShareBottomSheet(
        title: title,
        url: url,
        thumbnailUrl: thumbnailUrl,
        bannerUrl: bannerUrl,
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
        clipStartTime: clipStartTime,
        clipEndTime: clipEndTime,
        videoUrl: videoUrl,
        videoId: videoId,
        videoTitle: videoTitle,
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

  final RxBool _isPreparingClip = false.obs;
  final Rxn<File> _clipFile = Rxn<File>();
  final RxDouble _clipProgress = 0.0.obs;
  final RxString _clipStatus = ''.obs;

  @override
  void initState() {
    super.initState();
    final contentType = _detectType();
    if (contentType == 'clip') {
      _prepareClipFile();
    }
  }

  Future<File?> _prepareClipFile() async {
    const canGenerateVideo = !kIsWeb;
    if (!canGenerateVideo) return null;

    if (_clipFile.value != null && await _clipFile.value!.exists()) {
      return _clipFile.value;
    }
    _isPreparingClip.value = true;
    _clipProgress.value = 0.1;
    _clipStatus.value = 'Preparing TikTok-style Truthworld clip...';

    final start = widget.clipStartTime ?? 0.0;
    final end = widget.clipEndTime ?? ((widget.durationMs ?? 15000) / 1000.0);
    final vId = widget.videoId ?? _extractVideoId();

    try {
      final file = await ClipShareService.instance.getOrGenerateClipFile(
        videoId: vId,
        videoUrl: widget.videoUrl,
        channelName: widget.channelName,
        videoTitle: widget.videoTitle ?? widget.title,
        clipTitle: widget.title,
        startSeconds: start,
        endSeconds: end,
        onProgress: (progress, status) {
          if (!mounted) return;
          _clipProgress.value = progress;
          _clipStatus.value = status;
        },
      );
      if (!mounted) return file;
      if (file != null && await file.exists()) {
        _clipFile.value = file;
        _clipProgress.value = 1.0;
        _clipStatus.value = 'Clip ready!';
        return file;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ShareBottomSheet._prepareClipFile',
      );
    } finally {
      if (mounted) {
        _isPreparingClip.value = false;
      }
    }
    return null;
  }

  void _showTikTokExportDialog({
    required String title,
    required RxDouble progress,
    required RxString status,
    required VoidCallback onCancel,
  }) {
    Get.dialog<void>(
      PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) onCancel();
        },
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => LinearProgressIndicator(
                      value: progress.value,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      status.value,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      onCancel();
                      Get.back<void>();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _exportAndShareClipVideo({String? target}) async {
    final start = widget.clipStartTime ?? 0.0;
    final end = widget.clipEndTime ?? ((widget.durationMs ?? 15000) / 1000.0);
    final vId = widget.videoId ?? _extractVideoId();

    final shareUrl = ClipShareService.buildClipUrl(
      videoId: vId,
      startSeconds: start,
      endSeconds: end,
      clipTitle: widget.title,
    );

    final caption = ClipShareService.buildWatermarkCaption(
      clipTitle: widget.title,
      videoTitle: widget.videoTitle ?? widget.title,
      channelName: widget.channelName,
      startSeconds: start,
      endSeconds: end,
      clipUrl: shareUrl,
    );

    const canGenerateVideo = !kIsWeb;

    var file = _clipFile.value;
    var cancelled = false;

    if (canGenerateVideo && (file == null || !await file.exists())) {
      _showTikTokExportDialog(
        title: 'Exporting TikTok-style clip...',
        progress: _clipProgress,
        status: _clipStatus,
        onCancel: () => cancelled = true,
      );

      file = await _prepareClipFile();

      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
    }

    if (cancelled) return;

    final hasVideo = file != null && await file.exists();
    if (canGenerateVideo && !hasVideo) {
      AppSnackbar.info(
        'Video file could not be generated. Sharing clip link instead.',
        title: 'Sharing Clip',
      );
    }

    final xFile = hasVideo
        ? XFile(
            file.path,
            mimeType: 'video/mp4',
            name: '${widget.title} (Truthworld Clip).mp4',
          )
        : null;

    Future<void> shareVideoFile() async {
      if (Get.isBottomSheetOpen ?? false) Get.back<void>();
      if (xFile != null) {
        await SharePlus.instance.share(
          ShareParams(files: [xFile], text: caption, subject: widget.title),
        );
      } else if (kIsWeb) {
        var sourceUrl = widget.videoUrl;
        if (sourceUrl == null || sourceUrl.isEmpty) {
          sourceUrl =
              await ClipShareService.instance.resolveVideoSourceUrl(vId);
        }
        if (sourceUrl != null && sourceUrl.isNotEmpty) {
          final safeTitle =
              widget.title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
          await DownloadHelper.downloadFromUrl(
            sourceUrl,
            'Truthworld_${safeTitle}_Clip.mp4',
          );
        }
        await _shareDirectToPlatform(
          target ?? 'more',
          caption: caption,
          shareUrl: shareUrl,
        );
      } else {
        await _shareDirectToPlatform(
          target ?? 'more',
          caption: caption,
          shareUrl: shareUrl,
        );
      }
    }

    if (kIsWeb && (target == 'whatsapp' || target == 'whatsapp_status')) {
      await _showAppGuideDialog(
        emoji: '🎬',
        appName: 'WhatsApp',
        iconColor: const Color(0xFF25D366),
        steps:
            '1. Your video clip is downloading to your computer.\n\n'
            '2. In WhatsApp, click 📎 (Attach) > Photos & Videos.\n\n'
            '3. Select the downloaded clip to send it directly as a video message!',
        confirmText: 'Got it — Open WhatsApp',
        confirmColor: const Color(0xFF25D366),
      );
      await shareVideoFile();
      return;
    }

    if (xFile == null && !kIsWeb) {
      await shareVideoFile();
      return;
    }

    switch (target) {
      case 'whatsapp_status':
        await _showWhatsAppStatusGuideDialog();
        await shareVideoFile();

      case 'instagram':
        await _showAppGuideDialog(
          emoji: '📸',
          appName: 'Instagram',
          iconColor: const Color(0xFFDC2743),
          steps: 'Your Truthworld clip will open in the share sheet.\n\n'
              'In the share sheet:\n'
              '1. Tap "Instagram"\n'
              '2. Select "Reels" or "Story" to post the clip',
          confirmText: 'Got it — Open Instagram',
          confirmColor: const Color(0xFFBC1888),
        );
        await shareVideoFile();

      case 'tiktok':
        await _showAppGuideDialog(
          emoji: '🎵',
          appName: 'TikTok',
          iconColor: const Color(0xFF010101),
          steps: 'Your Truthworld watermarked clip will open in the share sheet.\n\n'
              'In the share sheet:\n'
              '1. Tap "TikTok"\n'
              '2. TikTok opens the video in its editor — add caption and post!',
          confirmText: 'Got it — Open TikTok',
          confirmColor: const Color(0xFFFF0050),
        );
        await shareVideoFile();

      default:
        // WhatsApp chat, Telegram, Facebook, X, More — all attach video directly
        await shareVideoFile();
    }
  }

  Future<void> _showWhatsAppStatusGuideDialog() => _showAppGuideDialog(
        emoji: '📲',
        appName: 'WhatsApp Status',
        iconColor: const Color(0xFF25D366),
        steps: 'Your Truthworld watermarked video clip will open in WhatsApp.\n\n'
            'To post it as a Status:\n'
            '1. Tap the WhatsApp icon in the share sheet\n'
            '2. Select "My Status" at the top',
        confirmText: 'Got it — Open WhatsApp',
        confirmColor: const Color(0xFF25D366),
      );

  Future<void> _showAppGuideDialog({
    required String emoji,
    required String appName,
    required Color iconColor,
    required String steps,
    required String confirmText,
    required Color confirmColor,
  }) async {
    await Get.dialog<void>(
      Dialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share to $appName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                steps,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: Get.back<void>,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveClipToDevice() async {
    final start = widget.clipStartTime ?? 0.0;
    final end = widget.clipEndTime ?? ((widget.durationMs ?? 15000) / 1000.0);
    final vId = widget.videoId ?? _extractVideoId();

    if (kIsWeb) {
      if (Get.isBottomSheetOpen ?? false) Get.back<void>();
      var sourceUrl = widget.videoUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        sourceUrl = await ClipShareService.instance.resolveVideoSourceUrl(vId);
      }
      if (sourceUrl != null && sourceUrl.isNotEmpty) {
        final safeTitle =
            widget.title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
        await DownloadHelper.downloadFromUrl(
          sourceUrl,
          'Truthworld_${safeTitle}_Clip.mp4',
        );
        AppSnackbar.success(
          'Truthworld video clip is downloading to your computer.',
          title: 'Downloading Clip',
        );
        return;
      }
    }

    var cancelled = false;

    _showTikTokExportDialog(
      title: 'Saving video to gallery...',
      progress: _clipProgress,
      status: _clipStatus,
      onCancel: () => cancelled = true,
    );

    final savedPath = await ClipShareService.instance.saveClipToDevice(
      videoId: vId,
      clipTitle: widget.title,
      videoUrl: widget.videoUrl,
      startSeconds: start,
      endSeconds: end,
      onProgress: (progress, status) {
        _clipProgress.value = progress;
        _clipStatus.value = status;
      },
    );

    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }

    if (cancelled) return;

    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }

    if (savedPath != null) {
      AppSnackbar.success(
        'Truthworld watermarked video clip saved successfully',
        title: 'Saved to Gallery',
      );
    } else {
      AppSnackbar.error(
        'Could not save video clip to device. Please try again.',
      );
    }
  }

  void _copyClipLink() {
    final start = widget.clipStartTime ?? 0.0;
    final end = widget.clipEndTime ?? ((widget.durationMs ?? 15000) / 1000.0);
    final vId = widget.videoId ?? _extractVideoId();
    final clipUrl = ClipShareService.buildClipUrl(
      videoId: vId,
      startSeconds: start,
      endSeconds: end,
      clipTitle: widget.title,
    );

    Clipboard.setData(ClipboardData(text: clipUrl));
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
    AppSnackbar.info(
      'Clip link copied to clipboard',
      title: 'Copied',
    );
  }

  void _shareLinkOnly() {
    final start = widget.clipStartTime ?? 0.0;
    final end = widget.clipEndTime ?? ((widget.durationMs ?? 15000) / 1000.0);
    final vId = widget.videoId ?? _extractVideoId();
    final clipUrl = ClipShareService.buildClipUrl(
      videoId: vId,
      startSeconds: start,
      endSeconds: end,
      clipTitle: widget.title,
    );

    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }

    SharePlus.instance.share(
      ShareParams(
        text: 'Watch "${widget.title}" clip on Truthworld:\n$clipUrl',
        subject: widget.title,
      ),
    );
  }

  String _detectType() {
    if (widget.type != null) return widget.type!;
    if (widget.clipStartTime != null ||
        widget.clipEndTime != null ||
        widget.url.contains('clipTitle') ||
        (widget.url.contains('start=') && widget.url.contains('end='))) {
      return 'clip';
    }
    if (widget.currentPosition != null ||
        widget.durationMs != null ||
        widget.url.contains('/watch')) {
      return 'video';
    }
    if (widget.subscriberCount != null ||
        widget.url.contains('/channel/') ||
        (widget.handle != null && widget.handle!.startsWith('@'))) {
      return 'channel';
    }
    if (widget.videoCount != null &&
        (widget.url.contains('/playlist') ||
            (widget.subtitle?.toLowerCase().contains('playlist') ?? false))) {
      return 'playlist';
    }
    if (widget.followerCount != null ||
        widget.url.contains('/topic/') ||
        widget.url.contains('/T/')) {
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
    if (!_startAtChecked.value || widget.currentPosition == null) {
      return widget.url;
    }
    final seconds = widget.currentPosition!.inSeconds;
    if (widget.url.contains('?')) {
      return '${widget.url}&t=$seconds';
    } else {
      return '${widget.url}?t=$seconds';
    }
  }

  String _extractVideoId() {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v']!;
      }
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    }
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
            color: AppColors.bgPage.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Obx(
          () => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showEmbedPanel.value
                ? _buildEmbedPanel(context)
                : _buildMainPanel(context, contentType),
          ),
        ),
      ),
    );
  }

  Widget _buildTikTokActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
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

  Widget _buildClipAppIcon({
    required String label,
    required Gradient gradient,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Center(child: child),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
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

  Widget _buildTikTokClipPanel(BuildContext context) {
    return Column(
      key: const ValueKey('tiktok_clip_panel'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              const Text(
                'Share video clip to',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: Get.back,
              ),
            ],
          ),
        ),

        // Clip Preview Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: _buildClipCard(),
        ),

        // Section 1: TikTok Style Social Apps Row
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            'Share Video',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            children: [
              _buildSocialIcon(
                imageAsset: 'assets/icons/whatsapp.png',
                label: 'WhatsApp',
                onTap: () => _exportAndShareClipVideo(target: 'whatsapp'),
              ),
              _buildSocialIcon(
                icon: Icons.camera_alt_rounded,
                label: 'Status',
                onTap: () => _exportAndShareClipVideo(target: 'whatsapp_status'),
              ),
              _buildClipAppIcon(
                label: 'Instagram',
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF09433),
                    Color(0xFFE6683C),
                    Color(0xFFDC2743),
                    Color(0xFFCC2366),
                    Color(0xFFBC1888),
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onTap: () => _exportAndShareClipVideo(target: 'instagram'),
              ),
              _buildClipAppIcon(
                label: 'TikTok',
                gradient: const LinearGradient(
                  colors: [Color(0xFF010101), Color(0xFF161616)],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 14,
                      top: 13,
                      child: Text(
                        '♪',
                        style: TextStyle(
                          color: Color(0xFF00F2EA),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 13,
                      top: 11,
                      child: Text(
                        '♪',
                        style: TextStyle(
                          color: Color(0xFFFF0050),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '♪',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                onTap: () => _exportAndShareClipVideo(target: 'tiktok'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/telegram.png',
                label: 'Telegram',
                onTap: () => _exportAndShareClipVideo(target: 'telegram'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/facebook.png',
                label: 'Facebook',
                onTap: () => _exportAndShareClipVideo(target: 'facebook'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/x.png',
                label: 'X',
                onTap: () => _exportAndShareClipVideo(target: 'x'),
              ),
              _buildSocialIcon(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: () => _exportAndShareClipVideo(target: 'more'),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: AppColors.bgDivider, height: 16),
        ),

        // Section 2: Actions Row (Save Video, Copy Link, Share Link)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            'Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
          child: Row(
            children: [
              _buildTikTokActionButton(
                icon: Icons.download_rounded,
                label: 'Save Video',
                onTap: _saveClipToDevice,
              ),
              _buildTikTokActionButton(
                icon: Icons.link_rounded,
                label: 'Copy Link',
                onTap: _copyClipLink,
              ),
              _buildTikTokActionButton(
                icon: Icons.share_outlined,
                label: 'Share Link',
                onTap: _shareLinkOnly,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainPanel(BuildContext context, String contentType) {
    if (contentType == 'clip') {
      return _buildTikTokClipPanel(context);
    }

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
              const Text(
                'Share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: Get.back,
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
                    checkColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.textSecondary,
                      width: 1.5,
                    ),
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
                    style: const TextStyle(
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
                imageAsset: 'assets/icons/whatsapp.png',
                label: 'WhatsApp',
                onTap: () => _shareToSocial('whatsapp'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/facebook.png',
                label: 'Facebook',
                onTap: () => _shareToSocial('facebook'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/x.png',
                label: 'X',
                onTap: () => _shareToSocial('twitter'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/telegram.png',
                label: 'Telegram',
                onTap: () => _shareToSocial('telegram'),
              ),
              _buildSocialIcon(
                imageAsset: 'assets/icons/email.png',
                label: 'Email',
                onTap: () => _shareToSocial('email'),
              ),
              if (contentType == 'video')
                _buildSocialIcon(
                  icon: Icons.code_rounded,
                  label: 'Embed',
                  onTap: () => _showEmbedPanel.value = true,
                ),
              _buildSocialIcon(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: _shareNative,
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
              const Text(
                'Copy Link',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                        foregroundColor: Colors.black,
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
    return ShareEmbedPanel(
      getIframeCode: _getIframeCode,
      onBack: () => _showEmbedPanel.value = false,
      showControls: _showControls,
      privacyMode: _privacyMode,
      startAtChecked: _startAtChecked,
      currentPosition: widget.currentPosition,
    );
  }

  Widget _buildPreviewCard(String contentType) {
    return SharePreviewCard(
      contentType: contentType,
      title: widget.title,
      thumbnailUrl: widget.thumbnailUrl,
      bannerUrl: widget.bannerUrl,
      subtitle: widget.subtitle,
      avatarUrl: widget.avatarUrl,
      durationMs: widget.durationMs,
      videoCount: widget.videoCount,
      subscriberCount: widget.subscriberCount,
      followerCount: widget.followerCount,
      handle: widget.handle,
      channelName: widget.channelName,
      clipStartTime: widget.clipStartTime,
      clipEndTime: widget.clipEndTime,
      clipFile: _clipFile,
      clipStatus: _clipStatus,
      isPreparingClip: _isPreparingClip,
    );
  }

  // Backward compatibility delegates
  Widget _buildClipCard() => _buildPreviewCard('clip');
  Widget _buildVideoCard() => _buildPreviewCard('video');
  Widget _buildChannelCard() => _buildPreviewCard('channel');
  Widget _buildPlaylistCard() => _buildPreviewCard('playlist');
  Widget _buildTopicCard() => _buildPreviewCard('topic');

  Widget _buildSocialIcon({
    required String label,
    required VoidCallback onTap,
    String? imageAsset,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E22),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.share_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      )
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
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

  String _buildShareMessage(String shareUrl) {
    final contentType = _detectType();
    if (contentType == 'clip') {
      final start = widget.clipStartTime ?? 0.0;
      final end = widget.clipEndTime ?? ((widget.durationMs ?? 15000) / 1000.0);
      return ClipShareService.buildWatermarkCaption(
        clipTitle: widget.title,
        videoTitle: widget.videoTitle ?? widget.title,
        channelName: widget.channelName,
        startSeconds: start,
        endSeconds: end,
        clipUrl: shareUrl,
      );
    } else if (contentType == 'channel') {
      final cleanHandle = (widget.handle ?? '').replaceAll(RegExp('^@'), '').trim();
      final handleStr = cleanHandle.isNotEmpty ? ' (@$cleanHandle)' : '';
      return 'Check out ${widget.title}$handleStr on TruthWorld:\n$shareUrl';
    } else if (contentType == 'playlist') {
      return 'Check out "${widget.title}" playlist on TruthWorld:\n$shareUrl';
    } else if (contentType == 'topic') {
      final topicName = widget.title.replaceAll(RegExp('^[#Tt]/'), '').trim();
      return 'Explore #$topicName on TruthWorld:\n$shareUrl';
    } else {
      final byChannel = (widget.channelName != null &&
              widget.channelName!.isNotEmpty &&
              widget.channelName != 'Channel' &&
              widget.channelName != 'TruthWorld Creator' &&
              !widget.title.toLowerCase().contains(widget.channelName!.toLowerCase()))
          ? ' by ${widget.channelName}'
          : '';
      return 'Watch "${widget.title}"$byChannel on TruthWorld:\n$shareUrl';
    }
  }

  Future<void> _shareToSocial(String platform) async {
    final contentType = _detectType();
    if (contentType == 'clip') {
      await _exportAndShareClipVideo(target: platform);
      return;
    }

    final shareUrl = _getShareUrl();
    final text = _buildShareMessage(shareUrl);
    await _shareDirectToPlatform(platform, caption: text, shareUrl: shareUrl);
  }

  Future<void> _shareDirectToPlatform(
    String platform, {
    required String caption,
    required String shareUrl,
  }) async {
    if (Get.isBottomSheetOpen ?? false) Get.back<void>();

    final encodedText = Uri.encodeComponent(caption);
    final encodedUrl = Uri.encodeComponent(shareUrl);
    final encodedTitle = Uri.encodeComponent(widget.title);

    try {
      switch (platform) {
        case 'whatsapp':
        case 'whatsapp_status':
          // WhatsApp direct share scheme opens WhatsApp's share picker (Status & Friends)
          final whatsappUri = Uri.parse('whatsapp://send?text=$encodedText');
          final webUri = Uri.parse(
            'https://api.whatsapp.com/send?text=$encodedText',
          );
          final waMeUri = Uri.parse('https://wa.me/?text=$encodedText');

          if (await canLaunchUrl(whatsappUri)) {
            await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(webUri)) {
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(waMeUri)) {
            await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
          } else {
            await SharePlus.instance.share(
              ShareParams(text: caption, subject: widget.title),
            );
          }

        case 'facebook':
          final fbAppUri = Uri.parse('fb://facewebmodal/f?href=$encodedUrl');
          final fbWebUri = Uri.parse(
            'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl',
          );

          if (await canLaunchUrl(fbAppUri)) {
            await launchUrl(fbAppUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(fbWebUri)) {
            await launchUrl(fbWebUri, mode: LaunchMode.externalApplication);
          } else {
            await SharePlus.instance.share(
              ShareParams(text: caption, subject: widget.title),
            );
          }

        case 'twitter':
        case 'x':
          final twitterAppUri = Uri.parse(
            'twitter://post?message=$encodedText',
          );
          final twitterWebUri = Uri.parse(
            'https://twitter.com/intent/tweet?text=$encodedText',
          );

          if (await canLaunchUrl(twitterAppUri)) {
            await launchUrl(
              twitterAppUri,
              mode: LaunchMode.externalApplication,
            );
          } else if (await canLaunchUrl(twitterWebUri)) {
            await launchUrl(
              twitterWebUri,
              mode: LaunchMode.externalApplication,
            );
          } else {
            await SharePlus.instance.share(
              ShareParams(text: caption, subject: widget.title),
            );
          }

        case 'telegram':
          final tgAppUri = Uri.parse('tg://msg?text=$encodedText');
          final tgWebUri = Uri.parse(
            'https://t.me/share/url?url=$encodedUrl&text=$encodedText',
          );

          if (await canLaunchUrl(tgAppUri)) {
            await launchUrl(tgAppUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(tgWebUri)) {
            await launchUrl(tgWebUri, mode: LaunchMode.externalApplication);
          } else {
            await SharePlus.instance.share(
              ShareParams(text: caption, subject: widget.title),
            );
          }

        case 'email':
          final mailUri = Uri.parse(
            'mailto:?subject=$encodedTitle&body=$encodedText',
          );

          if (await canLaunchUrl(mailUri)) {
            await launchUrl(mailUri, mode: LaunchMode.externalApplication);
          } else {
            await SharePlus.instance.share(
              ShareParams(text: caption, subject: widget.title),
            );
          }

        default:
          await SharePlus.instance.share(
            ShareParams(text: caption, subject: widget.title),
          );
      }
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: caption, subject: widget.title),
      );
    }
  }

  Future<void> _shareNative() async {
    final contentType = _detectType();
    if (contentType == 'clip') {
      await _exportAndShareClipVideo();
      return;
    }

    final shareUrl = _getShareUrl();
    await SharePlus.instance.share(
      ShareParams(
        text: _buildShareMessage(shareUrl),
        subject: widget.title,
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _getShareUrl()));
    Get.back();
    AppSnackbar.info(
      'Link copied to clipboard',
      title: 'Copied',
    );
  }
}
