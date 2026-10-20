import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

/// GetX View Controller managing UI state, inputs, dialogs, and validation
/// for the Channel Creation Wizard screen.
class ChannelWizardViewController extends GetxController {
  ChannelController get channelController {
    if (Get.isRegistered<ChannelController>()) {
      return Get.find<ChannelController>();
    }
    return Get.put(ChannelController());
  }

  // Local Controllers for Tag and Social Inputs
  final TextEditingController tagInputController = TextEditingController();
  final Map<String, TextEditingController> socialControllers = {};

  TextEditingController getSocialController(String key) {
    if (!socialControllers.containsKey(key)) {
      var initialText = channelController.socialLinks[key] ?? '';
      if (key == 'website' && initialText.isEmpty) {
        initialText = channelController.websiteUrl.text;
      } else if (key == 'email' && initialText.isEmpty) {
        initialText = channelController.contactEmail.text;
      }
      final ctrl = TextEditingController(text: initialText);
      ctrl.addListener(() {
        final val = ctrl.text.trim();
        if (val.isEmpty) {
          channelController.socialLinks.remove(key);
        } else {
          channelController.socialLinks[key] = val;
        }
        if (key == 'website') channelController.websiteUrl.text = val;
        if (key == 'email') channelController.contactEmail.text = val;
      });
      socialControllers[key] = ctrl;
    }
    return socialControllers[key]!;
  }

  // Reactive Tag Chip List
  final RxList<String> tagList = <String>[].obs;
  final RxString tagSearchQuery = ''.obs;
  String get tagQueryText => tagSearchQuery.value;

  final RxList<Map<String, dynamic>> liveFirestoreSuggestions =
      <Map<String, dynamic>>[].obs;
  final RxBool isSearchingTags = false.obs;
  final RxMap<String, int> realTagUsageMap = <String, int>{}.obs;

  // Mobile Accordion Expansion States
  final RxBool isChannelTypeExpanded = true.obs;
  final RxBool isCategoryExpanded = true.obs;
  final RxBool isLinksExpanded = true.obs;
  final RxBool isVisibilityExpanded = true.obs;
  final RxBool isCountryExpanded = true.obs;
  final RxBool isLanguageExpanded = true.obs;
  final RxBool isPlanExpanded = true.obs;
  final RxBool isAgreementsExpanded = true.obs;

  final RxBool draftDialogShown = false.obs;
  final RxBool isExiting = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeTagsAndSocials();
    checkExistingChannelAndRedirect();
  }

  void _initializeTagsAndSocials() {
    if (channelController.tags.text.trim().isNotEmpty) {
      final parsed = channelController.tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      tagList.assignAll(parsed);
    } else {
      tagList.clear();
      channelController.tags.text = '';
    }
  }

  void checkExistingChannelAndRedirect() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Get.isRegistered<AuthService>()) return;
      if (AuthService.to.hasChannel.value && AuthService.to.userChannel != null) {
        Get.offAllNamed('/studio', arguments: {
          'channel': AuthService.to.userChannel,
        });
        return;
      }
      final ch = await AuthService.to.ensureChannelLoaded();
      if (ch != null) {
        Get.offAllNamed('/studio', arguments: {
          'channel': ch,
        });
      }
    });
  }

  @override
  void onClose() {
    tagInputController.dispose();
    for (final ctrl in socialControllers.values) {
      ctrl.dispose();
    }
    super.onClose();
  }

  void addTag(String rawTag) {
    final clean = rawTag.trim().replaceAll(',', '');
    if (clean.isEmpty) return;
    if (tagList.length >= 5) {
      AppSnackbar.warning(
        'You can add up to 5 tags.',
        title: 'Tag Limit',
      );
      return;
    }
    if (!tagList.contains(clean)) {
      tagList.add(clean);
      channelController.tags.text = tagList.join(', ');
    }
    tagInputController.clear();
    tagSearchQuery.value = '';
  }

  void removeTag(String tag) {
    tagList.remove(tag);
    channelController.tags.text = tagList.join(', ');
  }

  Future<void> fetchRealMatchingTagsFromFirestore(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      liveFirestoreSuggestions.clear();
      isSearchingTags.value = false;
      return;
    }

    isSearchingTags.value = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.hashtags)
          .where('tagLowercase', isGreaterThanOrEqualTo: cleanQuery)
          .where('tagLowercase', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(8)
          .get();

      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        final name = data['name'] as String? ?? doc.id;
        final count = (data['usageCount'] as num?)?.toInt() ?? 1;
        realTagUsageMap[name] = count;
        return {
          'name': name,
          'usageCount': count,
        };
      }).toList();

      liveFirestoreSuggestions.assignAll(results);
    } on FirebaseException catch (e, stackTrace) {
      liveFirestoreSuggestions.clear();
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWizardViewController.tagSearch.firebase',
      );
    } catch (e, stackTrace) {
      liveFirestoreSuggestions.clear();
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWizardViewController.tagSearch',
      );
    } finally {
      isSearchingTags.value = false;
    }
  }

  String getTagUsageCountFormatted(String tag) {
    final count = realTagUsageMap[tag] ?? 1;
    if (count >= 1000000000) {
      final val = (count / 1000000000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}B';
    }
    if (count >= 1000000) {
      final val = (count / 1000000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}M';
    }
    if (count >= 1000) {
      final val = (count / 1000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}k';
    }
    return '$count';
  }

  void checkDraftAvailable(BuildContext context, bool isDarkMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<AuthService>()) return;
      if (channelController.hasDraft.value &&
          !draftDialogShown.value &&
          !AuthService.to.hasChannel.value) {
        draftDialogShown.value = true;
        showDraftAvailableDialog(context, isDarkMode);
      }
    });
  }

  void handleClose(BuildContext context, bool isDarkMode) {
    if (channelController.channelName.text.trim().isEmpty &&
        channelController.description.text.trim().isEmpty &&
        channelController.selectedCategories.isEmpty) {
      if (Navigator.of(context).canPop()) {
        Get.back();
      } else {
        _showSignOutOrExitDialog(context);
      }
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Save Draft?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Would you like to save a draft before exiting?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              isExiting.value = true;
              Get.back();
              if (Navigator.of(context).canPop()) {
                Get.back();
              } else {
                _showSignOutOrExitDialog(context);
              }
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () async {
              await channelController.saveDraft();
              isExiting.value = true;
              Get.back();
              if (Navigator.of(context).canPop()) {
                Get.back();
              } else {
                _showSignOutOrExitDialog(context);
              }
            },
            child: const Text('Save Draft', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSignOutOrExitDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Sign Out of Studio?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'A channel is required to use Creator Studio. Would you like to sign out or switch accounts?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await AuthService.to.signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void showDraftAvailableDialog(BuildContext context, bool isDarkMode) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Draft Available',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have a saved channel creation draft. Would you like to restore it?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              channelController.deleteDraft();
              Get.back();
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: Get.back,
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void showDeleteDraftDialog(BuildContext context, bool isDarkMode) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete Draft?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your saved draft? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              await channelController.deleteDraft();
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void validateAndSubmitChannel() {
    // Sync tags and social inputs from local controllers to ChannelController
    if (tagList.isNotEmpty) {
      channelController.tags.text = tagList.join(', ');
    }
    for (final entry in socialControllers.entries) {
      final val = entry.value.text.trim();
      if (val.isNotEmpty) {
        channelController.socialLinks[entry.key] = val;
      }
    }
    if (socialControllers.containsKey('website')) {
      channelController.websiteUrl.text = socialControllers['website']!.text.trim();
    }
    if (socialControllers.containsKey('email')) {
      channelController.contactEmail.text = socialControllers['email']!.text.trim();
    }

    // 1. Channel Banner
    if (channelController.bannerImageData.value == null &&
        channelController.bannerUrl.value.isEmpty) {
      AppSnackbar.warning('Please select and upload a Channel Banner image.');
      return;
    }

    if (channelController.bannerStatus.value == 'REJECTED') {
      AppSnackbar.warning(
        'Your banner was rejected: ${channelController.bannerStatusReason.value}. Please upload a different image.',
        title: 'Banner Rejected',
      );
      return;
    }

    // 2. Channel Avatar
    if (channelController.avatarImageData.value == null &&
        channelController.avatarUrl.value.isEmpty) {
      AppSnackbar.warning('Please select and upload a Channel Avatar image.');
      return;
    }

    if (channelController.avatarStatus.value == 'REJECTED') {
      AppSnackbar.warning(
        'Your avatar was rejected: ${channelController.avatarStatusReason.value}. Please upload a different image.',
        title: 'Avatar Rejected',
      );
      return;
    }

    // 3. Channel Name
    if (channelController.channelName.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter a Channel Name.');
      return;
    }

    if (channelController.channelNameAvailability.value == AvailabilityStatus.taken) {
      AppSnackbar.warning('The chosen channel name is already taken. Please choose another.');
      return;
    }

    // 4. Channel Handle
    if (channelController.customUrl.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter a Channel Handle.');
      return;
    }

    if (channelController.customUrlAvailability.value == AvailabilityStatus.taken) {
      AppSnackbar.warning('The chosen handle is already taken. Please select an available handle.');
      return;
    }

    if (channelController.customUrlAvailability.value == AvailabilityStatus.checking) {
      AppSnackbar.info('Verifying handle availability. Please wait a moment.');
      return;
    }

    // 5. Description
    if (channelController.description.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter a Channel Description.');
      return;
    }

    // 6. Tags (at least 1 required)
    final parsedTags = channelController.tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (parsedTags.isEmpty && tagList.isEmpty) {
      AppSnackbar.warning('Please add at least 1 Tag.');
      return;
    }

    // 7. Category (at least 1 required)
    if (channelController.selectedCategories.isEmpty &&
        (channelController.selectedCategory.value == null ||
            channelController.selectedCategory.value!.trim().isEmpty)) {
      AppSnackbar.warning('Please select at least 1 Category.');
      return;
    }

    // 8. Agreements
    if (!channelController.agreeTerms.value ||
        !channelController.agreeGuidelines.value) {
      AppSnackbar.warning(
          'Please agree to both Terms & Conditions and Community Guidelines.');
      return;
    }

    // 9. Plan Selection Default
    if (channelController.selectedPlan.value.isEmpty) {
      channelController.selectedPlan.value = 'standard';
    }
    channelController.planSelectionError.value = false;

    // 10. Organization / Company Custom Email Domain Check
    if (channelController.channelTypeCategory.value ==
        'Organization / Company') {
      final emailText = getSocialController('email').text.trim();
      if (emailText.isEmpty) {
        AppSnackbar.warning(
            'Please enter a custom business domain email (e.g. contact@yourcompany.com).');
        return;
      }
      if (!channelController.isCustomBusinessEmail(emailText)) {
        AppSnackbar.warning(
            'Please enter a custom business domain email. Free email services (@gmail.com, @yahoo.com) are not allowed for Organization / Company channels.');
        return;
      }
    }

    channelController.isAgreed.value = true;
    channelController.createChannel();
  }
}
