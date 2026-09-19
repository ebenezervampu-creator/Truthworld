import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/components/ui/share/utils/share_utils.dart';
import 'package:truthworld/core/services/clip_share_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareDispatcher {
  const ShareDispatcher._();

  static String buildShareMessage({
    required String title,
    required String shareUrl,
    required String contentType,
    String? channelName,
    String? handle,
    String? videoTitle,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
  }) {
    if (contentType == 'clip') {
      final start = clipStartTime ?? 0.0;
      final end = clipEndTime ?? ((durationMs ?? 15000) / 1000.0);
      return ClipShareService.buildWatermarkCaption(
        clipTitle: title,
        videoTitle: videoTitle ?? title,
        channelName: channelName,
        startSeconds: start,
        endSeconds: end,
        clipUrl: shareUrl,
      );
    } else if (contentType == 'channel') {
      final cleanHandle = (handle ?? '').replaceAll(RegExp('^@'), '').trim();
      final handleStr = cleanHandle.isNotEmpty ? ' (@$cleanHandle)' : '';
      return 'Check out $title$handleStr on TruthWorld:\n$shareUrl';
    } else if (contentType == 'playlist') {
      return 'Check out "$title" playlist on TruthWorld:\n$shareUrl';
    } else if (contentType == 'topic') {
      final topicName = title.replaceAll(RegExp('^[#Tt]/'), '').trim();
      return 'Explore #$topicName on TruthWorld:\n$shareUrl';
    } else {
      final byChannel = (channelName != null &&
              channelName.isNotEmpty &&
              channelName != 'Channel' &&
              channelName != 'TruthWorld Creator' &&
              !title.toLowerCase().contains(channelName.toLowerCase()))
          ? ' by $channelName'
          : '';
      return 'Watch "$title"$byChannel on TruthWorld:\n$shareUrl';
    }
  }

  static Future<void> shareDirectToPlatform({
    required String platform,
    required String caption,
    required String shareUrl,
    required String title,
  }) async {
    if (Get.isBottomSheetOpen ?? false) Get.back<void>();

    final encodedText = Uri.encodeComponent(caption);
    final encodedUrl = Uri.encodeComponent(shareUrl);
    final encodedTitle = Uri.encodeComponent(title);

    try {
      switch (platform) {
        case 'whatsapp':
        case 'whatsapp_status':
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
              ShareParams(text: caption, subject: title),
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
              ShareParams(text: caption, subject: title),
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
              ShareParams(text: caption, subject: title),
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
              ShareParams(text: caption, subject: title),
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
              ShareParams(text: caption, subject: title),
            );
          }

        default:
          await SharePlus.instance.share(
            ShareParams(text: caption, subject: title),
          );
      }
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: caption, subject: title),
      );
    }
  }

  static Future<void> shareToSocial({
    required String platform,
    required String title,
    required String url,
    required bool startAtChecked,
    required String contentType,
    Duration? currentPosition,
    String? channelName,
    String? handle,
    String? videoTitle,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
  }) async {
    final shareUrl = ShareUtils.getShareUrl(
      url: url,
      startAtChecked: startAtChecked,
      currentPosition: currentPosition,
    );
    final text = buildShareMessage(
      title: title,
      shareUrl: shareUrl,
      contentType: contentType,
      channelName: channelName,
      handle: handle,
      videoTitle: videoTitle,
      clipStartTime: clipStartTime,
      clipEndTime: clipEndTime,
      durationMs: durationMs,
    );
    await shareDirectToPlatform(
      platform: platform,
      caption: text,
      shareUrl: shareUrl,
      title: title,
    );
  }

  static Future<void> shareNative({
    required String title,
    required String url,
    required bool startAtChecked,
    required String contentType,
    Duration? currentPosition,
    String? channelName,
    String? handle,
    String? videoTitle,
    double? clipStartTime,
    double? clipEndTime,
    int? durationMs,
  }) async {
    final shareUrl = ShareUtils.getShareUrl(
      url: url,
      startAtChecked: startAtChecked,
      currentPosition: currentPosition,
    );
    await SharePlus.instance.share(
      ShareParams(
        text: buildShareMessage(
          title: title,
          shareUrl: shareUrl,
          contentType: contentType,
          channelName: channelName,
          handle: handle,
          videoTitle: videoTitle,
          clipStartTime: clipStartTime,
          clipEndTime: clipEndTime,
          durationMs: durationMs,
        ),
        subject: title,
      ),
    );
  }

  static void copyToClipboard({
    required String url,
    required bool startAtChecked,
    Duration? currentPosition,
  }) {
    final shareUrl = ShareUtils.getShareUrl(
      url: url,
      startAtChecked: startAtChecked,
      currentPosition: currentPosition,
    );
    Clipboard.setData(ClipboardData(text: shareUrl));
    Get.back<void>();
    AppSnackbar.info(
      'Link copied to clipboard',
      title: 'Copied',
    );
  }
}
