import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/intelligence_notification_card.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

/// Sticky urgent notification section grouping all critical policy and moderation alerts.
class IntelligenceCriticalSection extends StatelessWidget {
  const IntelligenceCriticalSection({
    required this.controller,
    required this.channelId,
    super.key,
  });

  final CreatorIntelligenceController controller;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final criticalItems = controller.filteredNotifications
        .where((n) => n.priority == NotificationPriority.critical)
        .toList();

    if (criticalItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ACTION REQUIRED',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...criticalItems.map(
            (n) => IntelligenceNotificationCard(
              controller: controller,
              notification: n,
              channelId: channelId,
              isCriticalStyle: true,
            ),
          ),
        ],
      ),
    );
  }
}
