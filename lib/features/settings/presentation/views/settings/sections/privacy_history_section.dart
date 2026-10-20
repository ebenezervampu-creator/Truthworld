import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/watch_history_settings_view.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class PrivacyHistorySection extends StatelessWidget {
  const PrivacyHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Privacy & History',
      children: [
        _buildWatchHistoryTile(context),
        _buildSearchHistoryTile(context),
        _buildBlockedMutedTile(context),
      ],
    );
  }

  Widget _buildWatchHistoryTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history, color: AppColors.textPrimary),
      title: const Text(
        'Watch History Controls',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        'Pause watch history or clear viewing log',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () => Get.to(() => const WatchHistorySettingsView()),
    );
  }

  Widget _buildSearchHistoryTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.search_off_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Search History Controls',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          ctrl.isSearchHistoryPaused.value
              ? 'Search history is PAUSED'
              : 'Manage or clear search queries',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showSearchHistoryDialog(context),
      ),
    );
  }

  void _showSearchHistoryDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Search History Controls',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => ListTile(
                leading: Icon(
                  ctrl.isSearchHistoryPaused.value
                      ? Icons.play_arrow_outlined
                      : Icons.pause_circle_outline,
                  color: AppColors.textPrimary,
                ),
                title: Text(
                  ctrl.isSearchHistoryPaused.value
                      ? 'Resume Search History'
                      : 'Pause Search History',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  ctrl.toggleSearchHistoryPaused();
                  Get.back();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: const Text(
                'Clear All Search History',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Get.back();
                ctrl.clearSearchHistory();
                AppSnackbar.success(
                  'Search history wiped successfully.',
                  title: 'Search History Cleared',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedMutedTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(Icons.block_outlined, color: AppColors.textPrimary),
        title: const Text(
          'Blocked & Muted List',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          '${ctrl.blockedUsers.length} blocked users • ${ctrl.mutedKeywords.length} muted keywords',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showBlockedMutedDialog(context),
      ),
    );
  }

  void _showBlockedMutedDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    final keywordCtrl = TextEditingController();
    final blockUserCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Blocked & Muted List',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MUTED KEYWORDS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: keywordCtrl,
                      maxLength: 50,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: TruthworldTextInputFormatters.withLimit(50),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Mute keyword...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.textPrimary),
                    onPressed: () {
                      if (keywordCtrl.text.isNotEmpty) {
                        ctrl.addMutedKeyword(keywordCtrl.text);
                        keywordCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: ctrl.mutedKeywords
                      .map(
                        (kw) => Chip(
                          backgroundColor: context.colors.surfaceContainerHigh,
                          label: Text(
                            kw,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          onDeleted: () => ctrl.removeMutedKeyword(kw),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider),
              const SizedBox(height: 8),
              const Text(
                'BLOCKED USERS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: blockUserCtrl,
                      maxLength: 30,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(30),
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Block user handle...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      if (blockUserCtrl.text.isNotEmpty) {
                        ctrl.blockUser(blockUserCtrl.text);
                        blockUserCtrl.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: ctrl.blockedUsers
                      .map(
                        (user) => Chip(
                          backgroundColor: context.colors.surfaceContainerHigh,
                          label: Text(
                            user,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          onDeleted: () => ctrl.unblockUser(user),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 7. ACCESSIBILITY TILES =================


}
