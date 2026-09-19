import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_accordion_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_branding_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_details_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_links_visibility_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_agreements_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_type_category_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';

/// Single-column responsive mobile accordion layout for the Channel Creation Wizard.
class ChannelWizardMobileLayout extends StatelessWidget {
  const ChannelWizardMobileLayout({
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
        ChannelWizardBrandingCard(
          controller: channelController,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 16),
        ChannelWizardDetailsCard(
          controller: channelController,
          tagList: wizardController.tagList,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '3. Channel Type',
          isExpanded: wizardController.isChannelTypeExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardTypeCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            contentOnly: true,
          ),
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '4. Category',
          isExpanded: wizardController.isCategoryExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardCategoryCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            contentOnly: true,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => ChannelWizardAccordionCard(
            title: channelController.country.value.isNotEmpty
                ? '5. Links for ${channelController.country.value} (Optional)'
                : '5. Links (Optional)',
            isExpanded: wizardController.isLinksExpanded,
            isDarkMode: isDarkMode,
            child: ChannelWizardLinksCard(
              controller: channelController,
              isDarkMode: isDarkMode,
              getSocialController: wizardController.getSocialController,
              contentOnly: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '6. Channel Visibility',
          isExpanded: wizardController.isVisibilityExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardVisibilityCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            contentOnly: true,
          ),
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '7. Country',
          isExpanded: wizardController.isCountryExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardCountryCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            contentOnly: true,
          ),
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '8. Language',
          isExpanded: wizardController.isLanguageExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardLanguageCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            contentOnly: true,
          ),
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '9. Channel Plan',
          isExpanded: wizardController.isPlanExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardPlanCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            contentOnly: true,
          ),
        ),
        const SizedBox(height: 16),
        ChannelWizardAccordionCard(
          title: '10. Agreements',
          isExpanded: wizardController.isAgreementsExpanded,
          isDarkMode: isDarkMode,
          child: ChannelWizardAgreementsCard(
            controller: channelController,
            isDarkMode: isDarkMode,
            onSubmit: wizardController.validateAndSubmitChannel,
            contentOnly: true,
          ),
        ),
      ],
    );
  }
}
