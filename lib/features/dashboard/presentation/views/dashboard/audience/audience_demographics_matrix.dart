import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience/audience_age_demographics_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience/audience_gender_demographics_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience/audience_subscribers_watch_share_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience/audience_viewer_loyalty_card.dart';

/// YouTube Studio Demographics Matrix (Ages, Genders, Subscribed vs Unsubscribed, Retention)
Widget buildAudienceDemographicsMatrix({
  required AudienceController controller,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 800;
      final cardWidth = isDesktop
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // Card 1: Watch time / views from subscribers (YouTube Studio style)
          SizedBox(
            width: cardWidth,
            child: buildAudienceSubscribersWatchShareCard(
              controller: controller,
              isDarkMode: isDarkMode,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ),

          // Card 2: Age Demographics
          SizedBox(
            width: cardWidth,
            child: buildAudienceAgeDemographicsCard(
              controller: controller,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ),

          // Card 3: Gender Demographics
          SizedBox(
            width: cardWidth,
            child: buildAudienceGenderDemographicsCard(
              controller: controller,
              isDarkMode: isDarkMode,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ),

          // Card 4: Viewer Loyalty & Urban/Rural Geography
          SizedBox(
            width: cardWidth,
            child: buildAudienceViewerLoyaltyAndSettingCard(
              controller: controller,
              isDarkMode: isDarkMode,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ),
        ],
      );
    },
  );
}
