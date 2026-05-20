import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/commnuity/data/models/poll_model.dart';
import 'package:truthworld/features/commnuity/poll_upload_controller.dart';
import 'package:truthworld/features/presentation/widgets/upload_shared_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

// =============================================================================
// POLL UPLOAD SCREEN â€” 100% StatelessWidget + GetX
// =============================================================================

class PollUploadScreen extends StatelessWidget {
  final bool inTab;
  PollUploadScreen({super.key, this.inTab = false});

  final _questionCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PollUploadController get _c => Get.find<PollUploadController>();

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (inTab) {
      return _isMobile(context)
          ? _buildMobileForm(context, isDark)
          : _buildDesktopFormContent(context, isDark);
    }
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.bgPage
          : AppColors.textPrimary,
      body: SafeArea(
        child: _isMobile(context)
            ? _buildMobileLayout(context, isDark)
            : _buildDesktopLayout(context, isDark),
      ),
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” DESKTOP â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildDesktopLayout(BuildContext context, bool isDark) {
    return Row(
      children: [
        _buildSidebar(isDark),
        Expanded(
          child: Center(child: _buildDesktopFormContent(context, isDark)),
        ),
      ],
    );
  }

  Widget _buildDesktopFormContent(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPollCard(isDark),
              const SizedBox(height: 24),
              _buildSettingsCard(isDark),
              const SizedBox(height: 24),
              _buildPublishButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” MOBILE â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildMobileAppBar(isDark),
        Expanded(child: _buildMobileForm(context, isDark)),
      ],
    );
  }

  Widget _buildMobileForm(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            UploadChannelSelector(
              channels: _c.channels,
              selectedChannel: _c.selectedChannel,
              onChanged: _c.selectChannel,
            ),
            const SizedBox(height: 16),
            _buildPollCard(isDark),
            const SizedBox(height: 16),
            _buildSettingsCard(isDark),
            const SizedBox(height: 20),
            _buildPublishButton(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” POLL CARD â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildPollCard(bool isDark) {
    return Obx(() {
      return _card(
        isDark,
        icon: Icons.poll_rounded,
        title: 'Create Your Poll',
        children: [
          // Poll type selector
          Row(
            children: [
              _typeChip(
                isDark,
                PollType.yesNo,
                'Yes / No',
                Icons.thumbs_up_down_rounded,
              ),
              const SizedBox(width: 10),
              _typeChip(
                isDark,
                PollType.multiChoice,
                'Multi-Choice',
                Icons.list_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Question
          UploadInputField(
            controller: _questionCtrl,
            label: 'Question',
            icon: Icons.help_outline_rounded,
            hint: 'Ask your audience something...',
            maxLength: 200,
            onChanged: (v) => _c.updateQuestion(v),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Question is required' : null,
          ),

          const SizedBox(height: 20),

          // Options
          if (_c.pollType.value == PollType.yesNo) ...[
            Row(
              children: [
                Expanded(
                  child: _previewPill(
                    isDark,
                    'Yes',
                    Icons.check_rounded,
                    AppColors.bgPage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _previewPill(
                    isDark,
                    'No',
                    Icons.close_rounded,
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.list_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Options (3â€“5)',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimary70
                        : Color(0xFFFFB703),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_c.pollOptions.length, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: _c.pollOptions[i],
                        onChanged: (v) => _c.updateOption(i, v),
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.bgPage,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Option ${i + 1}',
                          hintStyle: GoogleFonts.roboto(
                            color: isDark
                                ? AppColors.textPrimary30
                                : AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.bgPage
                              : AppColors.textPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Color(0xFFFFB703)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Color(0xFFFFB703)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.textSecondary,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_c.pollOptions.length > 3)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => _c.removeOption(i),
                      ),
                  ],
                ),
              );
            }),
            if (_c.pollOptions.length < 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _c.addOption,
                  icon: Icon(
                    Icons.add_rounded,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    'Add Option',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),

          // Duration
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: isDark
                    ? AppColors.textPrimary38
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Poll Duration',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimary70
                      : const Color(0xFFFFB703),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [null, 1, 3, 7].map((days) {
              final isSelected = _c.pollDurationDays.value == days;
              return InkWell(
                onTap: () => _c.pollDurationDays.value = days,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textSecondary.withAlpha(35)
                        : isDark
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textSecondary
                          : isDark
                          ? const Color(0xFFFFB703)
                          : AppColors.textSecondary,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    days == null
                        ? 'No limit'
                        : days == 1
                        ? '1 day'
                        : '$days days',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textSecondary
                          : isDark
                          ? AppColors.textPrimary60
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  // ━━━ SETTINGS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildSettingsCard(bool isDark) {
    return _card(
      isDark,
      icon: Icons.tune_rounded,
      title: 'Settings',
      children: [
        Text(
          'Visibility',
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textPrimary70
                : const Color(0xFFFFB703),
          ),
        ),
        const SizedBox(height: 10),
        UploadVisibilitySelector(selectedVisibility: _c.selectedVisibility),
      ],
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” PUBLISH â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildPublishButton(bool isDark) {
    return Obx(
      () => UploadPublishButton(
        canPublish: _c.canPublish,
        isUploading: _c.isUploading.value,
        onPublish: () {
          if (_formKey.currentState?.validate() != true) return;
          _c.publishPoll();
        },
        accentColor: AppColors.textSecondary,
      ),
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” SHARED â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        border: Border(
          right: BorderSide(
            color: isDark
                ? AppColors.bgSurface
                : AppColors.textSecondary,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.bgSurface
                      : AppColors.textSecondary,
                ),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brand, Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create Poll',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.bgPage,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: UploadChannelSelector(
              channels: _c.channels,
              selectedChannel: _c.selectedChannel,
              onChanged: _c.selectChannel,
            ),
          ),
          const Spacer(),
          _buildBackButton(isDark),
        ],
      ),
    );
  }

  Widget _buildMobileAppBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.bgSurface
                : AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Get.back(),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.settings_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Text(
            'Create Poll',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.bgPage,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          label: Text(
            'Back',
            style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark
                ? AppColors.textPrimary60
                : AppColors.textSecondary,
            side: BorderSide(
              color: isDark
                  ? const Color(0xFFFFB703)
                  : AppColors.textSecondary,
            ),
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(bool isDark, PollType type, String label, IconData icon) {
    return Obx(() {
      final isSelected = _c.pollType.value == type;
      return Expanded(
        child: InkWell(
          onTap: () => _c.setPollType(type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.textSecondary.withAlpha(30)
                  : isDark
                  ? AppColors.bgPage
                  : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.textSecondary
                    : isDark
                    ? const Color(0xFFFFB703)
                    : AppColors.textSecondary,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.textSecondary
                        : isDark
                        ? AppColors.textPrimary60
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _previewPill(bool isDark, String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    bool isDark, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFFB703)
              : AppColors.textSecondary,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withAlpha(isDark ? 60 : 12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.brand, Color(0xFF8B5CF6)],
                  ),
                ),
                child: Icon(icon, size: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.bgPage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}





