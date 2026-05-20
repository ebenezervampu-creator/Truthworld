import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';

class StudioSettingsPage extends StatelessWidget {
  const StudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final StudioSettingsController controller = Get.put(StudioSettingsController());

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgInput,
        title: Text(
          'Studio Settings',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: Obx(() {
        if (controller.isLoadingData.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          );
        }

        if (controller.userData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_rounded, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'No settings available',
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please sign in with your creator account.',
                  style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isLargeScreen = constraints.maxWidth >= 800;
            if (isLargeScreen) {
              return _buildDesktopLayout(context, controller);
            } else {
              return _buildMobileLayout(context, controller);
            }
          },
        );
      }),
    );
  }

  // ==========================================
  // DESKTOP & TABLET LAYOUT (Split Pane Tabs)
  // ==========================================
  Widget _buildDesktopLayout(BuildContext context, StudioSettingsController controller) {
    final tabs = [
      {'label': 'General', 'icon': Icons.tune_rounded},
      {'label': 'Channel', 'icon': Icons.smart_display_outlined},
      {'label': 'Upload Defaults', 'icon': Icons.cloud_upload_outlined},
      {'label': 'Permissions', 'icon': Icons.people_outline_rounded},
      {'label': 'Community', 'icon': Icons.forum_outlined},
      {'label': 'Creator Demographics', 'icon': Icons.analytics_outlined},
      {'label': 'Agreements', 'icon': Icons.description_outlined},
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Navigation
        Container(
          width: 250,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white10)),
            color: AppColors.bgInput,
          ),
          child: ListView.builder(
            itemCount: tabs.length,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return Obx(() {
                final isSelected = controller.activeTab.value == index;
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.activeTab.value = index;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppColors.brand.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          color: isSelected ? AppColors.brand : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            tab['label'] as String,
                            style: GoogleFonts.roboto(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });
            },
          ),
        ),
        // Content Area
        Expanded(
          child: Obx(() {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(controller.activeTab.value),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tabs[controller.activeTab.value]['label'] as String,
                        style: GoogleFonts.roboto(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTabContent(controller.activeTab.value, controller),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE LAYOUT (Index card view -> Sub-page)
  // ==========================================
  Widget _buildMobileLayout(BuildContext context, StudioSettingsController controller) {
    final tabs = [
      {
        'label': 'General',
        'icon': Icons.tune_rounded,
        'desc': 'Default currency & general preferences'
      },
      {
        'label': 'Channel Settings',
        'icon': Icons.smart_display_outlined,
        'desc': 'Keywords, Audience, and Feature eligibility'
      },
      {
        'label': 'Upload Defaults',
        'icon': Icons.cloud_upload_outlined,
        'desc': 'Preset metadata for automated uploads'
      },
      {
        'label': 'Permissions',
        'icon': Icons.people_outline_rounded,
        'desc': 'Collaborator management and role controls'
      },
      {
        'label': 'Community Filters',
        'icon': Icons.forum_outlined,
        'desc': 'Moderation lists, blocked links, and comment rules'
      },
      {
        'label': 'Creator Demographics',
        'icon': Icons.analytics_outlined,
        'desc': 'Aggregated inclusivity channel survey'
      },
      {
        'label': 'Agreements',
        'icon': Icons.description_outlined,
        'desc': 'Platform terms and distribution licensing'
      },
    ];

    return ListView.builder(
      itemCount: tabs.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final tab = tabs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(tab['icon'] as IconData, color: AppColors.brand, size: 24),
            ),
            title: Text(
              tab['label'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tab['desc'] as String,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: () {
              HapticFeedback.lightImpact();
              Get.to(() => _MobileSettingsSubPage(
                    title: tab['label'] as String,
                    tabIndex: index,
                    controller: controller,
                  ));
            },
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB ROUTER & CONTENTS BUILDER
  // ==========================================
  Widget _buildTabContent(int index, StudioSettingsController controller) {
    switch (index) {
      case 0:
        return _buildGeneralTab(controller);
      case 1:
        return _buildChannelTab(controller);
      case 2:
        return _buildUploadDefaultsTab(controller);
      case 3:
        return _buildPermissionsTab(controller);
      case 4:
        return _buildCommunityTab(controller);
      case 5:
        return _buildDemographicsTab(controller);
      case 6:
        return _buildAgreementsTab(controller);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===== GENERAL TAB =====
  Widget _buildGeneralTab(StudioSettingsController controller) {
    final activeCurrency = controller.userData['defaultCurrency'] ?? 'USD';
    final currencies = [
      {'code': 'USD', 'name': 'USD - US Dollar (\$)'},
      {'code': 'EUR', 'name': 'EUR - Euro (€)'},
      {'code': 'GBP', 'name': 'GBP - British Pound (£)'},
      {'code': 'JPY', 'name': 'JPY - Japanese Yen (¥)'},
      {'code': 'CAD', 'name': 'CAD - Canadian Dollar (C\$)'},
      {'code': 'AUD', 'name': 'AUD - Australian Dollar (A\$)'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Default Units',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the default currency for tracking channel transaction valuations, ad placements, and premium tips.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'Currency',
          value: activeCurrency,
          items: currencies.map((c) => DropdownMenuItem(value: c['code'], child: Text(c['name']!))).toList(),
          onChanged: (val) {
            if (val != null) {
              controller.updateField('defaultCurrency', val);
              controller.showSuccess('Default currency updated to $val');
            }
          },
        ),
      ],
    );
  }

  // ===== CHANNEL TAB =====
  Widget _buildChannelTab(StudioSettingsController controller) {
    final country = controller.userData['countryOfResidence'] ?? 'United States';
    final madeForKids = controller.userData['madeForKids'] ?? 'no_kids';
    final googleAdsLinked = controller.userData['googleAdsLinked'] ?? false;
    final autoCaptions = controller.userData['autoCaptionsDontShowInappropriate'] ?? true;
    final showSubs = controller.userData['showSubscriberCount'] ?? true;

    final keywords = List<String>.from(controller.userData['channelKeywords'] ?? []);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            dividerColor: Colors.white10,
            indicatorColor: AppColors.brand,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Basic Info'),
              Tab(text: 'Advanced Settings'),
              Tab(text: 'Feature Eligibility'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 480,
            child: TabBarView(
              children: [
                // 1. Basic Info
                ListView(
                  children: [
                    _buildDropdownField(
                      label: 'Country of Residence',
                      value: country,
                      items: const [
                        DropdownMenuItem(value: 'United States', child: Text('United States')),
                        DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom')),
                        DropdownMenuItem(value: 'Canada', child: Text('Canada')),
                        DropdownMenuItem(value: 'Germany', child: Text('Germany')),
                        DropdownMenuItem(value: 'Japan', child: Text('Japan')),
                        DropdownMenuItem(value: 'Australia', child: Text('Australia')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('countryOfResidence', val);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Keywords', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Add descriptive keywords to help viewers discover your channel, content focus, and niche.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    _TagEditor(
                      tags: keywords,
                      hint: 'Enter keyword and tap (+)',
                      onChanged: (tags) => controller.updateField('channelKeywords', tags),
                    ),
                  ],
                ),
                // 2. Advanced Settings
                ListView(
                  children: [
                    _AudienceSelector(
                      currentValue: madeForKids,
                      onChanged: (val) => controller.updateField('madeForKids', val),
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text('Google Ads Account Linking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    _buildToggleTile(
                      title: 'Link Google Ads ID',
                      subtitle: 'Share channel metrics with your configured Google Ads account to launch targeted video promotional campaigns.',
                      value: googleAdsLinked,
                      onChanged: (val) => controller.updateField('googleAdsLinked', val),
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text('Miscellaneous Rules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    _buildToggleTile(
                      title: 'Filter potential inappropriate words',
                      subtitle: 'Do not show inappropriate words in automatically generated caption overlays.',
                      value: autoCaptions,
                      onChanged: (val) => controller.updateField('autoCaptionsDontShowInappropriate', val),
                    ),
                    _buildToggleTile(
                      title: 'Show subscriber count',
                      subtitle: 'Display the total number of users subscribed to your channel publicly.',
                      value: showSubs,
                      onChanged: (val) => controller.updateField('showSubscriberCount', val),
                    ),
                  ],
                ),
                // 3. Feature Eligibility
                ListView(
                  children: [
                    const Text('Feature Statuses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Track system privileges, verifications, and channel capacity multipliers below.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    const _EligibilitySection(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== UPLOAD DEFAULTS TAB =====
  Widget _buildUploadDefaultsTab(StudioSettingsController controller) {
    final title = controller.userData['defaultUploadTitle'] ?? '';
    final desc = controller.userData['defaultUploadDescription'] ?? '';
    final vis = controller.userData['defaultUploadVisibility'] ?? 'public';
    final license = controller.userData['defaultUploadLicense'] ?? 'standard';
    final category = controller.userData['defaultUploadCategory'] ?? 'People & Blogs';
    final language = controller.userData['defaultUploadLanguage'] ?? 'English';
    final capCert = controller.userData['defaultUploadCaptionCertification'] ?? 'None';
    final commentVis = controller.userData['defaultUploadCommentsVisibility'] ?? 'hold_inappropriate';

    final tags = List<String>.from(controller.userData['defaultUploadTags'] ?? []);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            dividerColor: Colors.white10,
            indicatorColor: AppColors.brand,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Basic Info'),
              Tab(text: 'Advanced Settings'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 480,
            child: TabBarView(
              children: [
                // 1. Basic Info
                ListView(
                  children: [
                    _buildTextField(
                      label: 'Default Title',
                      value: title,
                      onChanged: (val) => controller.updateField('defaultUploadTitle', val),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Default Description',
                      value: desc,
                      maxLines: 4,
                      onChanged: (val) => controller.updateField('defaultUploadDescription', val),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Default Visibility',
                      value: vis,
                      items: const [
                        DropdownMenuItem(value: 'public', child: Text('Public')),
                        DropdownMenuItem(value: 'unlisted', child: Text('Unlisted')),
                        DropdownMenuItem(value: 'private', child: Text('Private')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('defaultUploadVisibility', val);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Preset Upload Tags', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Define default keywords added to all newly uploaded videos to save publishing time.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    _TagEditor(
                      tags: tags,
                      hint: 'Enter default tag and tap (+)',
                      onChanged: (newTags) => controller.updateField('defaultUploadTags', newTags),
                    ),
                  ],
                ),
                // 2. Advanced Settings
                ListView(
                  children: [
                    _buildDropdownField(
                      label: 'License',
                      value: license,
                      items: const [
                        DropdownMenuItem(value: 'standard', child: Text('Standard Truthworld License')),
                        DropdownMenuItem(value: 'creative_commons', child: Text('Creative Commons - Attribution')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('defaultUploadLicense', val);
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField(
                      label: 'Category',
                      value: category,
                      items: const [
                        DropdownMenuItem(value: 'People & Blogs', child: Text('People & Blogs')),
                        DropdownMenuItem(value: 'Gaming', child: Text('Gaming')),
                        DropdownMenuItem(value: 'Education', child: Text('Education')),
                        DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                        DropdownMenuItem(value: 'Science & Technology', child: Text('Science & Technology')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('defaultUploadCategory', val);
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField(
                      label: 'Video Language',
                      value: language,
                      items: const [
                        DropdownMenuItem(value: 'English', child: Text('English')),
                        DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                        DropdownMenuItem(value: 'German', child: Text('German')),
                        DropdownMenuItem(value: 'Japanese', child: Text('Japanese')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('defaultUploadLanguage', val);
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField(
                      label: 'Caption Certification',
                      value: capCert,
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('None')),
                        DropdownMenuItem(value: 'US Television', child: Text('This content has never aired on US television')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('defaultUploadCaptionCertification', val);
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdownField(
                      label: 'Comment Settings',
                      value: commentVis,
                      items: const [
                        DropdownMenuItem(value: 'allow_all', child: Text('Allow all comments')),
                        DropdownMenuItem(value: 'hold_inappropriate', child: Text('Hold potentially inappropriate comments for review')),
                        DropdownMenuItem(value: 'hold_all', child: Text('Hold all comments for review')),
                        DropdownMenuItem(value: 'disable', child: Text('Disable comments')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.updateField('defaultUploadCommentsVisibility', val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== PERMISSIONS TAB =====
  Widget _buildPermissionsTab(StudioSettingsController controller) {
    return _PermissionsTable(controller: controller);
  }

  // ===== COMMUNITY TAB =====
  Widget _buildCommunityTab(StudioSettingsController controller) {
    final blockLinks = controller.userData['blockLinks'] ?? false;
    final allowComments = controller.userData['allowChannelComments'] ?? true;

    final moderators = List<String>.from(controller.userData['moderators'] ?? []);
    final approvedUsers = List<String>.from(controller.userData['approvedUsers'] ?? []);
    final blockedWords = List<String>.from(controller.userData['blockedWords'] ?? []);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            dividerColor: Colors.white10,
            indicatorColor: AppColors.brand,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Automated Filters'),
              Tab(text: 'Default Settings'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 480,
            child: TabBarView(
              children: [
                // 1. Automated Filters
                ListView(
                  children: [
                    const Text('Moderators', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Configure community users that can review comments, pin items, and manage chat filters.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    _TagEditor(
                      tags: moderators,
                      hint: 'Add moderator handle and (+)',
                      onChanged: (mods) => controller.updateField('moderators', mods),
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text('Approved Users', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Comments from these users are automatically approved and bypass automated review filters.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    _TagEditor(
                      tags: approvedUsers,
                      hint: 'Add approved user handle and (+)',
                      onChanged: (users) => controller.updateField('approvedUsers', users),
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text('Blocked Words', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Comments containing or matching these words are held for review automatically.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    _TagEditor(
                      tags: blockedWords,
                      hint: 'Add blocked word and (+)',
                      onChanged: (words) => controller.updateField('blockedWords', words),
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    _buildToggleTile(
                      title: 'Block Links',
                      subtitle: 'New comments containing urls, links, or live redirect requests will be held for review.',
                      value: blockLinks,
                      onChanged: (val) => controller.updateField('blockLinks', val),
                    ),
                  ],
                ),
                // 2. Default Settings
                ListView(
                  children: [
                    const Text('Comments on your new videos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    _buildToggleTile(
                      title: 'Allow comments on new videos',
                      subtitle: 'Toggle global visibility of comment feedback on newly published video elements.',
                      value: allowComments,
                      onChanged: (val) => controller.updateField('allowChannelComments', val),
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    const Text('Platform Redirect Guidelines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text(
                      'By publishing videos on Truthworld, you agree to follow absolute truth community standards. Violators of community guidelines will receive warning notices, and continuous violations will trigger channel suspension.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== DEMOGRAPHICS TAB =====
  Widget _buildDemographicsTab(StudioSettingsController controller) {
    final gender = controller.userData['demographicGender'] ?? 'Not specified';
    final ethnicity = controller.userData['demographicEthnicity'] ?? 'Not specified';
    final focus = controller.userData['demographicFocus'] ?? 'Not specified';

    return ListView(
      children: [
        const Text(
          'Inclusivity & Analytics Demographics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'This voluntary survey helps Truthworld measure creator diversity, represent multiple perspectives, and guarantee absolute equity. Your data is privately encapsulated and strictly aggregated anonymously.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        _buildDropdownField(
          label: 'Gender Identity',
          value: gender,
          items: const [
            DropdownMenuItem(value: 'Not specified', child: Text('Prefer not to answer')),
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary / Other')),
          ],
          onChanged: (val) {
            if (val != null) controller.updateField('demographicGender', val);
          },
        ),
        const SizedBox(height: 14),
        _buildDropdownField(
          label: 'Race & Ethnicity',
          value: ethnicity,
          items: const [
            DropdownMenuItem(value: 'Not specified', child: Text('Prefer not to answer')),
            DropdownMenuItem(value: 'White / Caucasian', child: Text('White / Caucasian')),
            DropdownMenuItem(value: 'Black / African American', child: Text('Black / African American')),
            DropdownMenuItem(value: 'Asian', child: Text('Asian')),
            DropdownMenuItem(value: 'Hispanic / Latino', child: Text('Hispanic / Latino')),
            DropdownMenuItem(value: 'Other / Mixed', child: Text('Other / Mixed')),
          ],
          onChanged: (val) {
            if (val != null) controller.updateField('demographicEthnicity', val);
          },
        ),
        const SizedBox(height: 14),
        _buildDropdownField(
          label: 'Primary Content Segment',
          value: focus,
          items: const [
            DropdownMenuItem(value: 'Not specified', child: Text('Mixed Content')),
            DropdownMenuItem(value: 'News & Politics', child: Text('News & Politics')),
            DropdownMenuItem(value: 'Science & Education', child: Text('Science & Education')),
            DropdownMenuItem(value: 'Gaming & Interactive', child: Text('Gaming & Interactive')),
            DropdownMenuItem(value: 'Creative Art & Music', child: Text('Creative Art & Music')),
          ],
          onChanged: (val) {
            if (val != null) controller.updateField('demographicFocus', val);
          },
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            controller.showSuccess('Demographics survey saved! Thank you.');
          },
          child: const Text('SUBMIT RESPONSES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ===== AGREEMENTS TAB =====
  Widget _buildAgreementsTab(StudioSettingsController controller) {
    final partner = controller.userData['agreementsPartnerProgram'] ?? true;
    final licensing = controller.userData['agreementsContentLicensing'] ?? true;

    return ListView(
      children: [
        const Text(
          'Agreements and Licensing Terms',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'All creators must keep active agreements and abide by licensing frameworks to broadcast on Truthworld.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildAgreementCard(
          title: 'Truthworld Partner Program Agreement',
          description: 'Defines payout structures, advertisement rules, subscription options, guidelines, and responsibilities of partner channels.',
          value: partner,
          onChanged: (val) => controller.updateField('agreementsPartnerProgram', val),
        ),
        const SizedBox(height: 14),
        _buildAgreementCard(
          title: 'Commercial Content Licensing Agreement',
          description: 'Governs broad distribution rights, copyright dispute guidelines, platform playback options, and regional compliance factors.',
          value: licensing,
          onChanged: (val) => controller.updateField('agreementsContentLicensing', val),
        ),
      ],
    );
  }

  Widget _buildAgreementCard({
    required String title,
    required String description,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.dialog(
                    AlertDialog(
                      backgroundColor: AppColors.bgSurface,
                      title: Text(title, style: const TextStyle(color: Colors.white)),
                      content: SingleChildScrollView(
                        child: Text(
                          'Full terms of $title.\n\nBy checking this agreement, you represent that you are at least 18 years of age or the age of legal majority in your country of residence, and you consent to conform strictly to community standards, legal conditions, copyright claims verifications, and distribution bounds specified by Truthworld.',
                          style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('CLOSE'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('VIEW AGREEMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              Checkbox(
                value: value,
                activeColor: AppColors.brand,
                onChanged: (val) {
                  if (val != null) {
                    HapticFeedback.lightImpact();
                    onChanged(val);
                  }
                },
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'I agree to the terms and licensing guidelines specified in the agreement.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // INPUT FIELD HELPER WIDGETS
  // ==========================================
  Widget _buildTextField({
    required String label,
    required String value,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      onFieldSubmitted: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF333333)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.brand.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AppColors.bgSurface,
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: items,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ),
      value: value,
      onChanged: (val) {
        HapticFeedback.lightImpact();
        onChanged(val);
      },
      activeTrackColor: AppColors.brand,
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ==========================================
// MOBILE FULLSCREEN SUB-PAGE
// ==========================================
class _MobileSettingsSubPage extends StatelessWidget {
  final String title;
  final int tabIndex;
  final StudioSettingsController controller;

  const _MobileSettingsSubPage({
    required this.title,
    required this.tabIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgInput,
        title: Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Get.back();
          },
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: StudioSettingsPage()._buildTabContent(tabIndex, controller),
      ),
    );
  }
}

// ==========================================
// CUSTOM TAG CHIPS EDITOR
// ==========================================
class _TagEditor extends StatefulWidget {
  final List<String> tags;
  final String hint;
  final Function(List<String>) onChanged;

  const _TagEditor({
    required this.tags,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  final TextEditingController _textController = TextEditingController();

  void _addTag(String value) {
    final clean = value.trim();
    if (clean.isNotEmpty && !widget.tags.contains(clean)) {
      final updated = List<String>.from(widget.tags)..add(clean);
      widget.onChanged(updated);
      HapticFeedback.lightImpact();
    }
    _textController.clear();
  }

  void _removeTag(String tag) {
    final updated = List<String>.from(widget.tags)..remove(tag);
    widget.onChanged(updated);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.brand),
              onPressed: () => _addTag(_textController.text),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF333333)),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.brand),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: _addTag,
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.brandContainer.withValues(alpha: 0.5),
                deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                onDeleted: () => _removeTag(tag),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0x339B30FF)),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ==========================================
// AUDIENCE RESTRICTIONS RADIOS
// ==========================================
class _AudienceSelector extends StatelessWidget {
  final String currentValue;
  final Function(String) onChanged;

  const _AudienceSelector({required this.currentValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Do you want to set your channel as made for kids?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Regardless of your location, you’re legally required to comply with the Children’s Online Privacy Protection Act (COPPA) and/or other laws. You’re required to tell us if your videos are made for kids.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          value: 'yes_kids',
          title: 'Yes, set this channel as made for kids.',
          subtitle: 'I always upload content that’s designed specifically for children. Features like personalized ads and comments will be disabled.',
        ),
        const SizedBox(height: 8),
        _buildOptionCard(
          value: 'no_kids',
          title: 'No, set this channel as not made for kids.',
          subtitle: 'I never upload content that’s designed for children. My content is tailored for mature audiences.',
        ),
        const SizedBox(height: 8),
        _buildOptionCard(
          value: 'review_every_video',
          title: 'I want to review this setting for every single video.',
          subtitle: 'Choose this option if your content is mixed and you’d prefer to categorize each video upload individually.',
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = currentValue == value;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(value);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandContainer.withValues(alpha: 0.2) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brand : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brand,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FEATURE ELIGIBILITY STEPPERS
// ==========================================
class _EligibilitySection extends StatelessWidget {
  const _EligibilitySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildEligibilityCard(
          title: 'Standard features',
          subtitle: 'Upload videos, create playlists, and add collaborators or new videos to playlists.',
          status: 'Enabled',
          statusColor: AppColors.success,
          requirements: 'Standard video size checks and normal activity.',
        ),
        const SizedBox(height: 12),
        _buildEligibilityCard(
          title: 'Intermediate features',
          subtitle: 'Videos longer than 15 minutes, custom thumbnails, and live streaming.',
          status: 'Eligible',
          statusColor: AppColors.textLink,
          requirements: 'Verify phone number.',
          isActionable: true,
          actionText: 'VERIFY PHONE',
        ),
        const SizedBox(height: 12),
        _buildEligibilityCard(
          title: 'Advanced features',
          subtitle: 'Increase daily uploads and live streams, create clips, and embed links in descriptions.',
          status: 'Locked',
          statusColor: AppColors.error,
          requirements: 'Complete advanced identity verification.',
        ),
      ],
    );
  }

  Widget _buildEligibilityCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String requirements,
    bool isActionable = false,
    String? actionText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requirements: $requirements',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActionable && actionText != null)
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Get.snackbar(
                      'Verification',
                      'Phone verification flow launched!',
                      backgroundColor: AppColors.brandContainer,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// INVITE COLLABORATOR DIALOG
// ==========================================
class _InviteDialog extends StatefulWidget {
  final Function(String email, String role) onInvite;

  const _InviteDialog({required this.onInvite});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _emailController = TextEditingController();
  String _selectedRole = 'editor';
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invite User',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Grant permissions to access or manage your creator channel features.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.brand),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorStyle: const TextStyle(color: AppColors.error),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Email is required';
                  if (!GetUtils.isEmail(value.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    dropdownColor: AppColors.bgSurface,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'manager', child: Text('Manager (Edit, upload, manage permissions)')),
                      DropdownMenuItem(value: 'editor', child: Text('Editor (Edit and upload metadata)')),
                      DropdownMenuItem(value: 'subtitle_editor', child: Text('Subtitle Editor (Manage video captions)')),
                      DropdownMenuItem(value: 'viewer', child: Text('Viewer (Read-only access)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRole = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onInvite(_emailController.text.trim(), _selectedRole);
                        Get.back();
                      }
                    },
                    child: const Text('Send Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PERMISSIONS DATATABLE WIDGET
// ==========================================
class _PermissionsTable extends StatelessWidget {
  final StudioSettingsController controller;

  const _PermissionsTable({required this.controller});

  @override
  Widget build(BuildContext context) {
    final userEmail = controller.userData['email'] ?? 'owner@truthworld.com';
    final userName = controller.userData['displayName'] ?? 'Channel Owner';

    final permissions = [
      {'name': userName, 'email': userEmail, 'role': 'owner'},
      {'name': 'Alex Johnson', 'email': 'alex@truthworld.com', 'role': 'editor'},
      {'name': 'Sarah Parker', 'email': 'sarah@truthworld.com', 'role': 'subtitle_editor'},
      {'name': 'David Miller', 'email': 'david@truthworld.com', 'role': 'viewer'},
    ];

    final invited = controller.userData['invitedUsers'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Manage Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
              label: const Text('Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Get.dialog(
                  _InviteDialog(
                    onInvite: (email, role) {
                      final updatedList = List<Map<String, dynamic>>.from(
                          invited.map((item) => Map<String, dynamic>.from(item as Map)));
                      updatedList.add({
                        'email': email,
                        'role': role,
                        'status': 'pending',
                        'invitedAt': DateTime.now().toIso8601String(),
                      });
                      controller.updateField('invitedUsers', updatedList);
                      controller.showSuccess('Invitation sent to $email!');
                    },
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('User', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
                  ),
                ],
              ),
              ...permissions.map((p) {
                return TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(p['name']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(p['email']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: _buildRoleBadge(p['role']!),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        if (invited.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Pending Invitations',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          ...invited.map((inv) {
            final map = inv as Map;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, color: AppColors.brand, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(map['email'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Role: ${map['role']} • Invited recently', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Pending', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final updated = List.from(invited)..remove(inv);
                      controller.updateField('invitedUsers', updated);
                      controller.showWarning('Invitation cancelled.');
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = AppColors.textTertiary;
    String label = role.toUpperCase();
    if (role == 'owner') {
      color = AppColors.brand;
    } else if (role == 'editor') {
      color = AppColors.success;
    } else if (role == 'subtitle_editor') {
      color = AppColors.textLink;
    } else if (role == 'viewer') {
      color = AppColors.textSecondary;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
