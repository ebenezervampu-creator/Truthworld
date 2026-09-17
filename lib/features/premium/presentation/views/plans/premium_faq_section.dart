import 'package:flutter/material.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive FAQ accordion section for common subscription questions.
class PremiumFaqSection extends StatelessWidget {
  final List<PremiumFaqItem> faqs;

  const PremiumFaqSection({
    this.faqs = kDefaultPremiumFaqs,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: faqs.map((faq) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: cardColor,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    title: Text(
                      faq.q,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        faq.a,
                        style: const TextStyle(
                          fontSize: 14,
                          color: secondaryText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
