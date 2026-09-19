import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header bar for Channel Creation Wizard with back navigation,
/// title, and draft management overflow menu.
class ChannelWizardTopHeader extends StatelessWidget {
  const ChannelWizardTopHeader({
    required this.channelController,
    required this.wizardController,
    required this.isDesktop,
    required this.isDarkMode,
    super.key,
  });

  final ChannelController channelController;
  final ChannelWizardViewController wizardController;
  final bool isDesktop;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => wizardController.handleClose(context, isDarkMode),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: const [
                Text(
                  'Create Channel',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Build your brand. Share your story with the world.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
            onSelected: (value) async {
              if (value == 'save_draft') {
                await channelController.saveDraft();
              } else if (value == 'delete_draft') {
                wizardController.showDeleteDraftDialog(context, isDarkMode);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save_draft',
                child: Row(
                  children: [
                    Obx(
                      () => channelController.isSavingDraft.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.bookmark_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Save draft',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_draft',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Delete draft',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
