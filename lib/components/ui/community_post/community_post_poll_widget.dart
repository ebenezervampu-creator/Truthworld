import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/community/presentation/controllers/community_post_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive Poll Widget for Community Posts (YouTube parity)
/// Renders question, clickable vote option buttons, and live results bar charts.
class CommunityPostPollWidget extends StatelessWidget {
  const CommunityPostPollWidget({
    required this.controller,
    super.key,
  });

  final CommunityPostController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final poll = controller.poll.value;
      if (poll == null || poll.options.isEmpty) {
        return const SizedBox.shrink();
      }

      final uid = controller.currentUid;
      final hasVoted = poll.hasVoted(uid);
      final isExpired = poll.isExpired;
      final showResults = hasVoted || isExpired || controller.isCurrentUserOwner;
      final totalVotes = poll.totalVotes;
      final userChoiceId = poll.selectedOptionId(uid);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.bgDivider.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poll.question.trim().isNotEmpty) ...[
              Text(
                poll.question.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Options List
            ...poll.options.map((option) {
              final isUserChoice = option.id == userChoiceId;
              final percent = totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;
              final percentDisplay = (percent * 100).round();

              if (!showResults) {
                // Pre-vote action button
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.votePoll(option.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white24,
                          ),
                          color: const Color(0xFF262626),
                        ),
                        child: Text(
                          option.text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Post-vote results bar
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF222222),
                    border: Border.all(
                      color: isUserChoice ? Colors.white70 : Colors.white12,
                      width: isUserChoice ? 1.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Percentage fill bar
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          color: isUserChoice
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      // Text & stats row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            if (isUserChoice) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                option.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isUserChoice
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$percentDisplay%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isUserChoice
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isUserChoice
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 4),

            // Poll metadata (Total votes & state)
            Row(
              children: [
                Text(
                  '${FormatUtils.formatCount(totalVotes)} ${totalVotes == 1 ? 'vote' : 'votes'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isExpired) ...[
                  const Text(
                    ' • ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    'Final results',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else if (poll.expiresAt != null) ...[
                  const Text(
                    ' • ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _formatTimeRemaining(poll.expiresAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    });
  }

  String _formatTimeRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Final results';
    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} left';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} left';
    }
    return '${diff.inMinutes.clamp(1, 60)} min left';
  }
}
