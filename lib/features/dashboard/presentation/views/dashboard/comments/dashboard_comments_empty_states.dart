import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Context-aware empty state for Dashboard Comments
class DashboardCommentsEmptyState extends StatelessWidget {
  const DashboardCommentsEmptyState({
    required this.isHeldTab,
    super.key,
  });

  final bool isHeldTab;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHeldTab
                  ? Icons.rate_review_outlined
                  : Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              isHeldTab
                  ? 'No comments held for review'
                  : 'No comments found',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isHeldTab
                  ? 'Comments that need review will appear here.'
                  : 'Try adjusting your search query or filter chips.',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: const Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton / spinner for comments pane
class DashboardCommentsLoadingSkeleton extends StatelessWidget {
  const DashboardCommentsLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}
