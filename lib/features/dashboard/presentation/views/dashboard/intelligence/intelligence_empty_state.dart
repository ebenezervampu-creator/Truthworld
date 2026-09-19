import 'package:flutter/material.dart';

/// Clean illustration state shown when no creator intelligence notifications match current filters.
class IntelligenceEmptyState extends StatelessWidget {
  const IntelligenceEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Creator Insights Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Milestones, video verification audit reports, and AI growth tips will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFA1A1AA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
