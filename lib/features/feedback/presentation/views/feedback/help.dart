import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

// Constants for consistent styling
const double kBorderRadius = 16.0;
const double kSmallPadding = 8.0;
const double kMediumPadding = 16.0;
const double kLargePadding = 24.0;

class HelpPage extends StatelessWidget {
  final List<ModernFAQItem> faqItems = [
    ModernFAQItem(
      question: 'How do I upload a video?',
      answer:
          'Tap the "+" icon at the bottom of the screen, select your video, add details, and then upload.',
    ),
    ModernFAQItem(
      question: 'How do I report inappropriate content?',
      answer:
          'Go to the video, tap the three dots menu, and select "Report". Follow the instructions to submit your report.',
    ),
    ModernFAQItem(
      question: 'How do I reset my password?',
      answer:
          'Go to Settings > Account > Change Password and follow the instructions.',
    ),
    ModernFAQItem(
      question: 'How do I contact support?',
      answer:
          'You can contact us via the "Send Feedback" option in the Settings page.',
    ),
  ];

  final bool isDashboard;
  HelpPage({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: !isDashboard ? AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ) : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: EdgeInsets.all(kMediumPadding),
            children: [
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.roboto(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: kLargePadding),
              ...faqItems.map((item) => ModernFAQTile(item: item)),
              const SizedBox(height: kLargePadding * 2),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Get.snackbar(
                      'Action',
                      'Navigate to Send Feedback Page (placeholder)',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: colorScheme.primaryContainer,
                      colorText: colorScheme.onPrimaryContainer,
                    );
                  },
                  icon: Icon(
                    Icons.feedback_rounded,
                    color: colorScheme.onPrimary,
                  ),
                  label: Text(
                    'Contact Support',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: kLargePadding,
                      vertical: kMediumPadding,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    elevation: 4,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ModernFAQItem {
  final String question;
  final String answer;

  ModernFAQItem({required this.question, required this.answer});
}

class ModernFAQTile extends StatefulWidget {
  final ModernFAQItem item;

  const ModernFAQTile({super.key, required this.item});

  @override
  State<ModernFAQTile> createState() => _ModernFAQTileState();
}

class _ModernFAQTileState extends State<ModernFAQTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.symmetric(vertical: kSmallPadding),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kBorderRadius),
      ),
      color: AppTheme.colors.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(dividerColor: Colors.transparent), // Hide default divider
        child: ExpansionTile(
          key: PageStorageKey(widget.item.question), // Preserve expansion state
          tilePadding: EdgeInsets.symmetric(
            horizontal: kMediumPadding,
            vertical: kSmallPadding,
          ),
          title: Text(
            widget.item.question,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          trailing: RotationTransition(
            turns: _animation,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                kMediumPadding,
                0,
                kMediumPadding,
                kMediumPadding,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.item.answer,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          onExpansionChanged: (expanded) {
            if (expanded) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
        ),
      ),
    );
  }
}





