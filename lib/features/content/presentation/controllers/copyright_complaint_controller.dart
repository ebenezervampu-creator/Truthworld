import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// GetX controller for copyright infringement complaints (DMCA / Rule 75 Notice).
///
/// Inherits from [BaseController] to leverage standardized lifecycle tracking
/// and automatic disposal of [TextEditingController] instances via [trackTextController].
class CopyrightComplaintController extends BaseController {
  CopyrightComplaintController({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  // ── Form Key ─────────────────────────────────────────────────────────────
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // ── Tracked TextEditingControllers (Auto-disposed in onClose) ────────────
  late final TextEditingController nameController;
  late final TextEditingController orgController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController workTitleController;
  late final TextEditingController workUrlController;
  late final TextEditingController infringingUrlController;
  late final TextEditingController timestampsController;
  late final TextEditingController detailsController;
  late final TextEditingController signatureController;

  // ── Reactive State ───────────────────────────────────────────────────────
  final RxString claimantType = 'Copyright Owner'.obs;
  final RxString workType = 'Video'.obs;

  final RxBool declGoodFaith = false.obs;
  final RxBool declAccuracy = false.obs;
  final RxBool declForwarding = false.obs;
  final RxBool declLiability = false.obs;

  final RxBool isSubmitting = false.obs;
  final RxnString submittedComplaintId = RxnString();

  @override
  void onInit() {
    super.onInit();
    _initTextControllers();
    try {
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user?.email != null && user!.email!.isNotEmpty) {
          emailController.text = user.email!;
        }
        if (user?.displayName != null && user!.displayName!.isNotEmpty) {
          nameController.text = user.displayName!;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'CopyrightComplaintController.onInit',
      );
    }
    _handleRouteArguments();
  }

  void _initTextControllers() {
    nameController = trackTextController(TextEditingController());
    orgController = trackTextController(TextEditingController());
    emailController = trackTextController(TextEditingController());
    phoneController = trackTextController(TextEditingController());
    addressController = trackTextController(TextEditingController());
    workTitleController = trackTextController(TextEditingController());
    workUrlController = trackTextController(TextEditingController());
    infringingUrlController = trackTextController(TextEditingController());
    timestampsController = trackTextController(TextEditingController());
    detailsController = trackTextController(TextEditingController());
    signatureController = trackTextController(TextEditingController());
  }

  void _handleRouteArguments() {
    final args = Get.arguments;
    if (args is Map<String, dynamic>) {
      if (args['videoUrl'] != null) {
        infringingUrlController.text = args['videoUrl'].toString();
      } else if (args['videoId'] != null) {
        infringingUrlController.text =
            'https://truthworld.in/watch/${args['videoId']}';
      }
    }
  }

  // ── State Mutators ────────────────────────────────────────────────────────
  void setClaimantType(String value) {
    claimantType.value = value;
  }

  void setWorkType(String value) {
    workType.value = value;
  }

  void setDeclGoodFaith(bool value) {
    declGoodFaith.value = value;
  }

  void setDeclAccuracy(bool value) {
    declAccuracy.value = value;
  }

  void setDeclForwarding(bool value) {
    declForwarding.value = value;
  }

  void setDeclLiability(bool value) {
    declLiability.value = value;
  }

  // ── Submission Handler ────────────────────────────────────────────────────
  Future<void> submitComplaint() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.info(
        'You must be signed in with a TruthWorld account to submit a copyright complaint.',
        title: 'Sign In Required',
      );
      return;
    }

    if (!formKey.currentState!.validate()) {
      AppSnackbar.warning(
        'Please complete all required fields highlighted in the form.',
        title: 'Required Fields Missing',
      );
      return;
    }

    if (!declGoodFaith.value ||
        !declAccuracy.value ||
        !declForwarding.value ||
        !declLiability.value) {
      AppSnackbar.warning(
        'You must agree to all statutory legal declarations before submitting.',
        title: 'Declarations Required',
      );
      return;
    }

    final nameVal = ContentValidator.validate(nameController.text.trim(), fieldName: 'Full Legal Name');
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return;
    }

    final org = orgController.text.trim();
    if (org.isNotEmpty) {
      final orgVal = ContentValidator.validate(org, fieldName: 'Organization Name');
      if (!orgVal.isValid) {
        AppSnackbar.warning(orgVal.message);
        return;
      }
    }

    final workVal = ContentValidator.validate(workTitleController.text.trim(), fieldName: 'Original Work Title');
    if (!workVal.isValid) {
      AppSnackbar.warning(workVal.message);
      return;
    }

    final detailsVal = ContentValidator.validate(detailsController.text.trim(), fieldName: 'Infringement Details', minLength: 10, maxLength: 5000);
    if (!detailsVal.isValid) {
      AppSnackbar.warning(detailsVal.message);
      return;
    }

    final sigVal = ContentValidator.validate(signatureController.text.trim(), fieldName: 'Electronic Signature');
    if (!sigVal.isValid) {
      AppSnackbar.warning(sigVal.message);
      return;
    }

    isSubmitting.value = true;

    try {
      final now = DateTime.now();
      final complaintId =
          'CR-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';

      final complaintData = {
        'complaintId': complaintId,
        'userId': user.uid,
        'userEmail': user.email ?? emailController.text.trim(),
        'claimantType': claimantType.value,
        'claimantName': nameController.text.trim(),
        'claimantOrg': orgController.text.trim(),
        'claimantEmail': emailController.text.trim(),
        'claimantPhone': phoneController.text.trim(),
        'claimantAddress': addressController.text.trim(),
        'workType': workType.value,
        'workTitle': workTitleController.text.trim(),
        'workUrlOrRegistration': workUrlController.text.trim(),
        'infringingUrl': infringingUrlController.text.trim(),
        'infringingTimestamps': timestampsController.text.trim(),
        'details': detailsController.text.trim(),
        'electronicSignature': signatureController.text.trim(),
        'declarations': {
          'goodFaithBelief': declGoodFaith.value,
          'accuracyAndAuthority': declAccuracy.value,
          'forwardingNoticeConsent': declForwarding.value,
          'liabilityAcknowledgement': declLiability.value,
        },
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'operator': 'TowerVSP Services (OPC) Private Limited',
      };

      await _firestore
          .collection('copyright_complaints')
          .doc(complaintId)
          .set(complaintData);

      submittedComplaintId.value = complaintId;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to submit complaint. You may also email directly to copyright@truthworld.in.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }
}
