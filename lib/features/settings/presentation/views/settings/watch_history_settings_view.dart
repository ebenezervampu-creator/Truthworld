import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_theme.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchHistorySettingsView extends StatelessWidget {
  const WatchHistorySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<WatchHistoryController>()
        ? Get.find<WatchHistoryController>()
        : Get.put(WatchHistoryController());

    return Theme(
      data: getSettingsTheme(context),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(
              backgroundColor: context.colors.background,
              elevation: 0,
              title: Text(
                'Watch history',
                style: context.typography.headline.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Get.offAllNamed('/');
                  }
                },
              ),
            ),
            body: SafeArea(
              child: ListView(
                children: [
                  _buildHeader(context),
                  const Divider(color: AppColors.bgDivider),
                  _buildControlSection(context, controller),
                  const Divider(color: AppColors.bgDivider),
                  _buildDeleteSection(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage your viewing history',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "History helps you find videos you've watched and improves your recommendations.",
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(
    BuildContext context,
    WatchHistoryController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'CONTROLS'),
        Obx(
          () => ListTile(
            leading: Icon(
              controller.isHistoryPaused.value
                  ? Icons.play_arrow_outlined
                  : Icons.pause_circle_outline,
              color: AppColors.textPrimary,
            ),
            title: Text(
              controller.isHistoryPaused.value
                  ? 'Resume watch history'
                  : 'Pause watch history',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: controller.toggleHistoryPaused,
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.list_alt_rounded,
            color: AppColors.textPrimary,
          ),
          title: const Text(
            'View full history',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          onTap: () {
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().onSideNavItemSelect(
                HomeController.indexHistory,
              );
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              if (Get.currentRoute == AppRoutes.settings &&
                  Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            } else {
              Get.toNamed('/watchhistory');
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeleteSection(
    BuildContext context,
    WatchHistoryController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'DELETE OPTIONS'),
        _buildDeleteTile(
          context,
          'Delete today',
          Icons.today_outlined,
          onTap: () => _confirmDelete(context, 'today', controller.deleteToday),
        ),
        _buildDeleteTile(
          context,
          'Delete yesterday',
          Icons.event_note_outlined,
          onTap: () =>
              _confirmDelete(context, 'yesterday', controller.deleteYesterday),
        ),
        _buildDeleteTile(
          context,
          'Delete this week',
          Icons.calendar_view_week_outlined,
          onTap: () =>
              _confirmDelete(context, 'this week', controller.deleteThisWeek),
        ),
        _buildDeleteTile(
          context,
          'Delete previous week',
          Icons.calendar_month_outlined,
          onTap: () => _confirmDelete(
            context,
            'previous week',
            controller.deletePreviousWeek,
          ),
        ),
        _buildDeleteTile(
          context,
          'Delete all time',
          Icons.delete_forever_outlined,
          isError: true,
          onTap: controller.clearAllHistory,
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'To delete a particular video, use the "View full history" option above.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.colors.brand,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDeleteTile(
    BuildContext context,
    String title,
    IconData icon, {
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isError ? context.colors.error : AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isError ? context.colors.error : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDelete(
    BuildContext context,
    String label,
    VoidCallback onConfirm,
  ) {
    final colors = context.colors;
    Get.dialog(
      AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Delete History?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete your watch history from $label?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              onConfirm();
            },
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }
}

