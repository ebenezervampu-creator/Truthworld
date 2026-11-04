import 'package:flutter/material.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_branding_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_details_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_links_visibility_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_agreements_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_type_category_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';

/// Two-column responsive desktop layout for the Channel Creation Wizard.
class ChannelWizardDesktopLayout extends StatelessWidget {
  const ChannelWizardDesktopLayout({
    required this.channelController,
    required this.wizardController,
    required this.isDarkMode,
    super.key,
  });

  final ChannelController channelController;
  final ChannelWizardViewController wizardController;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Branding & Details
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  ChannelWizardBrandingCard(
                    controller: channelController,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  ChannelWizardDetailsCard(
                    controller: channelController,
                    tagList: wizardController.tagList,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Channel Type, Category & Links
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  ChannelWizardTypeCard(
                    controller: channelController,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  ChannelWizardCategoryCard(
                    controller: channelController,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 24),
                  ChannelWizardLinksCard(
                    controller: channelController,
                    isDarkMode: isDarkMode,
                    getSocialController: wizardController.getSocialController,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Bottom Row: Visibility, Country & Language
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ChannelWizardVisibilityCard(
                controller: channelController,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ChannelWizardCountryCard(
                controller: channelController,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ChannelWizardLanguageCard(
                controller: channelController,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Agreements & Submit Button
        ChannelWizardAgreementsCard(
          controller: channelController,
          isDarkMode: isDarkMode,
          onSubmit: wizardController.validateAndSubmitChannel,
        ),
      ],
    );
  }
}
