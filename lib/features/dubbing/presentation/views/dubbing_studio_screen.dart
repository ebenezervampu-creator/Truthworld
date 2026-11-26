import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_language_matrix_sheet.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_pricing_calculator_card.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_projects_hub.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_segment_row.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_source_language_sheet.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_voice_cloning_dialog.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_wallet_modal.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_waveform_player.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/dubbing_studio_theme.dart';
import 'package:truthworld/theme/tw_typography.dart';
import 'package:video_player/video_player.dart';

/// Standalone TruthWorld Dubbing Studio Screen.
///
/// Designed with a quiet-luxury dark DAW / ElevenLabs Dubbing Studio aesthetic:
/// - Deep obsidian canvas (`#09090B`) with whisper-thin 1px borders
/// - Single primary white CTA hierarchy (no competing white pill clutter)
/// - Multi-track DAW timeline + Inspector workspace
class DubbingStudioScreen extends GetView<DubbingStudioController> {
  const DubbingStudioScreen({super.key});

  static const Color _canvasBg = DubbingStudioTheme.canvasBg;
  static const Color _chromeBg = DubbingStudioTheme.chromeBg;
  static const Color _cardBg = DubbingStudioTheme.cardBg;
  static const Color _elevatedPill = DubbingStudioTheme.elevatedPill;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopStudioHeader(context),
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            Expanded(
              child: Obx(() {
                final project = controller.activeProject.value;
                final job = controller.activeJob.value;
                if (project == null && job == null) {
                  return const DubbingProjectsHub();
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 980;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildStudioStage(context, job)),
                          VerticalDivider(
                            color: Colors.white.withValues(alpha: 0.07),
                            width: 1,
                          ),
                          SizedBox(
                            width: 380,
                            child: _buildInspectorPanel(context),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStudioStageContent(context, job),
                          const SizedBox(height: 16),
                          _buildInspectorContent(context),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Studio Header ──────────────────────────────────────────
  Widget _buildTopStudioHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      color: _chromeBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 680;
          final showBetaPill = constraints.maxWidth > 860;

          return Row(
            children: [
              // Left: TW Mark + Breadcrumb + Back to Projects when inside a project
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (controller.activeProject.value != null || controller.activeJob.value != null) {
                          controller.closeActiveProject();
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'TW',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Truthworld',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: DubbingStudioTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              fontSize: 14.5,
                            ),
                          ),
                          if (!isCompact) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 7),
                              child: Text(
                                '/',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: DubbingStudioTheme.textTertiary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Flexible(
                              child: Text(
                                'Dubbing Studio',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: DubbingStudioTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Obx(() {
                      if (controller.activeProject.value == null && controller.activeJob.value == null) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 16,
                            color: DubbingStudioTheme.borderSubtle,
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: controller.closeActiveProject,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 15,
                              color: DubbingStudioTheme.textSecondary,
                            ),
                            label: const Text(
                              'Projects',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: DubbingStudioTheme.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right: Studio Beta Pill, + New Project CTA, Wallet & Account
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showBetaPill) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: DubbingStudioTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: DubbingStudioTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: DubbingStudioTheme.accentEmerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Studio Beta',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: DubbingStudioTheme.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Solid White + New Project CTA (always crisp black-on-white)
                  ElevatedButton.icon(
                    onPressed: () => DubbingProjectsHub.showCreateProjectDialog(context, controller),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                    label: Text(
                      isCompact ? 'New' : 'New Project',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.black,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : 14,
                        vertical: 9,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Wallet Pill
                  if (!isCompact)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Obx(() {
                        final wallet = controller.wallet.value;
                        final credits = wallet?.balanceCredits ?? controller.totalAvailableCharacters;
                        final isFree = controller.isFreeDubbingActive;

                        return InkWell(
                          onTap: () => Get.dialog(const DubbingWalletModal()),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: DubbingStudioTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: DubbingStudioTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isFree ? Icons.verified_rounded : Icons.bolt_rounded,
                                  size: 14,
                                  color: (credits > 0 || isFree)
                                      ? DubbingStudioTheme.accentSky
                                      : DubbingStudioTheme.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isFree
                                      ? '100% Free'
                                      : '${credits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
                                  style: DubbingStudioTheme.monoMeta.copyWith(
                                    color: DubbingStudioTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),

                  // Google Sign-In or Avatar
                  Obx(() {
                    final signedIn = AuthService.to.isUserSignedIn;
                    if (!signedIn) {
                      return OutlinedButton.icon(
                        onPressed: () => controller.signInWithGoogle(),
                        icon: const Icon(Icons.login, color: DubbingStudioTheme.textPrimary, size: 15),
                        label: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: DubbingStudioTheme.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _elevatedPill,
                          side: BorderSide(color: DubbingStudioTheme.borderMedium),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      );
                    }
                    return PopupMenuButton<String>(
                      tooltip: 'Account Menu',
                      offset: const Offset(0, 42),
                      elevation: 8,
                      color: _cardBg,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: DubbingStudioTheme.borderMedium),
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'wallet':
                            Get.dialog(const DubbingWalletModal());
                          case 'sign_out':
                            await controller.signOut();
                        }
                      },
                      itemBuilder: (context) => [
                        _buildUserHeaderMenuItem(context),
                        const PopupMenuDivider(height: 1),
                        _buildUserPopupMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Dubbing Wallet',
                          value: 'wallet',
                        ),
                        const PopupMenuDivider(height: 1),
                        _buildUserPopupMenuItem(
                          icon: Icons.logout_rounded,
                          title: 'Sign Out',
                          value: 'sign_out',
                          isDestructive: true,
                        ),
                      ],
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _elevatedPill,
                          shape: BoxShape.circle,
                          border: Border.all(color: DubbingStudioTheme.borderMedium),
                        ),
                        child: Text(
                          (AuthService.to.userDisplayName.value ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: DubbingStudioTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildUserHeaderMenuItem(BuildContext context) {
    final displayName = AuthService.to.userDisplayName.value ?? 'Creator';
    final emailOrHandle = AuthService.to.hasChannel.value && AuthService.to.userChannel != null
        ? AuthService.to.activeHandle
        : (AuthService.to.user?.email ?? '');

    return PopupMenuItem<String>(
      enabled: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: _elevatedPill,
            child: Text(
              displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (emailOrHandle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    emailOrHandle,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildUserPopupMenuItem({
    required IconData icon,
    required String title,
    required String value,
    bool isDestructive = false,
  }) {
    final itemColor = isDestructive ? AppColors.error : AppColors.textPrimary;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: itemColor),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: itemColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Left/Center Studio Stage ──────────────────────────────────
  Widget _buildStudioStage(BuildContext context, DubbingJob? job) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildStudioStageContent(context, job),
    );
  }

  Widget _buildStudioStageContent(BuildContext context, DubbingJob? job) {
    return Obx(() {
      final hasProjectJobs = job != null || controller.projectJobs.isNotEmpty;
      final showSource = job == null || controller.showSourceEditor.value;
      final isCompleted = job?.status == DubbingJobStatus.completed;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editable Project Header
          _buildProjectHeader(),
          const SizedBox(height: 18),

          // Source Media Ingest Stage (always accessible or collapsible once media/jobs exist)
          if (showSource) ...[
            _buildSourceIngestCard(context),
            const SizedBox(height: 18),
          ] else ...[
            _buildCompactSourceBar(),
            const SizedBox(height: 16),
          ],

          if (job != null) ...[
            _buildPipelineProgressTracker(job),
            const SizedBox(height: 16),
          ],

          // Live Video Preview Monitor
          _buildVideoPreviewMonitor(),

          // Multi-Track DAW Waveform Timeline
          DubbingWaveformPlayer(
            title: controller.mediaTitle.value.isNotEmpty
                ? controller.mediaTitle.value
                : (job?.title ?? 'Master Timeline Preview'),
            durationSeconds: job != null && job.durationSeconds > 0
                ? job.durationSeconds
                : controller.estimatedDurationSeconds.value,
            externalIsPlaying: controller.isPlaying,
            externalPositionMs: controller.playbackPositionMs,
            externalDurationMs: controller.totalDurationMs,
            externalSpeed: controller.playbackSpeed,
            onPlayToggle: controller.togglePlayback,
            onSeekPercent: controller.seekToPercent,
            onSpeedChanged: controller.setPlaybackSpeed,
          ),

          if (hasProjectJobs) ...[
            if (isCompleted || controller.projectJobs.any((j) => j.status == DubbingJobStatus.completed)) ...[
              const SizedBox(height: 18),
              _buildExportDock(context, job),
              if (job != null) ...[
                const SizedBox(height: 18),
                _buildSegmentWorkspace(context, job),
              ],
            ] else if (job != null) ...[
              const SizedBox(height: 18),
              _buildSegmentWorkspace(context, job),
              const SizedBox(height: 18),
              _buildExportDock(context, job),
            ],
          ],
        ],
      );
    });
  }

  Widget _buildProjectHeader() {
    return Obx(() {
      final title = controller.mediaTitle.value.isNotEmpty
          ? controller.mediaTitle.value
          : 'Untitled Project';
      final isEditing = controller.isEditingProjectTitle.value;
      final isSaving = controller.isSavingProject.value;
      final hasProject = controller.activeProject.value != null;
      final dubbedLangs = controller.activeProject.value?.dubbedLanguages ?? const <String>[];
      final subLangs = controller.activeProject.value?.subtitledLanguages ?? const <String>[];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller.projectTitleEditController,
                              autofocus: true,
                              onChanged: controller.setProjectTitle,
                              onSubmitted: (val) {
                                controller.setProjectTitle(val);
                                controller.isEditingProjectTitle.value = false;
                                controller.saveActiveProject(immediate: true);
                              },
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: _cardBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.textLink, width: 1.2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Save title',
                            onPressed: () {
                              controller.setProjectTitle(controller.projectTitleEditController.text);
                              controller.isEditingProjectTitle.value = false;
                              controller.saveActiveProject(immediate: true);
                            },
                            icon: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Rename project',
                            onPressed: () {
                              controller.projectTitleEditController.text = title;
                              controller.isEditingProjectTitle.value = true;
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasProject)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSaving ? Icons.sync_rounded : Icons.cloud_done_outlined,
                            size: 12,
                            color: isSaving ? AppColors.textLink : AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSaving ? 'Saving' : 'Saved',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppColors.textLink),
                        SizedBox(width: 5),
                        Text(
                          'AI Audio Studio',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a TruthWorld channel video or upload media, choose output languages, then select Dub or Subtitles.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (dubbedLangs.isNotEmpty || subLangs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (dubbedLangs.isNotEmpty)
                  _buildProjectSummaryBadge(
                    icon: Icons.multitrack_audio_rounded,
                    label: 'Dubbed: ${dubbedLangs.map((c) => DubbingLanguage.findByCode(c).name).join(', ')}',
                  ),
                if (subLangs.isNotEmpty)
                  _buildProjectSummaryBadge(
                    icon: Icons.subtitles_outlined,
                    label: 'Subtitles: ${subLangs.map((c) => DubbingLanguage.findByCode(c).name).join(', ')}',
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _buildProjectSummaryBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textLink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSourceBar() {
    return Obx(() {
      final isChannel = controller.sourceInputMode.value == 'channel_videos' &&
          controller.selectedChannelVideo.value != null;
      final sourceName = isChannel
          ? controller.selectedChannelVideo.value!.title
          : (controller.pickedFileName.value.isNotEmpty
              ? controller.pickedFileName.value
              : (controller.mediaTitle.value.isNotEmpty ? controller.mediaTitle.value : 'Source Media'));
      final durStr = controller.formatDuration(controller.estimatedDurationSeconds.value);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Icon(
              isChannel ? Icons.video_library_outlined : Icons.movie_creation_outlined,
              size: 16,
              color: AppColors.textLink,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Source: $sourceName ($durStr)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => controller.showSourceEditor.value = true,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Change Source',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textLink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVideoPreviewMonitor() {
    return Obx(() {
      final loading = controller.isPlayerLoading.value;
      final initialized = controller.isPlayerInitialized.value;
      final error = controller.playerError.value;
      final ctrl = controller.videoPlayerController;
      final job = controller.activeJob.value;
      final activeTrack = controller.activePlaybackTrack.value;
      final isAudioFallback = controller.isDubbedAudioFallbackActive.value;
      final isExporting = controller.isExportingAssets.value;

      if (!loading && !initialized && error.isEmpty && job == null) {
        return const SizedBox.shrink();
      }

      final dubbedLangs = controller.allProjectDubbedLanguages;
      final combinedVideos = controller.combinedDubbedVideosByLang;
      final combinedAudios = controller.combinedDubbedAudiosByLang;
      final showTrackBar = dubbedLangs.isNotEmpty || (job != null && job.mode == DubbingMode.dubbing);
      final activeLangForQuickDownload = activeTrack != 'original'
          ? activeTrack
          : (dubbedLangs.isNotEmpty ? dubbedLangs.first : '');
      final quickVideoUrl = activeLangForQuickDownload.isNotEmpty
          ? (combinedVideos[activeLangForQuickDownload] ?? job?.dubbedVideoUrlFor(activeLangForQuickDownload))
          : null;
      final quickAudioUrl = activeLangForQuickDownload.isNotEmpty
          ? (combinedAudios[activeLangForQuickDownload] ?? job?.dubbedAudioUrlFor(activeLangForQuickDownload))
          : null;

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF050507),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTrackBar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'MONITOR',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 2),
                        _buildMonitorTrackChip(
                          label: 'Original (${(job?.sourceLanguage ?? controller.sourceLanguage.value).toUpperCase()})',
                          isActive: activeTrack == 'original',
                          isReady: true,
                          onTap: () => controller.selectPlaybackTrack('original'),
                        ),
                        ...dubbedLangs.map((code) {
                          final lang = DubbingLanguage.findByCode(code);
                          final hasDub = (combinedVideos[code] ?? job?.dubbedVideoUrlFor(code) ?? '').isNotEmpty ||
                              (combinedAudios[code] ?? job?.dubbedAudioUrlFor(code) ?? '').isNotEmpty;
                          final isSelected = activeTrack == code;
                          final subtitle = isSelected && isAudioFallback
                              ? ' • Synced Audio'
                              : (hasDub
                                  ? ''
                                  : (job?.status == DubbingJobStatus.completed && !isExporting
                                      ? ' • Unavailable'
                                      : ' • Rendering...'));
                          return _buildMonitorTrackChip(
                            label: 'Dubbed • ${lang.name}$subtitle',
                            isActive: isSelected,
                            isReady: hasDub,
                            onTap: hasDub ? () => controller.selectPlaybackTrack(code) : null,
                          );
                        }),
                      ],
                    ),
                    if (quickVideoUrl != null || quickAudioUrl != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          final norm = activeLangForQuickDownload.trim().toLowerCase();
                          if (quickVideoUrl != null) {
                            controller.downloadExportArtifact(
                              quickVideoUrl,
                              'video_with_${norm}_dub.mp4',
                            );
                          } else if (quickAudioUrl != null) {
                            controller.downloadExportArtifact(
                              quickAudioUrl,
                              'dub_$norm.mp3',
                            );
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 15, color: Colors.black),
                        label: Text(
                          quickVideoUrl != null ? 'Download Dubbed MP4' : 'Download Dubbed Audio',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.black,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                          elevation: 0,
                        ),
                      )
                    else if (job?.status == DubbingJobStatus.completed && isExporting)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              color: AppColors.textSecondary,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Preparing dubbed video...',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (loading || initialized || error.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320, minHeight: 160),
                child: loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : error.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : (ctrl != null
                            ? GestureDetector(
                                onTap: controller.togglePlayback,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: AspectRatio(
                                        aspectRatio: ctrl.value.aspectRatio > 0
                                            ? ctrl.value.aspectRatio
                                            : 16 / 9,
                                        child: VideoPlayer(ctrl),
                                      ),
                                    ),
                                    if (!controller.isPlaying.value)
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink()),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildMonitorTrackChip({
    required String label,
    required bool isActive,
    required bool isReady,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _elevatedPill : _canvasBg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActive
                ? AppColors.textLink
                : Colors.white.withValues(alpha: isReady ? 0.12 : 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.textLink
                    : (isReady ? AppColors.success : AppColors.textTertiary),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                color: isReady ? AppColors.textPrimary : AppColors.textTertiary,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceIngestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                const Text(
                  'SOURCE VIDEO OR AUDIO',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Obx(() {
                  final sourceMode = controller.sourceInputMode.value;
                  final count = controller.channelVideos.length;
                  final hasJob = controller.activeJob.value != null;
                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _canvasBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSourceTabButton(
                              title: 'Channel Videos${count > 0 ? ' ($count)' : ''}',
                              icon: Icons.video_library_outlined,
                              isActive: sourceMode == 'channel_videos',
                              onTap: () {
                                controller.sourceInputMode.value = 'channel_videos';
                                controller.scheduleProjectAutoSave();
                              },
                            ),
                            const SizedBox(width: 2),
                            _buildSourceTabButton(
                              title: 'Upload Media',
                              icon: Icons.cloud_upload_outlined,
                              isActive: sourceMode == 'file_upload',
                              onTap: () {
                                controller.sourceInputMode.value = 'file_upload';
                                controller.scheduleProjectAutoSave();
                              },
                            ),
                          ],
                        ),
                      ),
                      if (hasJob)
                        TextButton(
                          onPressed: () => controller.showSourceEditor.value = false,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textLink,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Obx(() {
            final sourceMode = controller.sourceInputMode.value;
            if (sourceMode == 'channel_videos') {
              return _buildChannelVideosSection(context);
            } else {
              return _buildFileUploadSection(context);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildSourceTabButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 11),
        decoration: BoxDecoration(
          color: isActive ? _elevatedPill : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: Colors.white.withValues(alpha: 0.12)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Right Inspector Panel ──────────────────────────────────────
  Widget _buildInspectorPanel(BuildContext context) {
    return ColoredBox(
      color: _chromeBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: const Row(
              children: [
                Icon(Icons.tune_rounded, size: 15, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'PROJECT SETTINGS',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildInspectorContent(context, includeBottomCta: false),
            ),
          ),

          // Pinned Bottom Primary CTA Dock
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: _chromeBg,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
            ),
            child: _buildPrimaryActionCta(),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorContent(BuildContext context, {bool includeBottomCta = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLanguageRoutingSection(),
        Obx(() {
          if (controller.mode.value == DubbingMode.subtitlesOnly) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              const SizedBox(height: 14),
              _buildStudioControlsCard(),
            ],
          );
        }),
        const SizedBox(height: 14),
        const DubbingPricingCalculatorCard(),
        if (includeBottomCta) ...[
          const SizedBox(height: 18),
          _buildPrimaryActionCta(),
        ],
      ],
    );
  }

  Widget _buildLanguageRoutingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SOURCE LANGUAGE',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${DubbingLanguage.availableSourceLanguages.length} supported',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(() {
            final srcCode = controller.sourceLanguage.value;
            final srcLang = DubbingLanguage.findByCode(srcCode);

            return InkWell(
              onTap: () => Get.bottomSheet(
                DubbingSourceLanguageSheet(),
                isScrollControlled: true,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _canvasBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          ChannelWizardCountryCard.buildCountryFlagByCode(
                            srcLang.countryCode,
                            width: 22,
                            height: 15,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${srcLang.name} (${srcLang.nativeName})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'TARGET LANGUAGES',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '5 available now',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textLink,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final langs = controller.targetLanguages;
            final existingTracks = controller.selectedVideoAudioTracks;

            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...langs.map((code) {
                  final lang = DubbingLanguage.findByCode(code);
                  final isAlreadyDubbed = existingTracks.containsKey(code);

                  return Chip(
                    backgroundColor: _canvasBg,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: isAlreadyDubbed
                          ? AppColors.success.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    avatar: isAlreadyDubbed
                        ? const Icon(Icons.check_circle_outline, size: 13, color: AppColors.success)
                        : ChannelWizardCountryCard.buildCountryFlagByCode(
                            lang.countryCode,
                            width: 18,
                            height: 12,
                            borderRadius: 2,
                          ),
                    label: Text(
                      '${lang.name} (${lang.nativeName})${isAlreadyDubbed ? ' • Dubbed' : ''}',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 13, color: AppColors.textSecondary),
                    onDeleted: () => controller.toggleTargetLanguage(code),
                  );
                }),
                ActionChip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.add, size: 14, color: AppColors.textPrimary),
                  label: Text(
                    langs.isEmpty ? 'Select output language' : 'Add language',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: _elevatedPill,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  onPressed: () => Get.bottomSheet(
                    DubbingLanguageMatrixSheet(),
                    isScrollControlled: true,
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),

          // Output Mode Tabs (Dub / Subtitles) — shown after selecting output languages
          Obx(() {
            final langs = controller.targetLanguages;
            final currentMode = controller.mode.value;

            if (langs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _canvasBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select output languages above to choose Dub or Subtitles.',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OUTPUT MODE',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _canvasBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSettingsModeTab(
                          key: const Key('mode_tab_dub'),
                          label: 'Dub',
                          icon: Icons.multitrack_audio_rounded,
                          isActive: currentMode == DubbingMode.dubbing,
                          onTap: () => controller.setMode(DubbingMode.dubbing),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildSettingsModeTab(
                          key: const Key('mode_tab_subtitles'),
                          label: 'Subtitles',
                          icon: Icons.subtitles_outlined,
                          isActive: currentMode == DubbingMode.subtitlesOnly,
                          onTap: () => controller.setMode(DubbingMode.subtitlesOnly),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  currentMode == DubbingMode.subtitlesOnly
                      ? 'Generate translated SRT & VTT subtitles in your selected output languages.'
                      : 'Generate dubbed videos and audio tracks in your selected output languages.',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsModeTab({
    required Key key,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isActive ? Colors.black : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioControlsCard() {
    return Obx(() {
      final cloning = controller.voiceCloningEnabled.value;
      final isolate = controller.isolateVocals.value;
      final preserveBgm = controller.preserveBgm.value;
      final twoStage = controller.twoStageReviewEnabled.value;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'VOICE & AUDIO SETTINGS',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Get.dialog(const DubbingVoiceCloningDialog()),
                  child: const Text(
                    'Configure →',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textLink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Voice Cloning',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Preserve each speaker's natural voice across languages",
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: cloning,
                  activeThumbColor: Colors.black,
                  activeTrackColor: Colors.white,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: _elevatedPill,
                  onChanged: controller.setVoiceCloning,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildStatusTag('Clean Vocals', isolate),
                _buildStatusTag(
                  'Background Music ${preserveBgm ? "(${controller.bgmDuckingPercent.value.toInt()}% lower)" : "Off"}',
                  preserveBgm,
                ),
                _buildStatusTag('Script Review', twoStage),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatusTag(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _canvasBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: active ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: active ? AppColors.textSecondary : AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionCta() {
    return Obx(() {
      final submitting = controller.isSubmitting.value;
      final job = controller.activeJob.value;
      final isSubOnly = controller.mode.value == DubbingMode.subtitlesOnly;
      final isChannelVideo = controller.sourceInputMode.value == 'channel_videos' &&
          controller.selectedChannelVideo.value != null;
      final isJobRunning = job != null &&
          job.status != DubbingJobStatus.completed &&
          job.status != DubbingJobStatus.failed;
      final hasCompletedJobs = job?.status == DubbingJobStatus.completed ||
          controller.projectJobs.any((j) => j.status == DubbingJobStatus.completed);

      final actionTitle = isJobRunning
          ? 'Processing (${job.progressPercent}%)...'
          : (isChannelVideo
              ? (isSubOnly ? 'Generate Channel Subtitles' : 'Dub Video & Save to Audio Tracks')
              : (isSubOnly
                  ? (hasCompletedJobs ? 'Add Subtitles' : 'Generate Subtitles')
                  : (hasCompletedJobs ? 'Generate Dubs' : 'Start Dubbing')));

      final onPressed = submitting || isJobRunning
          ? null
          : () => controller.startDubbingJob();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _elevatedPill,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isJobRunning)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: AppColors.textSecondary,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            isSubOnly ? Icons.subtitles_rounded : Icons.multitrack_audio_rounded,
                            color: Colors.black,
                            size: 17,
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            actionTitle,
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: isJobRunning ? AppColors.textSecondary : Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (isChannelVideo) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync_rounded, size: 12, color: AppColors.textTertiary),
                SizedBox(width: 4),
                Text(
                  'Saved directly to your Studio Audio Tracks tab',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }

  // ── Channel Videos Section ──────────────────────────────────────
  Widget _buildChannelVideosSection(BuildContext context) {
    final signedIn = AuthService.to.isUserSignedIn;

    if (!signedIn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: _canvasBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_library_outlined, size: 22, color: AppColors.textLink),
                SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect your TruthWorld Channel',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sign in to dub channel videos directly, or switch to Upload Media.',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => controller.sourceInputMode.value = 'file_upload',
                  child: const Text(
                    'Upload File',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: controller.signInWithGoogle,
                  icon: const Icon(Icons.login, color: AppColors.textPrimary, size: 15),
                  label: const Text(
                    'Sign In with Google',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _elevatedPill,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (controller.isLoadingChannelVideos.value) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2),
      );
    }

    if (controller.channelVideos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _canvasBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Channel Videos Found',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Upload a video in TruthWorld Studio or dub a local file.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => controller.sourceInputMode.value = 'file_upload',
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Upload Media',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final selected = controller.selectedChannelVideo.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: controller.searchChannelVideos,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'Search your channel videos...',
            hintStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
            prefixIcon: const Icon(Icons.search, size: 17, color: AppColors.textSecondary),
            filled: true,
            fillColor: _canvasBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textLink, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.filteredChannelVideos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final video = controller.filteredChannelVideos[index];
              final isCurSelected = selected?.id == video.id;

              return InkWell(
                onTap: () => controller.selectChannelVideo(video),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurSelected ? _elevatedPill : _canvasBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurSelected ? AppColors.textLink : Colors.white.withValues(alpha: 0.07),
                      width: isCurSelected ? 1.2 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCurSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 15,
                            color: isCurSelected ? AppColors.textLink : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: isCurSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (video.language.isNotEmpty ? video.language : 'EN').toUpperCase(),
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textLink,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            controller.formatDuration(video.durationSeconds > 0 ? video.durationSeconds : 60),
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (selected != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _canvasBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.audiotrack, size: 14, color: AppColors.textLink),
                        const SizedBox(width: 6),
                        Text(
                          'Studio Audio Tracks (${controller.selectedVideoAudioTracks.length})',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => controller.openInStudioAudioTracks(selected),
                      child: const Row(
                        children: [
                          Text(
                            'Open in Studio',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textLink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 12, color: AppColors.textLink),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (controller.isLoadingVideoTracks.value)
                  const SizedBox(
                    height: 20,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand)),
                  )
                else if (controller.selectedVideoAudioTracks.isEmpty)
                  const Text(
                    'No dubbed tracks yet. Select target languages in Project Settings.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: controller.selectedVideoAudioTracks.keys.map((langCode) {
                      final l = DubbingLanguage.findByCode(langCode);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 11, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '${l.name} (${langCode.toUpperCase()})',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                color: AppColors.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Standalone File Upload Section ─────────────────────────────
  Widget _buildFileUploadSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller.projectTitleEditController,
          onChanged: controller.setProjectTitle,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            labelText: 'Project Title',
            labelStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            hintText: 'e.g. Science Explained Ep 4',
            hintStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: _canvasBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textLink, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Obx(() {
          final file = controller.pickedFile.value;
          final isUploading = controller.isUploadingMedia.value;
          final hasUploadedUrl = controller.mediaUrl.value.isNotEmpty;

          if (file == null && !hasUploadedUrl) {
            return InkWell(
              onTap: controller.pickMediaFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                decoration: BoxDecoration(
                  color: _canvasBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: AppColors.textLink, size: 26),
                    const SizedBox(height: 10),
                    const Text(
                      'Select Video or Audio File',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'MP4, MOV, MKV, MP3, WAV • Up to 2 Hours (4 GB)',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: controller.pickMediaFile,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _elevatedPill,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.folder_open, size: 15, color: AppColors.textPrimary),
                      label: const Text(
                        'Browse Files',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final fileName = file?.name ?? 'Selected Source Media';
          final fileSize = file != null ? controller.formatFileSize(file.size) : '';
          final durationStr = controller.formatDuration(controller.estimatedDurationSeconds.value);
          final ext = file?.extension?.toLowerCase() ?? '';
          final isAudio = const {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'}.contains(ext);

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _canvasBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasUploadedUrl
                    ? AppColors.success.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Icon(
                        isAudio ? Icons.audiotrack : Icons.movie_creation_outlined,
                        color: AppColors.textLink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 10,
                            children: [
                              Text(
                                durationStr,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              if (fileSize.isNotEmpty)
                                Text(
                                  fileSize,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 17, color: AppColors.textSecondary),
                      tooltip: 'Remove or change file',
                      onPressed: controller.clearPickedFile,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isUploading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.uploadProgress.value,
                      backgroundColor: _elevatedPill,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.textLink),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        controller.uploadStatus.value,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${(controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textLink,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ] else if (hasUploadedUrl) ...[
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 13, color: AppColors.success),
                      SizedBox(width: 6),
                      Text(
                        'Upload complete • Ready for dubbing',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          controller.uploadStatus.value.isNotEmpty
                              ? controller.uploadStatus.value
                              : 'Ready to upload (up to 2h)',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.startUpload,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Upload Now',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textLink,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Multi-Stage Pipeline Tracker ──────────────────────────────
  Widget _buildPipelineProgressTracker(DubbingJob job) {
    final stagesMap = job.stages ?? const {};
    final isJobDone = job.status == DubbingJobStatus.completed;
    final isJobFailed = job.status == DubbingJobStatus.failed;
    final isSubOnly = job.mode == DubbingMode.subtitlesOnly;

    bool isStageDone(String key) {
      if (isJobDone) return true;
      final stage = stagesMap[key];
      if (stage is Map) {
        final status = stage['status']?.toString().toLowerCase();
        return status == 'completed' || status == 'done' || status == 'skipped';
      }
      return false;
    }

    int stageProgress(String key) {
      final stage = stagesMap[key];
      if (stage is Map) {
        return (stage['progress'] as num?)?.toInt() ?? 0;
      }
      return 0;
    }

    final transDone = isStageDone('transcription');
    final dubDone = isStageDone('dubbing');
    final subDone = isStageDone('subtitles');
    final dubPct = stageProgress('dubbing');

    final audioPrepDone = isStageDone('audio_extraction') ||
        isStageDone('demux') ||
        transDone ||
        job.progressPercent >= 20;
    final speakersDone = isStageDone('diarization') ||
        (isSubOnly ? transDone : (dubDone || dubPct >= 20 || job.progressPercent >= 40));
    final transcriptDone = transDone || job.progressPercent >= 35;
    final voiceoverDone = isSubOnly
        ? (subDone || job.progressPercent >= 95)
        : (dubDone || isStageDone('synthesis') || job.progressPercent >= 95);
    final finalizeDone = isStageDone('mastering') || isStageDone('export') || isJobDone;

    final stages = [
      {'name': 'Audio Prep', 'icon': Icons.tune, 'done': audioPrepDone},
      {'name': 'Speakers', 'icon': Icons.people_outline, 'done': speakersDone},
      {'name': 'Transcript', 'icon': Icons.mic_none, 'done': transcriptDone},
      {'name': isSubOnly ? 'Subtitles' : 'Voiceover', 'icon': isSubOnly ? Icons.subtitles_outlined : Icons.record_voice_over, 'done': voiceoverDone},
      {'name': 'Finalize', 'icon': Icons.check_circle_outline, 'done': finalizeDone},
    ];

    final hasReportedProgress = job.progressPercent > 0;
    final accentColor = isJobDone
        ? AppColors.success
        : (isJobFailed ? AppColors.error : AppColors.textLink);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isJobFailed
              ? AppColors.error.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job.status.displayName.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                isJobFailed
                    ? 'Action needed'
                    : (hasReportedProgress ? '${job.progressPercent}% Complete' : job.status.displayName),
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (job.currentStepMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              job.currentStepMessage,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isJobFailed ? AppColors.error : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isJobFailed
                  ? 1.0
                  : (hasReportedProgress ? (job.progressPercent / 100.0).clamp(0.0, 1.0) : null),
              backgroundColor: _canvasBg,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.map((s) {
              final isDone = s['done'] == true;
              return Row(
                children: [
                  Icon(
                    (s['icon'] as IconData?) ?? Icons.circle,
                    size: 14,
                    color: isDone ? AppColors.textLink : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    (s['name'] as String?) ?? '',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: isDone ? AppColors.textPrimary : AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          if (isJobFailed) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.resetActiveJob,
              icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.textPrimary),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: _elevatedPill,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Segment Workspace (Script & Line Review) ───────────────────
  Widget _buildSegmentWorkspace(BuildContext context, DubbingJob job) {
    final rawActiveLang = controller.activePreviewLanguage.value;
    final activeLang = job.targetLanguages.contains(rawActiveLang)
        ? rawActiveLang
        : (job.targetLanguages.isNotEmpty ? job.targetLanguages.first : rawActiveLang);
    final segments = job.segmentsByLanguage[activeLang] ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dialogue & Script Editor',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Review and edit your script or regenerate individual lines',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: job.targetLanguages.map((code) {
                    final isSelected = activeLang == code;
                    final lang = DubbingLanguage.findByCode(code);

                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(lang.name),
                        selected: isSelected,
                        selectedColor: _elevatedPill,
                        backgroundColor: _canvasBg,
                        side: BorderSide(
                          color: isSelected ? AppColors.textLink : Colors.white.withValues(alpha: 0.08),
                        ),
                        labelStyle: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        onSelected: (val) {
                          if (val) controller.activePreviewLanguage.value = code;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (segments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  job.status == DubbingJobStatus.completed
                      ? 'Your dubbed audio, video, and subtitle files are ready for download above.'
                      : 'Transcribing audio and preparing dialogue...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...segments.map((seg) {
              final isPostTts = job.status == DubbingJobStatus.awaitingPostTtsReview ||
                  job.status == DubbingJobStatus.completed ||
                  (job.stages?['dubbing'] is Map && job.stages!['dubbing']['status'] == 'completed');
              return DubbingSegmentRow(
                segment: seg,
                isPostTtsStage: isPostTts,
                onOriginalTextChanged: (val) {
                  controller.saveSegmentEdits(
                    language: activeLang,
                    segments: segments,
                    approveForTTS: false,
                  );
                },
                onTranslatedTextChanged: (val) {
                  controller.saveSegmentEdits(
                    language: activeLang,
                    segments: segments,
                    approveForTTS: false,
                  );
                },
                onRegenerate: () {
                  controller.regenerateLine(
                    language: activeLang,
                    segmentId: seg.id,
                    newText: seg.translatedText,
                  );
                },
              );
            }),

          const SizedBox(height: 12),
          if (job.status == DubbingJobStatus.awaitingTranscriptionReview)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  controller.saveSegmentEdits(
                    language: activeLang,
                    segments: segments,
                    approveForTTS: true,
                  );
                },
                icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 17),
                label: const Text(
                  'Approve Script & Generate Dubbed Audio',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Export & Download Dock ─────────────────────────────────────
  Widget _buildExportDock(BuildContext context, DubbingJob? job) {
    final allJobs = <DubbingJob>[
      if (job != null) job,
      ...controller.projectJobs.where((j) => j.id != job?.id),
    ];
    final outputLangs = controller.allProjectOutputLanguages;
    final combinedVideos = controller.combinedDubbedVideosByLang;
    final combinedAudios = controller.combinedDubbedAudiosByLang;
    final combinedDialogue = controller.combinedDialogueAudiosByLang;
    final combinedTranslations = controller.combinedTranslationJsonByLang;
    final combinedSrt = controller.combinedSubtitlesSrtByLang;
    final combinedVtt = controller.combinedSubtitlesVttByLang;

    String? findFirstShared(String? Function(DubbingJob j) selector) {
      for (final j in allJobs) {
        final v = selector(j);
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final vocalsStemUrl = findFirstShared((j) => j.vocalsStemMp3);
    final backgroundStemUrl = findFirstShared((j) => j.backgroundStemMp3);
    final reportJsonUrl = findFirstShared((j) => j.reportJson);
    final hasSharedArtifacts =
        vocalsStemUrl != null || backgroundStemUrl != null || reportJsonUrl != null;
    final hasAnyExports = allJobs.any((j) => j.exportUrls != null) ||
        combinedVideos.isNotEmpty ||
        combinedAudios.isNotEmpty ||
        combinedSrt.isNotEmpty ||
        combinedVtt.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.download_done_rounded, color: AppColors.textLink, size: 18),
              SizedBox(width: 8),
              Text(
                'Output Artifacts & Downloads',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasAnyExports)
            Obx(() {
              final exporting = controller.isExportingAssets.value;
              if (job == null || job.status != DubbingJobStatus.completed) {
                return const Text(
                  'Downloadable files will appear automatically as soon as processing completes.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                );
              }
              return _buildDownloadButton(
                icon: exporting ? Icons.hourglass_top_rounded : Icons.download_rounded,
                label: exporting ? 'Preparing output artifacts...' : 'Prepare output artifacts',
                onTap: exporting ? () {} : () => controller.exportPackage(),
              );
            })
          else ...[
            for (final code in outputLangs)
              _buildLanguageDownloads(
                job: allJobs.firstWhere(
                  (j) => j.mode == DubbingMode.dubbing && j.targetLanguages.contains(code),
                  orElse: () => allJobs.firstWhere(
                    (j) => j.targetLanguages.contains(code),
                    orElse: () => job ?? allJobs.first,
                  ),
                ),
                langCode: code,
                languageName: DubbingLanguage.findByCode(code).name,
                videoUrl: combinedVideos[code],
                audioUrl: combinedAudios[code],
                dialogueUrl: combinedDialogue[code],
                translationJsonUrl: combinedTranslations[code],
                subtitlesSrtUrl: combinedSrt[code],
                subtitlesVttUrl: combinedVtt[code],
              ),
            if (hasSharedArtifacts) ...[
              const SizedBox(height: 6),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
              const Text(
                'STEMS & REPORT',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (vocalsStemUrl != null)
                    _buildDownloadButton(
                      icon: Icons.mic_none_rounded,
                      label: 'Vocals Stem (vocals_stem.mp3)',
                      onTap: () => controller.downloadExportArtifact(
                        vocalsStemUrl,
                        'vocals_stem.mp3',
                      ),
                    ),
                  if (backgroundStemUrl != null)
                    _buildDownloadButton(
                      icon: Icons.music_note_outlined,
                      label: 'Background Stem (background_stem.mp3)',
                      onTap: () => controller.downloadExportArtifact(
                        backgroundStemUrl,
                        'background_stem.mp3',
                      ),
                    ),
                  if (reportJsonUrl != null)
                    _buildDownloadButton(
                      icon: Icons.analytics_outlined,
                      label: 'Report (report.json)',
                      onTap: () => controller.downloadExportArtifact(
                        reportJsonUrl,
                        'report.json',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => controller.exportPackage(),
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 15),
              label: const Text(
                'Refresh output artifacts',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageDownloads({
    required DubbingJob job,
    required String langCode,
    required String languageName,
    String? videoUrl,
    String? audioUrl,
    String? dialogueUrl,
    String? translationJsonUrl,
    String? subtitlesSrtUrl,
    String? subtitlesVttUrl,
  }) {
    final norm = langCode.trim().toLowerCase();
    final canGenerateMp4 = job.status == DubbingJobStatus.completed &&
        job.mode == DubbingMode.dubbing &&
        job.sourceMediaType != 'audio' &&
        videoUrl == null &&
        audioUrl != null;
    final hasAny = videoUrl != null ||
        audioUrl != null ||
        dialogueUrl != null ||
        translationJsonUrl != null ||
        subtitlesSrtUrl != null ||
        subtitlesVttUrl != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageName,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (!hasAny)
            const Text(
              'Not available for this language',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (videoUrl != null)
                  _buildDownloadButton(
                    icon: Icons.movie_outlined,
                    label: 'Dubbed MP4 (video_with_${norm}_dub.mp4)',
                    onTap: () => controller.downloadExportArtifact(
                      videoUrl,
                      'video_with_${norm}_dub.mp4',
                    ),
                  )
                else if (canGenerateMp4)
                  Obx(() {
                    final busy = controller.isExportingAssets.value;
                    return _buildDownloadButton(
                      icon: busy ? Icons.hourglass_top_rounded : Icons.movie_creation_outlined,
                      label: busy ? 'Generating Dubbed MP4...' : 'Generate Dubbed MP4',
                      onTap: busy ? () {} : () => controller.exportPackage(),
                    );
                  }),
                if (audioUrl != null)
                  _buildDownloadButton(
                    icon: Icons.audiotrack_outlined,
                    label: 'Master Audio (dub_$norm.mp3)',
                    onTap: () => controller.downloadExportArtifact(
                      audioUrl,
                      'dub_$norm.mp3',
                    ),
                  ),
                if (dialogueUrl != null)
                  _buildDownloadButton(
                    icon: Icons.record_voice_over_outlined,
                    label: 'Dialogue-only TTS (dialogue_$norm.mp3)',
                    onTap: () => controller.downloadExportArtifact(
                      dialogueUrl,
                      'dialogue_$norm.mp3',
                    ),
                  ),
                if (translationJsonUrl != null)
                  _buildDownloadButton(
                    icon: Icons.translate_rounded,
                    label: 'Translation (translation_$norm.json)',
                    onTap: () => controller.downloadExportArtifact(
                      translationJsonUrl,
                      'translation_$norm.json',
                    ),
                  ),
                if (subtitlesSrtUrl != null)
                  _buildDownloadButton(
                    icon: Icons.subtitles_outlined,
                    label: 'Subtitles ($norm.srt)',
                    onTap: () => controller.downloadExportArtifact(
                      subtitlesSrtUrl,
                      '$norm.srt',
                    ),
                  ),
                if (subtitlesVttUrl != null)
                  _buildDownloadButton(
                    icon: Icons.closed_caption_outlined,
                    label: 'Subtitles ($norm.vtt)',
                    onTap: () => controller.downloadExportArtifact(
                      subtitlesVttUrl,
                      '$norm.vtt',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textSecondary, size: 15),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: _canvasBg,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
    );
  }
}
