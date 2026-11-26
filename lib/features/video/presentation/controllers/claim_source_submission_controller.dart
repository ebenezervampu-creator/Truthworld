import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/credibility_governance_service.dart';

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
  final RxBool isAppealMode = false.obs;

  bool get isPremiumUser =>
      Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value;

  bool get isChannelOwner =>
      Get.isRegistered<AuthService>() &&
      AuthService.to.user?.uid != null &&
      (AuthService.to.user!.uid == video.ownerId ||
          AuthService.to.user!.uid == video.channelId);

  bool get isEligible => isPremiumUser || isChannelOwner;

  void setAppealMode(bool appeal) {
    isAppealMode.value = appeal;
    update();
  }

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
      if (user == null) {
        AppSnackbar.warning('Please sign in to submit supporting evidence.');
        isSubmitting.value = false;
        return;
      }

      // The submission is recorded once, server-side, in the evidence review queue
      // (validation, daily limit, reviewer approval). The app no longer writes its own
      // unvalidated copy to `claim_sources`.
      final target = _resolveTargetClaim();
      final reasonText = note.isNotEmpty
          ? note
          : (title.isNotEmpty
              ? title
              : 'Community supporting source: $normalizedUrl');
      final result = await CredibilityGovernanceService.submitFactualDispute(
        videoId: video.id,
        reason: reasonText,
        additionalSources: [normalizedUrl],
        claimId: target.claimId,
        claimText: target.claimText,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        final message = result['message'];
        AppSnackbar.success(
          message is String && message.trim().isNotEmpty
              ? message
              : 'Thanks! Your source is queued for review. If a reviewer approves it, the claim will be re-checked with your evidence.',
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

  /// Resolves the claim the user selected so the server can re-check exactly that claim.
  ({String? claimId, String? claimText}) _resolveTargetClaim() {
    final targetText = selectedTarget.value.trim();
    if (targetText.isEmpty || targetText == 'Entire Video') {
      return (claimId: null, claimText: null);
    }
    String? idOf(dynamic c) {
      if (c is! Map) return null;
      final id = c['claimId'] ?? c['id'];
      return id is String && id.isNotEmpty ? id : null;
    }
    String textOf(dynamic c) =>
        c is Map ? (c['claim'] ?? c['text'] ?? '').toString().trim() : '';

    if (initialClaim != null && textOf(initialClaim) == targetText) {
      return (claimId: idOf(initialClaim), claimText: targetText);
    }
    for (final c in claims) {
      if (textOf(c) == targetText) {
        return (claimId: idOf(c), claimText: targetText);
      }
    }
    return (claimId: null, claimText: targetText);
  }

  /// Submits a formal appeal to the Independent Fact-Check Appeals Desk.
  Future<void> submitFormalAppeal(BuildContext context) async {
    if (!isChannelOwner) {
      AppSnackbar.warning('Only the channel creator may file a formal editorial appeal.');
      return;
    }

    final note = noteController.text.trim();
    if (note.length < 10) {
      AppSnackbar.warning('Please provide a substantive rationale (at least 10 characters) for your appeal.');
      return;
    }

    final url = urlController.text.trim();
    String? normalizedUrl;
    if (url.isNotEmpty) {
      final urlValidation = SourceUrlSanitizer.validateAuthoritativeSource(url);
      if (!urlValidation.isValid) {
        AppSnackbar.warning(urlValidation.errorMessage ?? 'Please enter a valid supporting link.');
        return;
      }
      normalizedUrl = urlValidation.normalizedUrl;
    }

    isSubmitting.value = true;
    try {
      final user = Get.isRegistered<AuthService>() ? AuthService.to.user : null;
      if (user == null) {
        AppSnackbar.warning('Please sign in to file an editorial appeal.');
        isSubmitting.value = false;
        return;
      }

      final claimId = (initialClaim?['claimId'] ?? initialClaim?['id'] ?? 'claim_${DateTime.now().millisecondsSinceEpoch}').toString();
      final claimText = selectedTarget.value;
      final originalVerdict = (initialClaim?['verdict'] ?? initialClaim?['status'] ?? 'disputed').toString();

      final evidenceUrls = normalizedUrl != null ? [normalizedUrl] : <String>[];
      await CredibilityGovernanceService.submitClaimAppeal(
        videoId: video.id,
        claimId: claimId,
        claimText: claimText,
        originalVerdict: originalVerdict,
        creatorRationale: note,
        evidenceUrls: evidenceUrls,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackbar.success(
          'Your appeal has been escalated to the Independent Fact-Check Appeals Desk.',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      if (context.mounted) {
        isSubmitting.value = false;
        AppSnackbar.error('Unable to submit appeal. Please try again.');
      }
    }
  }
}
