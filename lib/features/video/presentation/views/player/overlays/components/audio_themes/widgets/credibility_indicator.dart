import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Epistemic states distinguishing verified evidence status from unverified assumptions.
enum EpistemicAssessmentState {
  notEvaluated,
  processing,
  supported,
  contradicted,
  inconclusive,
  outdated,
  contextual;

  String get shortLabel {
    switch (this) {
      case EpistemicAssessmentState.notEvaluated:
        return 'UNEVALUATED';
      case EpistemicAssessmentState.processing:
        return 'EVALUATING';
      case EpistemicAssessmentState.supported:
        return 'EVIDENCE SUPPORTED';
      case EpistemicAssessmentState.contradicted:
        return 'CONTRADICTED BY EVIDENCE';
      case EpistemicAssessmentState.inconclusive:
        return 'EVIDENCE INCONCLUSIVE';
      case EpistemicAssessmentState.outdated:
        return 'ASSESSMENT OUTDATED';
      case EpistemicAssessmentState.contextual:
        return 'CONTEXT & NUANCE';
    }
  }

  Color get color {
    switch (this) {
      case EpistemicAssessmentState.notEvaluated:
        return Colors.white38;
      case EpistemicAssessmentState.processing:
        return const Color(0xFF38BDF8); // Cyan
      case EpistemicAssessmentState.supported:
        return const Color(0xFF10B981); // Emerald
      case EpistemicAssessmentState.contradicted:
        return const Color(0xFFEF4444); // Red
      case EpistemicAssessmentState.inconclusive:
        return const Color(0xFFF59E0B); // Amber
      case EpistemicAssessmentState.outdated:
        return const Color(0xFF94A3B8); // Slate grey
      case EpistemicAssessmentState.contextual:
        return const Color(0xFF818CF8); // Indigo
    }
  }

  IconData get icon {
    switch (this) {
      case EpistemicAssessmentState.notEvaluated:
        return Icons.help_outline_rounded;
      case EpistemicAssessmentState.processing:
        return Icons.sync_rounded;
      case EpistemicAssessmentState.supported:
        return Icons.check_circle_outline_rounded;
      case EpistemicAssessmentState.contradicted:
        return Icons.cancel_outlined;
      case EpistemicAssessmentState.inconclusive:
        return Icons.flaky_rounded;
      case EpistemicAssessmentState.outdated:
        return Icons.history_rounded;
      case EpistemicAssessmentState.contextual:
        return Icons.info_outline_rounded;
    }
  }

  static EpistemicAssessmentState resolve(Video? video) {
    if (video == null || video.isNonCredibilityCategory) {
      return EpistemicAssessmentState.notEvaluated;
    }
    final status = (video.credibilityStatus ?? '').toLowerCase();
    if (status.isEmpty || status == 'pending' || status == 'not_evaluated') {
      return EpistemicAssessmentState.notEvaluated;
    }
    if (status.contains('processing') || status.contains('analyzing')) {
      return EpistemicAssessmentState.processing;
    }
    if (status.contains('outdated') || status.contains('expired')) {
      return EpistemicAssessmentState.outdated;
    }
    if (status.contains('contradict') || status.contains('refuted') || status.contains('false')) {
      return EpistemicAssessmentState.contradicted;
    }
    if (status.contains('inconclusive') || status.contains('disputed') || status.contains('mixed')) {
      return EpistemicAssessmentState.inconclusive;
    }
    if (video.hasPublicAiCredibility &&
        (status.contains('verified') || status.contains('supported') || status.contains('provisional_ready'))) {
      return EpistemicAssessmentState.supported;
    }
    return EpistemicAssessmentState.contextual;
  }
}

/// Contextual credibility badge communicating authentic epistemic evidence states.
/// Only illuminates when evaluation exists; never implies AI opinion equals absolute truth.
class CredibilityIndicator extends StatelessWidget {
  const CredibilityIndicator({
    this.video,
    this.compact = false,
    super.key,
  });

  final Video? video;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = EpistemicAssessmentState.resolve(video);

    // Unevaluated content: render nothing to avoid false authenticity cues
    if (state == EpistemicAssessmentState.notEvaluated) {
      return const SizedBox.shrink();
    }

    final color = state.color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.icon,
            size: compact ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            state.shortLabel,
            style: TextStyle(
              color: color,
              fontSize: compact ? 8.0 : 9.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
