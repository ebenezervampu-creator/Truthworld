import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_project.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/theme/dubbing_studio_theme.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Landing workspace for TruthWorld Dubbing Studio when no project is open.
///
/// Features the flagship obsidian hero with a dashed quick-start dropzone,
/// status filter tabs, search + grid/list toggle, and media-first project cards.
class DubbingProjectsHub extends GetView<DubbingStudioController> {
  const DubbingProjectsHub({super.key});

  /// Opens the dialog to name and create a new Dubbing Studio project.
  static Future<void> showCreateProjectDialog(
    BuildContext context,
    DubbingStudioController controller,
  ) async {
    final isSignedIn = Get.isRegistered<AuthService>() && AuthService.to.isUserSignedIn;
    if (!isSignedIn) {
      await controller.signInWithGoogle();
      final nowSignedIn = Get.isRegistered<AuthService>() && AuthService.to.isUserSignedIn;
      if (!nowSignedIn) return;
    }

    controller.createProjectTitleController.clear();
    await Get.dialog<void>(
      Dialog(
        backgroundColor: DubbingStudioTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: DubbingStudioTheme.borderMedium),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Project',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: DubbingStudioTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.close, color: DubbingStudioTheme.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Name your project to start dubbing videos or generating multilingual subtitles.',
                  style: DubbingStudioTheme.body,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller.createProjectTitleController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (val) async {
                    Get.back();
                    await controller.createNewProject(title: val);
                  },
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    color: DubbingStudioTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Project Name',
                    labelStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: DubbingStudioTheme.textSecondary,
                      fontSize: 12.5,
                    ),
                    hintText: 'e.g. Science Explained Episode 4',
                    hintStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: DubbingStudioTheme.textTertiary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: DubbingStudioTheme.inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: DubbingStudioTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: DubbingStudioTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: DubbingStudioTheme.accentIndigo, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: DubbingStudioTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final title = controller.createProjectTitleController.text;
                        Get.back();
                        await controller.createNewProject(title: title);
                      },
                      icon: const Icon(Icons.add_rounded, size: 17, color: Colors.black),
                      label: const Text(
                        'Create Project',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showPasteUrlDialog(
    BuildContext context,
    DubbingStudioController controller,
  ) async {
    final urlCtrl = TextEditingController();
    await Get.dialog<void>(
      Dialog(
        backgroundColor: DubbingStudioTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: DubbingStudioTheme.borderMedium),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste Media URL',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: DubbingStudioTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter a direct MP4, MOV, WAV, or MP3 media link to open in the studio.',
                  style: DubbingStudioTheme.body,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlCtrl,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: DubbingStudioTheme.monoFamily,
                    fontFamilyFallback: DubbingStudioTheme.monoFallbacks,
                    color: DubbingStudioTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://cdn.example.com/video.mp4',
                    hintStyle: const TextStyle(color: DubbingStudioTheme.textTertiary),
                    filled: true,
                    fillColor: DubbingStudioTheme.inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: DubbingStudioTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: DubbingStudioTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: DubbingStudioTheme.accentIndigo, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: DubbingStudioTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final url = urlCtrl.text;
                        Get.back();
                        await controller.quickPasteUrlFromHub(url);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Open Media',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    urlCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Section: Intro Left + Dashed Dropzone Right ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 840;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: _buildHeroIntro()),
                        const SizedBox(width: 28),
                        Expanded(flex: 6, child: _buildDashedDropzone(context)),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroIntro(),
                      const SizedBox(height: 22),
                      _buildDashedDropzone(context),
                    ],
                  );
                },
              ),

              // ── Saved Projects Toolbar & Grid/List ──
              Obx(() {
                final loading = controller.isLoadingProjects.value;
                final allProjects = controller.savedProjects;

                if (loading && allProjects.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (allProjects.isEmpty) {
                  return const SizedBox.shrink();
                }

                final filtered = controller.filteredHubProjects;
                final isGrid = controller.hubIsGridView.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    _buildFilterAndSearchBar(context, allProjects),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SAVED PROJECTS (${filtered.length})',
                          style: DubbingStudioTheme.labelCaps,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      _buildEmptyFilterState()
                    else if (isGrid)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth > 900
                              ? 3
                              : (constraints.maxWidth > 560 ? 2 : 1);
                          const spacing = 16.0;
                          final cardWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: filtered
                                .map((p) => SizedBox(
                                      width: cardWidth,
                                      child: _buildSavedProjectCard(context, p),
                                    ))
                                .toList(),
                          );
                        },
                      )
                    else
                      Column(
                        children: filtered
                            .map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildSavedProjectListRow(context, p),
                                ))
                            .toList(),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Projects', style: DubbingStudioTheme.displayHero),
        const SizedBox(height: 10),
        const Text(
          'Dub videos, clone speaker tone, and generate frame-accurate subtitles across languages.',
          style: DubbingStudioTheme.body,
        ),
        const SizedBox(height: 16),
        Obx(() {
          final total = controller.savedProjects.length;
          final actionCount = controller.savedProjects.where((p) => p.latestStatus == 'failed').length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: DubbingStudioTheme.accentIndigo,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  total == 0
                      ? 'Studio ready  •  70+ languages supported'
                      : '$total ${total == 1 ? 'project' : 'projects'}  •  $actionCount action needed',
                  style: DubbingStudioTheme.monoMeta,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDashedDropzone(BuildContext context) {
    return InkWell(
      onTap: () => showCreateProjectDialog(context, controller),
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: DubbingStudioTheme.borderMedium,
          radius: 16,
          strokeWidth: 1.3,
          dashWidth: 6,
          dashSpace: 5,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            color: DubbingStudioTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DubbingStudioTheme.accentIndigoBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: DubbingStudioTheme.accentIndigo.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: DubbingStudioTheme.accentIndigo,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Drop video or audio here to start',
                          style: DubbingStudioTheme.cardTitle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'MP4, MOV, WAV, MP3 up to 2 hours',
                          style: DubbingStudioTheme.monoMeta.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildDropzoneActionButton(
                    icon: Icons.video_file_outlined,
                    label: 'Upload Media',
                    onTap: controller.quickUploadFromHub,
                  ),
                  _buildDropzoneActionButton(
                    icon: Icons.link_rounded,
                    label: 'Paste URL',
                    onTap: () => _showPasteUrlDialog(context, controller),
                  ),
                  _buildDropzoneActionButton(
                    key: const Key('create_new_project_card'),
                    icon: Icons.add_rounded,
                    label: 'Create New Project',
                    onTap: () => showCreateProjectDialog(context, controller),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropzoneActionButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: DubbingStudioTheme.textPrimary),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: DubbingStudioTheme.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: DubbingStudioTheme.surfaceElevated,
        side: BorderSide(color: DubbingStudioTheme.borderSubtle),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _buildFilterAndSearchBar(BuildContext context, List<DubbingProject> allProjects) {
    final completedCount = allProjects.where((p) => p.latestStatus == 'completed').length;
    final processingCount = allProjects.where((p) => p.latestStatus == 'processing').length;
    final failedCount = allProjects.where((p) => p.latestStatus == 'failed').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 760;

        final filterTabs = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTab('all', 'All', allProjects.length),
              const SizedBox(width: 6),
              _buildFilterTab('completed', 'Completed', completedCount),
              const SizedBox(width: 6),
              _buildFilterTab('processing', 'Processing', processingCount),
              const SizedBox(width: 6),
              _buildFilterTab('failed', 'Action Needed', failedCount),
            ],
          ),
        );

        final searchAndToggle = Row(
          mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (isWide)
              SizedBox(width: 240, child: _buildSearchField())
            else
              Expanded(child: _buildSearchField()),
            const SizedBox(width: 10),
            _buildViewToggle(),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: filterTabs),
              const SizedBox(width: 16),
              searchAndToggle,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            filterTabs,
            const SizedBox(height: 12),
            searchAndToggle,
          ],
        );
      },
    );
  }

  Widget _buildFilterTab(String key, String label, int count) {
    return Obx(() {
      final isActive = controller.hubFilterStatus.value == key;
      return InkWell(
        onTap: () => controller.hubFilterStatus.value = key,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? DubbingStudioTheme.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive ? DubbingStudioTheme.borderMedium : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: isActive ? DubbingStudioTheme.textPrimary : DubbingStudioTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: DubbingStudioTheme.monoMeta.copyWith(
                  fontSize: 11.5,
                  color: isActive ? DubbingStudioTheme.textSecondary : DubbingStudioTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller.hubSearchController,
        onChanged: (val) => controller.hubSearchQuery.value = val,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: DubbingStudioTheme.textPrimary,
          fontSize: 12.5,
        ),
        decoration: InputDecoration(
          hintText: 'Search projects or languages...',
          hintStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: DubbingStudioTheme.textTertiary,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: DubbingStudioTheme.textTertiary),
          filled: true,
          fillColor: DubbingStudioTheme.inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: DubbingStudioTheme.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: DubbingStudioTheme.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: DubbingStudioTheme.borderStrong),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Obx(() {
      final isGrid = controller.hubIsGridView.value;
      return Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: DubbingStudioTheme.inputBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: DubbingStudioTheme.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleIcon(
              icon: Icons.grid_view_rounded,
              active: isGrid,
              onTap: () => controller.hubIsGridView.value = true,
            ),
            _buildToggleIcon(
              icon: Icons.view_list_rounded,
              active: !isGrid,
              onTap: () => controller.hubIsGridView.value = false,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildToggleIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? DubbingStudioTheme.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? DubbingStudioTheme.textPrimary : DubbingStudioTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: DubbingStudioTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DubbingStudioTheme.borderSubtle),
      ),
      child: const Column(
        children: [
          Icon(Icons.filter_list_off_rounded, size: 28, color: DubbingStudioTheme.textTertiary),
          SizedBox(height: 10),
          Text(
            'No matching projects',
            style: DubbingStudioTheme.cardTitle,
          ),
          SizedBox(height: 4),
          Text(
            'Try clearing your search or switching status filters.',
            style: DubbingStudioTheme.body,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedProjectCard(BuildContext context, DubbingProject project) {
    final (statusLabel, statusColor) = _statusPresentation(project.latestStatus);

    final dubbedNames = project.dubbedLanguages
        .map((c) => DubbingLanguage.findByCode(c).name)
        .toList();
    final subNames = project.subtitledLanguages
        .map((c) => DubbingLanguage.findByCode(c).name)
        .toList();

    return InkWell(
      onTap: () => controller.openProject(project),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: DubbingStudioTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DubbingStudioTheme.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Media Preview Header ──
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF14141C),
                      Color(0xFF0A0A0E),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildProjectMediaPreview(project),
                    ),
                    // Subtle top & bottom gradient scrim for badge legibility over video frames
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top-left status pill
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xCC050507),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Top-right overflow menu
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _buildProjectOverflowMenu(context, project),
                    ),
                    // Bottom-right duration badge
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xCC050507),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: DubbingStudioTheme.borderSubtle),
                        ),
                        child: Text(
                          _formatDuration(project.durationSeconds),
                          style: DubbingStudioTheme.monoBadge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Card Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DubbingStudioTheme.cardTitle,
                  ),
                  const SizedBox(height: 10),
                  if (dubbedNames.isNotEmpty || subNames.isNotEmpty || project.targetLanguages.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (dubbedNames.isNotEmpty)
                          _buildProjectTag(
                            icon: Icons.multitrack_audio_rounded,
                            label: 'Dub: ${dubbedNames.join(', ')}',
                          ),
                        if (subNames.isNotEmpty)
                          _buildProjectTag(
                            icon: Icons.subtitles_outlined,
                            label: 'Sub: ${subNames.join(', ')}',
                          ),
                        if (dubbedNames.isEmpty && subNames.isEmpty && project.targetLanguages.isNotEmpty)
                          _buildProjectTag(
                            icon: Icons.translate_rounded,
                            label: project.targetLanguages
                                .map((c) => DubbingLanguage.findByCode(c).name)
                                .join(', '),
                          ),
                      ],
                    )
                  else
                    const Text(
                      'No output languages selected yet',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: DubbingStudioTheme.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Divider(color: DubbingStudioTheme.borderSubtle, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _sourceLabel(project),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: DubbingStudioTheme.textTertiary,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeTime(project.updatedAt),
                        style: DubbingStudioTheme.monoMeta.copyWith(
                          fontSize: 11,
                          color: DubbingStudioTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectMediaPreview(DubbingProject project) {
    final thumbUrl = controller.getProjectThumbnailUrl(project);
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      return Image.network(
        thumbUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildMediaFallbackIcon(project),
      );
    }

    if (project.sourceMediaType != 'audio' && project.sourceMediaUrl.isNotEmpty) {
      controller.ensureHubVideoFrame(project.sourceMediaUrl);
      return Obx(() {
        final frameCtrl = controller.hubFrameControllers[project.sourceMediaUrl];
        if (frameCtrl != null &&
            frameCtrl.value.isInitialized &&
            frameCtrl.value.size.width > 0 &&
            frameCtrl.value.size.height > 0) {
          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: frameCtrl.value.size.width,
              height: frameCtrl.value.size.height,
              child: VideoPlayer(frameCtrl),
            ),
          );
        }
        return _buildMediaFallbackIcon(project);
      });
    }

    return _buildMediaFallbackIcon(project);
  }

  Widget _buildMediaFallbackIcon(DubbingProject project) {
    return Center(
      child: Icon(
        project.sourceMediaType == 'audio'
            ? Icons.graphic_eq_rounded
            : Icons.movie_creation_outlined,
        size: 34,
        color: Colors.white.withValues(alpha: 0.12),
      ),
    );
  }

  Widget _buildSavedProjectListRow(BuildContext context, DubbingProject project) {
    final (statusLabel, statusColor) = _statusPresentation(project.latestStatus);
    return InkWell(
      onTap: () => controller.openProject(project),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: DubbingStudioTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DubbingStudioTheme.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DubbingStudioTheme.cardTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_sourceLabel(project)}  •  $statusLabel',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: DubbingStudioTheme.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatDuration(project.durationSeconds),
              style: DubbingStudioTheme.monoMeta.copyWith(fontSize: 11.5),
            ),
            const SizedBox(width: 14),
            Text(
              _formatRelativeTime(project.updatedAt),
              style: DubbingStudioTheme.monoMeta.copyWith(
                fontSize: 11,
                color: DubbingStudioTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            _buildProjectOverflowMenu(context, project),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectOverflowMenu(BuildContext context, DubbingProject project) {
    return PopupMenuButton<String>(
      tooltip: 'Project options',
      color: DubbingStudioTheme.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: DubbingStudioTheme.borderMedium),
      ),
      onSelected: (value) {
        if (value == 'open') {
          controller.openProject(project);
        } else if (value == 'delete') {
          _confirmDeleteProject(context, project);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'open',
          child: Text(
            'Open Studio',
            style: TextStyle(color: DubbingStudioTheme.textPrimary, fontSize: 13),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete Project',
            style: TextStyle(color: DubbingStudioTheme.accentRose, fontSize: 13),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0x99050507),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 17, color: DubbingStudioTheme.textSecondary),
      ),
    );
  }

  Widget _buildProjectTag({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DubbingStudioTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: DubbingStudioTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: DubbingStudioTheme.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: DubbingStudioTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusPresentation(String status) {
    return switch (status) {
      'completed' => ('Completed', DubbingStudioTheme.accentEmerald),
      'processing' => ('Processing', DubbingStudioTheme.accentSky),
      'failed' => ('Action needed', DubbingStudioTheme.accentAmber),
      _ => ('Draft', DubbingStudioTheme.textSecondary),
    };
  }

  String _sourceLabel(DubbingProject project) {
    if (project.sourceInputMode == 'channel_videos') return 'Channel Video';
    if (project.pickedFileName.isNotEmpty) return project.pickedFileName;
    return 'Uploaded Media';
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _confirmDeleteProject(BuildContext context, DubbingProject project) async {
    await Get.dialog<void>(
      AlertDialog(
        backgroundColor: DubbingStudioTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: DubbingStudioTheme.borderMedium),
        ),
        title: const Text(
          'Delete Project?',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: DubbingStudioTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Remove "${project.title}" from your projects list?',
          style: DubbingStudioTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: DubbingStudioTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteProject(project);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DubbingStudioTheme.accentRose,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(int timestampMs) {
    if (timestampMs <= 0) return 'Recently';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestampMs));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        dashedPath.addPath(metric.extractPath(distance, next), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
