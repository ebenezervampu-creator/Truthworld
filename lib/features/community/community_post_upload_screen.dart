import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/presentation/views/upload/community_upload_components.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// COMMUNITY POST UPLOAD SCREEN — Declarative, Responsive, Zero-setState
// =============================================================================

/// Declarative community post creation and upload coordinator screen.
class CommunityPostUploadScreen extends StatelessWidget {
  final CommunityDraft? draftToLoad;

  const CommunityPostUploadScreen({super.key, this.draftToLoad});

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 900;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CommunityPostUploadController>()
        ? Get.find<CommunityPostUploadController>()
        : Get.put(CommunityPostUploadController());

    if (draftToLoad != null && controller.currentDraft.value != draftToLoad) {
      controller.loadDraft(draftToLoad!);
    }

    final isMobile = _isMobile(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 28.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommunityUploadHeader(isMobile: isMobile),
                    const SizedBox(height: 24),
                    if (isMobile)
                      _buildMobileLayout()
                    else
                      _buildDesktopLayout(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── DESKTOP LAYOUT (2 Columns) ─────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return const Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Post Content)
            Expanded(
              flex: 65,
              child: CommunityPostContentInputs(),
            ),
            SizedBox(width: 28),
            // Right Column (Visibility + Additional Options)
            Expanded(
              flex: 35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommunityPostVisibilitySection(),
                  SizedBox(height: 24),
                  CommunityPostAdditionalOptions(),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        CommunityCopyrightDeclarationCard(),
        SizedBox(height: 24),
        CommunityUploadActionButtons(),
      ],
    );
  }

  // ── MOBILE LAYOUT (1 Column Stacked) ───────────────────────────────────────

  Widget _buildMobileLayout() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityPostContentInputs(),
        SizedBox(height: 20),
        CommunityPostVisibilitySection(),
        SizedBox(height: 20),
        CommunityPostAdditionalOptions(),
        SizedBox(height: 20),
        CommunityCopyrightDeclarationCard(),
        SizedBox(height: 24),
        CommunityUploadActionButtons(),
      ],
    );
  }
}
