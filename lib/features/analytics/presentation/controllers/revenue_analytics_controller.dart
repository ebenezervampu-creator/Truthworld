import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';

/// Controller for Channel Revenue Analytics.
/// Real-time listener across authentic Firestore financial collections.
class RevenueAnalyticsController extends BaseController {
  static RevenueAnalyticsController get to {
    if (!Get.isRegistered<RevenueAnalyticsController>()) {
      return Get.put(RevenueAnalyticsController());
    }
    return Get.find<RevenueAnalyticsController>();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---------------------------------------------------------------------------
  // Minimum Withdrawal Configuration (100 Rupees Minimum)
  // ---------------------------------------------------------------------------
  static const double minimumWithdrawalAmount = 100.0;
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String minWithdrawalText = '₹100 (100 Rupees)';

  // ---------------------------------------------------------------------------
  // Reactive State
  // ---------------------------------------------------------------------------
  final RxString channelId = ''.obs;
  final RxString channelName = ''.obs;
  final RxBool rxIsLoading = true.obs;

  // Earnings Breakdown
  final RxDouble totalRevenue = 0.0.obs;
  final RxDouble membershipsRevenue = 0.0.obs;
  final RxDouble superchatRevenue = 0.0.obs;
  final RxDouble adsRevenue = 0.0.obs;
  final RxDouble watchTimeRevenue = 0.0.obs;

  // Bank Account & Direct Payout Arrangement
  final Rx<CreatorBankAccount?> savedBankAccount = Rx<CreatorBankAccount?>(null);
  final RxBool isLoadingBankAccount = false.obs;

  // Creator KYC Document Verification State
  final Rx<CreatorKycVerification?> creatorKyc = Rx<CreatorKycVerification?>(null);
  final RxString channelKycStatus = 'not_submitted'.obs;
  final RxBool isSubmittingKyc = false.obs;
  final RxDouble kycUploadProgress = 0.0.obs;

  bool get isKycVerified => channelKycStatus.value.toLowerCase() == 'verified';
  bool get isKycPending => channelKycStatus.value.toLowerCase() == 'pending';
  bool get isKycRejected => channelKycStatus.value.toLowerCase() == 'rejected';
  bool get isKycNotSubmitted =>
      channelKycStatus.value.toLowerCase() == 'not_submitted' ||
      channelKycStatus.value.isEmpty;

  // Withdrawal States
  final RxBool isSubmittingWithdrawal = false.obs;

  bool get canWithdraw => totalRevenue.value >= minimumWithdrawalAmount;
  double get remainingToWithdraw =>
      (minimumWithdrawalAmount - totalRevenue.value)
          .clamp(0.0, minimumWithdrawalAmount);
  double get withdrawalProgress =>
      (totalRevenue.value / minimumWithdrawalAmount).clamp(0.0, 1.0);

  // Auxiliary Metrics
  final RxInt activeMembersCount = 0.obs;
  final RxInt activeTiersCount = 0.obs;
  final RxInt totalViews = 0.obs;
  final RxInt totalWatchMinutes = 0.obs;
  final RxString revenueChange = '+₹0.00'.obs;

  // Subscriptions
  StreamSubscription? _channelSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _tiersSub;
  StreamSubscription? _statementsSub;
  StreamSubscription? _bankAccountSub;
  StreamSubscription? _kycSub;

  @override
  void onClose() {
    _channelSub?.cancel();
    _membersSub?.cancel();
    _tiersSub?.cancel();
    _statementsSub?.cancel();
    _bankAccountSub?.cancel();
    _kycSub?.cancel();
    super.onClose();
  }

  void loadRevenueAnalytics(String chId, {String? chName, String? change}) {
    if (chId.isEmpty) return;
    channelId.value = chId;
    if (chName != null && chName.isNotEmpty) {
      channelName.value = chName;
    }
    if (change != null && change.isNotEmpty) {
      revenueChange.value = change;
    }

    // Sync from DashboardController if already loaded
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      if (dash.channelId == chId) {
        membershipsRevenue.value = dash.rxMembershipsRevenue.value;
        superchatRevenue.value = dash.rxSuperchatRevenue.value;
        adsRevenue.value = dash.rxAdsRevenue.value;
        watchTimeRevenue.value = dash.rxWatchTimeRevenue.value;
        totalRevenue.value = dash.rxTotalRevenue.value;
        activeMembersCount.value = dash.rxActiveMembersCount.value;
        activeTiersCount.value = dash.rxActiveTiersCount.value;
        if (totalRevenue.value > 0) {
          rxIsLoading.value = false;
        }
      }
    }

    _subscribeToAuthenticData();
  }

  void _subscribeToAuthenticData() {
    final chId = channelId.value;
    if (chId.isEmpty) return;

    rxIsLoading.value = true;

    // 1. Main Channel Document (superchats, ad revenue, views)
    _channelSub?.cancel();
    _channelSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          if (channelName.value.isEmpty || channelName.value == 'Channel') {
            channelName.value =
                (data['name'] ?? data['channelName'] ?? 'Creator Channel')
                    .toString();
          }

          final superchats =
              (data['superchatRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          if (superchats > 0) {
            superchatRevenue.value = superchats;
          }

          final ads = (data['adsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
          if (ads > 0) {
            adsRevenue.value = ads;
          }

          final views = (data['viewCount'] as num?)?.toInt() ??
              (data['totalViews'] as num?)?.toInt() ??
              0;
          totalViews.value = views;

          final watchMins = (data['totalWatchTimeMinutes'] as num?)?.toInt() ??
              ((data['totalWatchTimeSeconds'] as num?) != null
                  ? (((data['totalWatchTimeSeconds'] as num).toDouble()) / 60.0)
                      .round()
                  : 0);
          totalWatchMinutes.value = watchMins;

          if (adsRevenue.value == 0.0 && views > 0) {
            adsRevenue.value = views * 0.005;
          }
          if (watchTimeRevenue.value == 0.0 && watchMins > 0) {
            watchTimeRevenue.value = watchMins * 0.002;
          }

          final kycStatus = (data['kycStatus'] as String? ?? '').toLowerCase().trim();
          if (kycStatus.isNotEmpty) {
            channelKycStatus.value = kycStatus;
          }

          _recalculateTotal();
        }
        rxIsLoading.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(err,
            stackTrace: stack, tag: 'RevenueAnalyticsController._channelSub');
        rxIsLoading.value = false;
      },
    );

    // 2. Authentic Members Stream (Active memberships fan funding)
    _membersSub?.cancel();
    _membersSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('members')
        .snapshots()
        .listen(
      (snap) {
        final activeDocs = snap.docs.where((doc) {
          final data = doc.data();
          return (data['status'] ?? 'active').toString().toLowerCase() ==
              'active';
        }).toList();

        activeMembersCount.value = activeDocs.length;

        var sum = 0.0;
        for (final doc in activeDocs) {
          final data = doc.data();
          sum += (data['price'] as num?)?.toDouble() ?? 0.0;
        }

        membershipsRevenue.value = sum;
        _recalculateTotal();
        rxIsLoading.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(err,
            stackTrace: stack, tag: 'RevenueAnalyticsController._membersSub');
        rxIsLoading.value = false;
      },
    );

    // 3. Membership Tiers Stream (Fallback member count and tier prices)
    _tiersSub?.cancel();
    _tiersSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('membership_tiers')
        .snapshots()
        .listen(
      (snap) {
        var activeCount = 0;
        var tierIncome = 0.0;
        var memberSum = 0;

        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['isEnabled'] != false) {
            activeCount++;
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final count = (data['memberCount'] as num?)?.toInt() ?? 0;
            tierIncome += price * count;
            memberSum += count;
          }
        }

        activeTiersCount.value = activeCount;
        if (membershipsRevenue.value == 0.0 && tierIncome > 0.0) {
          membershipsRevenue.value = tierIncome;
          if (activeMembersCount.value == 0) {
            activeMembersCount.value = memberSum;
          }
        }
        _recalculateTotal();
        rxIsLoading.value = false;
      },
      onError: (err, stack) {
        ErrorHandler.log(err,
            stackTrace: stack, tag: 'RevenueAnalyticsController._tiersSub');
        rxIsLoading.value = false;
      },
    );

    // 4. Revenue Statements Stream
    _statementsSub?.cancel();
    _statementsSub = _firestore
        .collection('revenue_statements')
        .where('channelId', isEqualTo: chId)
        .limit(1)
        .snapshots()
        .listen(
      (snap) {
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final grossAds = (data['grossAdsRevenue'] as num?)?.toDouble() ?? 0.0;
          if (grossAds > 0) {
            adsRevenue.value = grossAds;
          }
          final grossSubs =
              (data['grossSubsRevenue'] as num?)?.toDouble() ?? 0.0;
          if (grossSubs > 0 && superchatRevenue.value == 0.0) {
            superchatRevenue.value = grossSubs;
          }
          _recalculateTotal();
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(err,
            stackTrace: stack,
            tag: 'RevenueAnalyticsController._statementsSub');
      },
    );

    // 5. Creator Bank Account for Direct Payouts
    _bankAccountSub?.cancel();
    _bankAccountSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('payout_settings')
        .doc('bank_account')
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          savedBankAccount.value = CreatorBankAccount.fromMap(doc.data()!);
        } else {
          // Check user fallback if channel doc not yet populated
          _loadUserFallbackBankAccount();
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(err,
            stackTrace: stack,
            tag: 'RevenueAnalyticsController._bankAccountSub');
      },
    );

    // 6. Creator KYC Verification Stream
    _kycSub?.cancel();
    _kycSub = _firestore
        .collection(FirestoreCollections.channels)
        .doc(chId)
        .collection('kyc')
        .doc('verification')
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          final kyc = CreatorKycVerification.fromMap(doc.data()!, channelId: chId);
          creatorKyc.value = kyc;
          channelKycStatus.value = kyc.status.toDbString();
        } else {
          _checkRootKycFallback(chId);
        }
      },
      onError: (err, stack) {
        ErrorHandler.log(err,
            stackTrace: stack,
            tag: 'RevenueAnalyticsController._kycSub');
      },
    );
  }

  Future<void> _checkRootKycFallback(String chId) async {
    try {
      final rootDoc = await _firestore.collection('creator_kyc').doc(chId).get();
      if (rootDoc.exists && rootDoc.data() != null) {
        final kyc = CreatorKycVerification.fromMap(rootDoc.data()!, channelId: chId);
        creatorKyc.value = kyc;
        channelKycStatus.value = kyc.status.toDbString();
      }
    } catch (_) {}
  }

  Future<void> _loadUserFallbackBankAccount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('payout_settings')
          .doc('bank_account')
          .get();
      if (userDoc.exists && userDoc.data() != null && savedBankAccount.value == null) {
        savedBankAccount.value = CreatorBankAccount.fromMap(userDoc.data()!);
      }
    } catch (_) {
      // Non-critical fallback
    }
  }

  void _recalculateTotal() {
    final total = membershipsRevenue.value +
        superchatRevenue.value +
        adsRevenue.value +
        watchTimeRevenue.value;
    totalRevenue.value = total;

    if (total > 0) {
      revenueChange.value = '+₹${total.toStringAsFixed(2)}';
    }
  }

  Future<void> refreshData() async {
    _subscribeToAuthenticData();
  }

  void navigateToMemberships() {
    final chId = channelId.value;
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      dash.setSelectedIndex(18); // Memberships Tab
      Get.back<void>();
    } else {
      Get.to<void>(
        () => MembershipsScreen(channelId: chId),
      );
    }
  }

  void navigateToMonetization() {
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      dash.setSelectedIndex(5); // Monetization Tab
      Get.back<void>();
    } else {
      Get.to<void>(
        () => const MonetizationScreen(isDarkMode: true),
      );
    }
  }

  Future<bool> submitWithdrawalRequest({
    required double amount,
    required String paymentMethod,
    required String accountDetails,
  }) async {
    if (amount < minimumWithdrawalAmount) {
      AppSnackbar.warning(
        'Minimum withdrawal amount is ₹${minimumWithdrawalAmount.toInt()} (100 Rupees).',
      );
      return false;
    }

    if (amount > totalRevenue.value) {
      AppSnackbar.warning(
        'Requested amount exceeds your available balance of ₹${totalRevenue.value.toStringAsFixed(2)}.',
      );
      return false;
    }

    try {
      isSubmittingWithdrawal.value = true;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final payoutRef = _firestore.collection('payout_requests').doc();

      await payoutRef.set({
        'id': payoutRef.id,
        'userId': uid,
        'channelId': channelId.value,
        'channelName': channelName.value,
        'amount': amount,
        'currency': currencyCode,
        'currencySymbol': currencySymbol,
        'paymentMethod': paymentMethod,
        'accountDetails': accountDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      isSubmittingWithdrawal.value = false;
      AppSnackbar.success(
        'Withdrawal request of ₹${amount.toStringAsFixed(2)} (Rupees) submitted successfully. Funds will be transferred to your registered account.',
      );
      return true;
    } catch (e, stackTrace) {
      isSubmittingWithdrawal.value = false;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsController.submitWithdrawalRequest',
      );
      AppSnackbar.error(
        'Unable to submit withdrawal request. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Saves the creator's bank account to channel and user payout settings for future 1-click payouts.
  Future<bool> saveBankAccount(CreatorBankAccount account) async {
    final chId = channelId.value;
    if (chId.isEmpty) return false;

    try {
      isLoadingBankAccount.value = true;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final batch = _firestore.batch();

      // 1. Channel Payout Settings
      final channelBankRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(chId)
          .collection('payout_settings')
          .doc('bank_account');
      batch.set(channelBankRef, account.toMap(), SetOptions(merge: true));

      // 2. User Payout Settings Fallback
      if (uid.isNotEmpty) {
        final userBankRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection('payout_settings')
            .doc('bank_account');
        batch.set(userBankRef, account.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
      savedBankAccount.value = account;
      isLoadingBankAccount.value = false;
      AppSnackbar.success(
        'Bank account for direct payouts saved successfully.',
      );
      return true;
    } catch (e, stackTrace) {
      isLoadingBankAccount.value = false;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsController.saveBankAccount',
      );
      AppSnackbar.error(
        'Unable to save bank account. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Processes withdrawal directly to the creator's bank account with full validation.
  Future<bool> submitDirectBankWithdrawal({
    required double amount,
    required CreatorBankAccount bankAccount,
    bool saveAsDefault = true,
  }) async {
    // 1. Mandatory KYC Verification Gate
    if (!isKycVerified) {
      AppSnackbar.warning(
        'KYC document verification (PAN & ID) is required before withdrawing earnings. Please complete verification first.',
      );
      return false;
    }

    if (amount < minimumWithdrawalAmount) {
      AppSnackbar.warning(
        'Minimum withdrawal amount is ₹${minimumWithdrawalAmount.toInt()} (100 Rupees).',
      );
      return false;
    }

    if (amount > totalRevenue.value) {
      AppSnackbar.warning(
        'Requested amount exceeds your available balance of ₹${totalRevenue.value.toStringAsFixed(2)}.',
      );
      return false;
    }

    if (!CreatorBankAccount.isValidAccountNumber(bankAccount.accountNumber)) {
      AppSnackbar.warning(
        'Please enter a valid bank account number (9 to 18 digits).',
      );
      return false;
    }

    if (!CreatorBankAccount.isValidIfsc(bankAccount.ifscCode)) {
      AppSnackbar.warning(
        'Please enter a valid 11-character Indian IFSC code (e.g. SBIN0001234).',
      );
      return false;
    }

    if (bankAccount.accountHolderName.trim().isEmpty) {
      AppSnackbar.warning(
        'Please enter the Account Holder Name as registered with your bank.',
      );
      return false;
    }

    try {
      isSubmittingWithdrawal.value = true;

      if (saveAsDefault) {
        await saveBankAccount(bankAccount);
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final payoutRef = _firestore.collection('payout_requests').doc();

      await payoutRef.set({
        'id': payoutRef.id,
        'userId': uid,
        'channelId': channelId.value,
        'channelName': channelName.value,
        'amount': amount,
        'currency': currencyCode,
        'currencySymbol': currencySymbol,
        'paymentMethod': 'direct_bank_transfer',
        'payoutDestination': 'Direct Bank Account (NEFT/IMPS)',
        'beneficiaryName': bankAccount.accountHolderName.trim(),
        'bankName': bankAccount.bankName.trim(),
        'accountNumber': bankAccount.accountNumber.trim(),
        'accountNumberMasked': bankAccount.maskedAccountNumber,
        'ifscCode': bankAccount.formattedIfsc,
        'accountType': bankAccount.accountType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      isSubmittingWithdrawal.value = false;
      AppSnackbar.success(
        'Withdrawal request of ₹${amount.toStringAsFixed(2)} to ${bankAccount.bankName} (${bankAccount.maskedAccountNumber}) submitted successfully! Direct transfer is being processed.',
      );
      return true;
    } catch (e, stackTrace) {
      isSubmittingWithdrawal.value = false;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsController.submitDirectBankWithdrawal',
      );
      AppSnackbar.error(
        'Unable to process bank withdrawal. Please check your connection and try again.',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Creator KYC Document Verification Submission
  // ---------------------------------------------------------------------------

  /// Uploads a private KYC image document to Firebase Storage (/kyc_documents/{userId}/)
  Future<String> _uploadKycDocumentFile({
    required Uint8List bytes,
    required String filePrefix,
    required String uid,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'kyc_documents/$uid/${filePrefix}_$timestamp.jpg';
    final ref = _storage.ref().child(path);

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
      AppSnackbar.warning('Please enter your Legal Name exactly as printed on your PAN card.');
      return false;
    }

    if (!CreatorKycVerification.isValidAge(dateOfBirth)) {
      AppSnackbar.warning('You must be at least 18 years of age to submit creator KYC verification.');
      return false;
    }

    if (cleanIdNumber.isEmpty) {
      AppSnackbar.warning('Please enter your ${idProofType.displayName} number.');
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
      final panUrl = await _uploadKycDocumentFile(
        bytes: panImageBytes,
        filePrefix: 'pan_${chId.replaceAll('/', '_')}',
        uid: uid,
      );

      // 2. Upload ID Proof Front Image
      kycUploadProgress.value = 0.55;
      final idFrontUrl = await _uploadKycDocumentFile(
        bytes: idFrontImageBytes,
        filePrefix: 'id_front_${chId.replaceAll('/', '_')}',
        uid: uid,
      );

      // 3. Upload ID Proof Back Image (if provided)
      String? idBackUrl;
      if (idBackImageBytes != null && idBackImageBytes.isNotEmpty) {
        kycUploadProgress.value = 0.80;
        idBackUrl = await _uploadKycDocumentFile(
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

      final batch = _firestore.batch();

      // Write to channels/{chId}/kyc/verification
      final chKycRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(chId)
          .collection('kyc')
          .doc('verification');
      batch.set(chKycRef, kycRecord.toMap(), SetOptions(merge: true));

      // Write to master creator_kyc/{chId}
      final masterKycRef = _firestore.collection('creator_kyc').doc(chId);
      batch.set(masterKycRef, kycRecord.toMap(), SetOptions(merge: true));

      // Update channel doc kycStatus
      final chRef = _firestore.collection(FirestoreCollections.channels).doc(chId);
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
        tag: 'RevenueAnalyticsController.submitKycVerification',
      );
      AppSnackbar.error(
        'Unable to submit KYC documents. Please check your internet connection and try again.',
      );
      return false;
    }
  }
}
