import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_page.dart';

/// Studio Full Verification & Credibility Inspector Modal.
/// Kept for 100% backward compatibility, delegates open to [TruthVerificationFullInspectorPage.open].
class TruthVerificationFullInspectorModal
    extends TruthVerificationFullInspectorPage {
  TruthVerificationFullInspectorModal({
    required super.videoItem,
    required super.channelId,
    required super.isDarkMode,
    required super.onToggleApproval,
    super.key,
  });

  /// Opens the full verification inspection report on a separate page.
  static void open(
    BuildContext context, {
    required VideoFactCheckItem videoItem,
    required String channelId,
    required bool isDarkMode,
    required void Function(String videoId, bool currentStatus) onToggleApproval,
  }) {
    TruthVerificationFullInspectorPage.open(
      context,
      videoItem: videoItem,
      channelId: channelId,
      isDarkMode: isDarkMode,
      onToggleApproval: onToggleApproval,
    );
  }
}
