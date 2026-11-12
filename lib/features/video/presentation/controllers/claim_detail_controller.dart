import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/ai_chat/ai_credibility_chat_sheet.dart';

/// 🎮 ClaimDetailController
///
/// Manages reactive state for the Claim Detail Command Center on desktop and mobile:
/// - Active claim selection in the Claim Ledger Timeline
/// - Collapsible right drawer / split canvas state (65% Command Center / 35% Truth AI)
/// - Synchronized video seeking and live transcript navigation
/// - Seamless memory management and controller disposal
class ClaimDetailController extends BaseController {
  final int initialIndex;
  late final RxInt currentClaimIndex;
  final RxBool isAiChatDocked = true.obs;
  final RxBool isTranscriptExpanded = true.obs;
  final RxBool isVideoMuted = false.obs;

  late final ScrollController timelineScrollController;
  late final ScrollController transcriptScrollController;

  ClaimDetailController({this.initialIndex = 0});

  @override
  void onInit() {
    super.onInit();
    currentClaimIndex = initialIndex.obs;
    timelineScrollController = ScrollController();
    transcriptScrollController = ScrollController();
  }

  @override
  void onClose() {
    timelineScrollController.dispose();
    transcriptScrollController.dispose();
    super.onClose();
  }

  /// Toggles the docked persistent Truth AI chat on desktop
  void toggleAiChatDock() {
    isAiChatDocked.value = !isAiChatDocked.value;
  }

  /// Opens / docks the persistent Truth AI chat
  void openAiChat() {
    isAiChatDocked.value = true;
  }

  /// Collapses / closes the docked Truth AI chat pane
  void closeAiChat() {
    isAiChatDocked.value = false;
  }

  /// Switches active claim, syncing video seek and scrolling timeline
  void selectClaim({
    required int index,
    required List<dynamic> allClaims,
    VideoController? videoController,
  }) {
    if (index < 0 || index >= allClaims.length) return;
    currentClaimIndex.value = index;

    // 1. Seek video player if start timestamp is present
    final claimItem = allClaims[index];
    if (claimItem is Map) {
      final startSec = _extractStartSeconds(claimItem);
      if (startSec != null && startSec >= 0) {
        final target = Duration(milliseconds: (startSec * 1000).toInt());
        videoController?.videoPlayerController?.seekTo(target);
      }
    }

    // 2. Center the selected item in the timeline
    _scrollToClaimTimeline(index);
  }

  void _scrollToClaimTimeline(int index) {
    if (!timelineScrollController.hasClients) return;
    const itemWidth = 148.0;
    final targetOffset = (index * itemWidth - 120.0).clamp(
      0.0,
      timelineScrollController.position.maxScrollExtent,
    );
    timelineScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  static double? _extractStartSeconds(Map<dynamic, dynamic> claim) {
    dynamic val = claim['startSec'] ??
        claim['startTime'] ??
        claim['start_time'] ??
        claim['start'] ??
        claim['timestampSec'] ??
        claim['timestamp'] ??
        claim['time'];
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) return parsed;
      if (val.contains(':')) {
        final parts = val.split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = double.tryParse(parts[1]) ?? 0.0;
          return m * 60 + s;
        } else if (parts.length == 3) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = double.tryParse(parts[2]) ?? 0.0;
          return h * 3600 + m * 60 + s;
        }
      }
    }
    return null;
  }
}
