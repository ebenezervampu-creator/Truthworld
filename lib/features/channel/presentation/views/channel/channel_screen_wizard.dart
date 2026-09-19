import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_desktop_layout.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_mobile_layout.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_top_header.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';

export 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_plan_badge_item.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_accordion_card.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_desktop_layout.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_mobile_layout.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_selection_view.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_top_header.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';

/// Redesigned Channel Creation Screen
/// Supports Desktop (multi-column layout) and Mobile (responsive single column layout)
/// matching exact visual architecture from the reference design.
///
/// Implemented as a declarative StatelessWidget adhering strictly to TruthWorld's
/// Zero setState Policy and sub-500 LOC ceiling.
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  ChannelWizardViewController get wizardController {
    if (Get.isRegistered<ChannelWizardViewController>()) {
      return Get.find<ChannelWizardViewController>();
    }
    return Get.put(ChannelWizardViewController());
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final ctrl = wizardController;
    final channelCtrl = ctrl.channelController;

    // Show draft dialog post-frame if draft exists
    ctrl.checkDraftAvailable(context, isDarkMode);

    return Obx(
      () => PopScope(
        canPop: ctrl.isExiting.value ||
            (channelCtrl.channelName.text.trim().isEmpty &&
                channelCtrl.description.text.trim().isEmpty &&
                channelCtrl.selectedCategories.isEmpty),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          ctrl.handleClose(context, isDarkMode);
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Stack(
                  children: [
                    Column(
                      children: [
                        ChannelWizardTopHeader(
                          channelController: channelCtrl,
                          wizardController: ctrl,
                          isDesktop: isDesktop,
                          isDarkMode: isDarkMode,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 32 : 16,
                              vertical: isDesktop ? 24 : 16,
                            ),
                            child: Form(
                              key: channelCtrl.formKey,
                              child: isDesktop
                                  ? ChannelWizardDesktopLayout(
                                      channelController: channelCtrl,
                                      wizardController: ctrl,
                                      isDarkMode: isDarkMode,
                                    )
                                  : ChannelWizardMobileLayout(
                                      channelController: channelCtrl,
                                      wizardController: ctrl,
                                      isDarkMode: isDarkMode,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Obx(
                      () => channelCtrl.isSubmitting.value
                          ? const ColoredBox(
                              color: Colors.black54,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
