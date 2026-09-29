import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Controller managing evidence source submission for fact-checking claims.
class ClaimSourceSubmissionController extends BaseController
    with ContentValidationMixin {
  ClaimSourceSubmissionController({
    required this.video,
    this.claims = const [],
    this.initialClaim,
  });

  final Video video;
  final List<dynamic> claims;
  final Map<dynamic, dynamic>? initialClaim;

  late final TextEditingController urlController;
  late final TextEditingController titleController;
  late final TextEditingController noteController;

  late final RxString selectedTarget;
  final RxBool isSubmitting = false.obs;

  bool get isPremiumUser =>
      Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value;

  bool get isChannelOwner =>
      Get.isRegistered<AuthService>() &&
      AuthService.to.user?.uid != null &&
      (AuthService.to.user!.uid == video.ownerId ||
          AuthService.to.user!.uid == video.channelId);

  bool get isEligible => isPremiumUser || isChannelOwner;

  @override
  void onInit() {
    super.onInit();
    urlController = trackTextController(TextEditingController());
    titleController = trackTextController(TextEditingController());
    noteController = trackTextController(TextEditingController());

    if (initialClaim != null) {
      selectedTarget =
          (initialClaim!['claim'] ?? initialClaim!['text'] ?? '')
              .toString()
              .obs;
    } else {
      selectedTarget = 'Entire Video'.obs;
    }
  }

  bool validateForm() {
    final url = urlController.text.trim();
    if (!SourceUrlSanitizer.isValidSourceUrl(url)) {
      return false;
    }
    final title = titleController.text.trim();
    if (title.isNotEmpty) {
      final v = ContentValidator.validate(
        title,
        fieldName: 'Source Title',
        maxLength: 200,
      );
      if (!v.isValid) return false;
    }
    final note = noteController.text.trim();
    if (note.isNotEmpty) {
      final v = ContentValidator.validate(
        note,
        fieldName: 'Citation Note',
        maxLength: 1000,
      );
      if (!v.isValid) return false;
    }
    return true;
  }

  void resetForm() {
    urlController.clear();
    titleController.clear();
    noteController.clear();
    isSubmitting.value = false;
  }

  Future<void> submitSource(BuildContext context) async {
    final url = urlController.text.trim();
    final urlValidation = SourceUrlSanitizer.validateAuthoritativeSource(url);
    if (!urlValidation.isValid) {
      AppSnackbar.warning(
        urlValidation.errorMessage ??
            'Please enter a valid HTTP/HTTPS source link.',
      );
      return;
    }
    final normalizedUrl = urlValidation.normalizedUrl!;

    final title = titleController.text.trim();
    if (title.isNotEmpty) {
      final v = ContentValidator.validate(
        title,
        fieldName: 'Source Title',
        maxLength: 200,
      );
      if (!v.isValid) {
        AppSnackbar.warning(v.message);
        return;
      }
    }

    final note = noteController.text.trim();
    if (note.isNotEmpty) {
      final v = ContentValidator.validate(
        note,
        fieldName: 'Citation Note',
        maxLength: 1000,
      );
      if (!v.isValid) {
        AppSnackbar.warning(v.message);
        return;
      }
    }

    isSubmitting.value = true;

    try {
      final user = Get.isRegistered<AuthService>() ? AuthService.to.user : null;
      final firestore = FirebaseFirestore.instance;

      final sourceData = <String, dynamic>{
        'videoId': video.id,
        'target': selectedTarget.value,
        'url': normalizedUrl,
        'title': titleController.text.trim(),
        'note': noteController.text.trim(),
        'submittedBy': user?.uid,
        'submittedByEmail': user?.email,
        'submittedByName': user?.displayName ?? 'Anonymous User',
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending_review',
      };

      await firestore.collection('claim_sources').add(sourceData);

      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackbar.success(
          'Thank you! Your supporting evidence has been submitted for credibility review.',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      if (context.mounted) {
        isSubmitting.value = false;
        AppSnackbar.error('Unable to submit source. Please try again.');
      }
    }
  }
}
