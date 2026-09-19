import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics/revenue_analytics_state_base.dart';

/// Mixin handling creator KYC document upload, verification data collection, and batch submissions.
mixin RevenueAnalyticsKycMixin on RevenueAnalyticsStateBase {
  /// Uploads a private KYC image document to Firebase Storage (/kyc_documents/{userId}/).
  Future<String> uploadKycDocumentFile({
    required Uint8List bytes,
    required String filePrefix,
    required String uid,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'kyc_documents/$uid/${filePrefix}_$timestamp.jpg';
    final ref = storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploaderId': uid,
        'userId': uid,
        'category': 'kyc_document',
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final task = ref.putData(bytes, metadata);
    final snapshot = await task.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  /// Submits creator PAN details, identity proof photos, and bank account name verification.
  Future<bool> submitKycVerification({
    required String panNumber,
    required String panLegalName,
    required DateTime dateOfBirth,
    required Uint8List panImageBytes,
    required IdentityProofType idProofType,
    required String idProofNumber,
    required Uint8List idFrontImageBytes,
    Uint8List? idBackImageBytes,
  }) async {
    final cleanPan = panNumber.trim().toUpperCase();
    final cleanPanName = panLegalName.trim();
    final cleanIdNumber = idProofNumber.trim();

    if (!CreatorKycVerification.isValidPan(cleanPan)) {
      AppSnackbar.warning(
        'Please enter a valid 10-character Indian PAN number (e.g. ABCDE1234F).',
      );
      return false;
    }

    if (cleanPanName.isEmpty) {
      AppSnackbar.warning(
        'Please enter your Legal Name exactly as printed on your PAN card.',
      );
      return false;
    }

    if (!CreatorKycVerification.isValidAge(dateOfBirth)) {
      AppSnackbar.warning(
        'You must be at least 18 years of age to submit creator KYC verification.',
      );
      return false;
    }

    if (cleanIdNumber.isEmpty) {
      AppSnackbar.warning(
        'Please enter your ${idProofType.displayName} number.',
      );
      return false;
    }

    // Check bank account matching if linked
    final bankName = savedBankAccount.value?.accountHolderName ?? '';
    final nameScore = bankName.isNotEmpty
        ? CreatorKycVerification.calculateNameMatchScore(bankName, cleanPanName)
        : 1.0;

    if (bankName.isNotEmpty && nameScore < 0.40) {
      AppSnackbar.warning(
        'Name mismatch warning: The name on your PAN card ($cleanPanName) does not match your linked bank account holder name ($bankName). Please ensure both accounts belong to the same individual.',
      );
      return false;
    }

    try {
      isSubmittingKyc.value = true;
      kycUploadProgress.value = 0.1;

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final chId = channelId.value;

      // 1. Upload PAN Card Image
      kycUploadProgress.value = 0.25;
      final panUrl = await uploadKycDocumentFile(
        bytes: panImageBytes,
        filePrefix: 'pan_${chId.replaceAll('/', '_')}',
        uid: uid,
      );

      // 2. Upload ID Proof Front Image
      kycUploadProgress.value = 0.55;
      final idFrontUrl = await uploadKycDocumentFile(
        bytes: idFrontImageBytes,
        filePrefix: 'id_front_${chId.replaceAll('/', '_')}',
        uid: uid,
      );

      // 3. Upload ID Proof Back Image (if provided)
      String? idBackUrl;
      if (idBackImageBytes != null && idBackImageBytes.isNotEmpty) {
        kycUploadProgress.value = 0.80;
        idBackUrl = await uploadKycDocumentFile(
          bytes: idBackImageBytes,
          filePrefix: 'id_back_${chId.replaceAll('/', '_')}',
          uid: uid,
        );
      }

      kycUploadProgress.value = 0.90;

      // 4. Create KYC Verification Object
      final kycRecord = CreatorKycVerification(
        channelId: chId,
        userId: uid,
        status: KycStatus.pending,
        panNumber: cleanPan,
        panLegalName: cleanPanName,
        dateOfBirth: dateOfBirth,
        panDocumentUrl: panUrl,
        identityProofType: idProofType,
        identityProofNumber: cleanIdNumber,
        identityProofFrontUrl: idFrontUrl,
        identityProofBackUrl: idBackUrl,
        bankAccountName: bankName,
        nameMatchScore: nameScore,
        isNameMatched: nameScore >= 0.70,
        submittedAt: DateTime.now(),
      );

      final batch = firestore.batch();

      // Write to channels/{chId}/kyc/verification
      final chKycRef = firestore
          .collection(FirestoreCollections.channels)
          .doc(chId)
          .collection('kyc')
          .doc('verification');
      batch.set(chKycRef, kycRecord.toMap(), SetOptions(merge: true));

      // Write to master creator_kyc/{chId}
      final masterKycRef = firestore.collection('creator_kyc').doc(chId);
      batch.set(masterKycRef, kycRecord.toMap(), SetOptions(merge: true));

      // Update channel doc kycStatus
      final chRef =
          firestore.collection(FirestoreCollections.channels).doc(chId);
      batch.set(chRef, {
        'kycStatus': 'pending',
        'kycSubmittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      // Update local state
      creatorKyc.value = kycRecord;
      channelKycStatus.value = 'pending';
      kycUploadProgress.value = 1.0;
      isSubmittingKyc.value = false;

      AppSnackbar.success(
        'KYC documents submitted successfully! Your PAN & Identity details are being verified.',
      );
      return true;
    } catch (e, stackTrace) {
      isSubmittingKyc.value = false;
      kycUploadProgress.value = 0.0;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsKycMixin.submitKycVerification',
      );
      AppSnackbar.error(
        'Unable to submit KYC documents. Please check your internet connection and try again.',
      );
      return false;
    }
  }
}
