import 'package:flutter/material.dart';

/// Specialized issue notification card with status-specific badge accents.
class IntelligenceIssueCard extends StatelessWidget {
  const IntelligenceIssueCard({
    required this.title,
    required this.description,
    required this.statusType,
    required this.icon,
    this.isLoading = false,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String description;
  final String statusType;
  final IconData icon;
  final bool isLoading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color borderColor;

    if (statusType == 'PENDING') {
      badgeBg = const Color(0xFF1E293B);
      borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
    } else if (statusType == 'APPROVED') {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
    } else if (statusType == 'FLAGGED') {
      badgeBg = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
    } else if (statusType == 'MANUAL_REVIEW') {
      badgeBg = const Color(0xFF2E1065);
      borderColor = const Color(0xFF8B5CF6).withValues(alpha: 0.4);
    } else {
      // REJECTED
      badgeBg = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA1A1AA),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
