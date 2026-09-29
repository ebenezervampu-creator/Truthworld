import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class PremiumCommentInputController extends BaseController {
  final TextEditingController commentController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final RxBool isSubmitting = false.obs;
  final RxBool isFocused = false.obs;
  final RxBool hasText = false.obs;

  @override
  void onInit() {
    super.onInit();
    trackTextController(commentController);
    focusNode.addListener(() {
      isFocused.value = focusNode.hasFocus;
    });
    commentController.addListener(() {
      hasText.value = commentController.text.trim().isNotEmpty;
    });
  }

  @override
  void onClose() {
    focusNode.dispose();
    super.onClose();
  }
}

/// Premium comment input with enhanced UI and onSubmit callback
class PremiumCommentInput extends StatelessWidget {
  const PremiumCommentInput({
    required this.videoId,
    required this.onSubmit,
    super.key,
    this.isReply = false,
    this.onCancel,
    this.channelId,
    this.videoTitle,
  });
  final String videoId;
  final bool isReply;
  final Function(String text, bool postAsChannel, String? channelId) onSubmit;
  final VoidCallback? onCancel;
  final String? channelId;
  final String? videoTitle;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      PremiumCommentInputController(),
      tag: 'premium_input_${videoId}_$isReply',
    );

    return Obx(() {
      final authService = AuthService.to;
      final isAuthenticated = authService.isAuthenticated.value;
      if (!isAuthenticated) {
        return _buildUnauthenticatedPrompt(context);
      }

      final user = authService.user;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final photoUrl = authService.activePhotoUrl;
      final initial = hasChannel
          ? (channel?.name.isNotEmpty ?? false
                ? channel!.name.substring(0, 1).toUpperCase()
                : 'C')
          : (user?.email?.isNotEmpty ?? false
                ? user!.email!.substring(0, 1).toUpperCase()
                : (user?.displayName?.isNotEmpty ?? false
                      ? user!.displayName!.substring(0, 1).toUpperCase()
                      : 'U'));

      Future<void> submitComment() async {
        if (!authService.isAuthenticated.value) {
          AppSnackbar.warning(
            'Please sign in to post a comment',
            title: 'Sign In Required',
            actionLabel: 'SIGN IN',
            onAction: authService.signInWithGoogle,
          );
          return;
        }

        final text = controller.commentController.text.trim();
        if (text.isEmpty || controller.isSubmitting.value) return;

        final validation = ContentValidator.validate(text, fieldName: 'Comment');
        if (!validation.isValid) {
          AppSnackbar.warning(
            validation.message,
            title: 'Inappropriate Content',
          );
          return;
        }

        controller.isSubmitting.value = true;

        try {
          HapticFeedback.mediumImpact();
          await onSubmit(
            text,
            hasChannel,
            hasChannel ? channel?.id : null,
          );
          controller.commentController.clear();
          controller.focusNode.unfocus();
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'PremiumCommentInput.submitComment',
          );
          AppSnackbar.error('Failed to post comment. Please try again.');
        } finally {
          controller.isSubmitting.value = false;
        }
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            photoUrl: photoUrl,
            displayName: initial,
            radius: 18,
            backgroundColor: AppColors.info,
            textColor: AppColors.textPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: controller.commentController,
                  focusNode: controller.focusNode,
                  maxLines: null,
                  minLines: 1,
                  inputFormatters: [TruthworldTextInputFormatters.englishOnly],
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => submitComment(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: isReply ? 'Add a reply...' : 'Add a comment...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textPrimary,
                        width: 1.5,
                      ),
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                Obx(() {
                  if (controller.isFocused.value || controller.hasText.value) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              controller.commentController.clear();
                              controller.focusNode.unfocus();
                              if (onCancel != null) onCancel!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          if (!isReply) ...[
                            IconButton(
                              onPressed: () => showSuperThanksModal(
                                context,
                                videoId: videoId,
                                channelId: channelId,
                                videoTitle: videoTitle,
                                onSubmit: onSubmit,
                              ),
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.attach_money,
                                  color: AppColors.textPrimary,
                                  size: 18,
                                ),
                              ),
                              tooltip: 'Super Thanks / Donate',
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton(
                            onPressed:
                                controller.isSubmitting.value ||
                                    !controller.hasText.value
                                ? null
                                : submitComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: controller.hasText.value
                                  ? AppColors.info
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                              foregroundColor: controller.hasText.value
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Comment'),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildUnauthenticatedPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Join the conversation',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sign in to add a comment or reply',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await AuthService.to.signInWithGoogle();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showSuperThanksModal(
    BuildContext context, {
    required String videoId,
    String? channelId,
    String? videoTitle,
    Function(String text, bool postAsChannel, String? channelId)? onSubmit,
  }) {
    if (!AuthService.to.isAuthenticated.value) {
      AppSnackbar.warning(
        'Please sign in to send Super Thanks.',
        title: 'Authentication Required',
        actionLabel: 'SIGN IN',
        onAction: () => AuthService.to.signInWithGoogle(),
      );
      return;
    }

    if (Get.isRegistered<CurrencyLocalizationService>()) {
      CurrencyLocalizationService.to.fetchRealtimeRate();
    }

    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    final inrTiers = [
      {'amount': 40.0, 'color': '0xFF00B8D4', 'label': '₹40'},
      {'amount': 100.0, 'color': '0xFF1E88E5', 'label': '₹100'},
      {'amount': 200.0, 'color': '0xFF00C853', 'label': '₹200'},
      {'amount': 500.0, 'color': '0xFFFFD600', 'label': '₹500'},
      {'amount': 1000.0, 'color': '0xFFFF6D00', 'label': '₹1,000'},
      {'amount': 2000.0, 'color': '0xFFD50000', 'label': '₹2,000'},
    ];

    final usdTiers = [
      {'amount': 2.0, 'color': '0xFF00B8D4', 'label': r'$2.00'},
      {'amount': 5.0, 'color': '0xFF1E88E5', 'label': r'$5.00'},
      {'amount': 10.0, 'color': '0xFF00C853', 'label': r'$10.00'},
      {'amount': 20.0, 'color': '0xFFFFD600', 'label': r'$20.00'},
      {'amount': 50.0, 'color': '0xFFFF6D00', 'label': r'$50.00'},
      {'amount': 100.0, 'color': '0xFFD50000', 'label': r'$100.00'},
    ];

    final tiers = isIndian ? inrTiers : usdTiers;
    final selectedTierIndex = 1.obs; // Default 2nd tier
    final messageController = TextEditingController();
    final isSubmitting = false.obs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Obx(() {
                final currentTier = tiers[selectedTierIndex.value];
                final tierColor = Color(
                  int.parse(currentTier['color']! as String),
                );
                final amountStr = currentTier['label']! as String;
                final amountVal =
                    (currentTier['amount'] as num?)?.toDouble() ?? 0.0;
                final amountINR = isIndian
                    ? amountVal
                    : double.parse((amountVal * rate).toStringAsFixed(2));

                final isLightColor = tierColor.computeLuminance() > 0.45;
                final buttonTextColor =
                    isLightColor ? Colors.black : Colors.white;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.bgDivider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: tierColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Super Thanks',
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Post a highlighted comment & support the creator directly',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tier Selection Pills
                    Text(
                      'SELECT DONATION AMOUNT',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(tiers.length, (index) {
                          final isSelected = selectedTierIndex.value == index;
                          final item = tiers[index];
                          final itemColor = Color(
                            int.parse(item['color']! as String),
                          );
                          final isItemLight =
                              itemColor.computeLuminance() > 0.45;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                item['label']! as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? (isItemLight
                                          ? Colors.black
                                          : Colors.white)
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: itemColor,
                              backgroundColor: AppColors.bgInput,
                              onSelected: (_) =>
                                  selectedTierIndex.value = index,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isIndian
                          ? 'Equivalent to ~ \$${(amountVal / rate).toStringAsFixed(2)} USD (Live forex: ₹${rate.toStringAsFixed(2)} / \$1 USD)'
                          : 'Billed via Cashfree PG as ₹${amountINR.toStringAsFixed(2)} INR (Live forex: ₹${rate.toStringAsFixed(2)} / \$1 USD)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Donated Comment Preview Box
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tierColor, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Tier Banner Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: tierColor,
                            child: Row(
                              children: [
                                UserAvatar(
                                  photoUrl: AuthService.to.activePhotoUrl,
                                  displayName: AuthService.to.activeDisplayName,
                                  radius: 16,
                                  textColor: buttonTextColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AuthService.to.activeDisplayName,
                                    style: TextStyle(
                                      color: buttonTextColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        amountStr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Comment Input Area inside preview
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: messageController,
                              maxLines: 3,
                              minLines: 2,
                              inputFormatters:
                                  TruthworldTextInputFormatters.standard,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Write a Super Thanks message...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tierColor,
                          foregroundColor: buttonTextColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSubmitting.value
                            ? null
                            : () async {
                                final text = messageController.text.trim();
                                if (text.isEmpty) {
                                  AppSnackbar.warning(
                                    'Please enter a message for your Super Thanks.',
                                  );
                                  return;
                                }

                                final validation = ContentValidator.validate(
                                  text,
                                  fieldName: 'Super Thanks',
                                );
                                if (!validation.isValid) {
                                  AppSnackbar.warning(validation.message);
                                  return;
                                }

                                if (amountINR < 1.0) {
                                  AppSnackbar.warning(
                                    'Minimum transaction amount is ₹1.00.',
                                  );
                                  return;
                                }

                                isSubmitting.value = true;
                                try {
                                  final cleanText =
                                      ContentValidator.cleanProfanity(text);

                                  // Resolve target CommentsController and channel info
                                  CommentsController? commentsCtrl;
                                  final tag = 'comments_$videoId';
                                  if (Get.isRegistered<CommentsController>(
                                      tag: tag)) {
                                    commentsCtrl =
                                        Get.find<CommentsController>(tag: tag);
                                  } else if (Get.isRegistered<
                                      CommentsController>()) {
                                    commentsCtrl =
                                        Get.find<CommentsController>();
                                  }

                                  final effectiveChannelId = channelId ??
                                      commentsCtrl?.video?.channelId ??
                                      '';
                                  final effectiveVideoTitle = videoTitle ??
                                      commentsCtrl?.video?.title ??
                                      'Video';

                                  var paymentSucceeded = false;
                                  var transactionOrderId = '';

                                  final orderNote = isIndian
                                      ? 'Super Thanks on $effectiveVideoTitle ($amountStr)'
                                      : 'Super Thanks on $effectiveVideoTitle ($amountStr ~ ₹${amountINR.toStringAsFixed(2)} INR)';

                                  final paymentResult =
                                      await CashfreePaymentService.to
                                          .startPayment(
                                    amount: amountINR,
                                    purpose: 'super_thanks',
                                    orderNote: orderNote,
                                    metadata: {
                                      'channelId': effectiveChannelId,
                                      'videoId': videoId,
                                      'text': cleanText,
                                      'userName':
                                          AuthService.to.activeDisplayName,
                                      'userProfilePicUrl':
                                          AuthService.to.activePhotoUrl,
                                      'tierColor':
                                          currentTier['color']! as String,
                                      'originalAmount': amountVal,
                                      'originalCurrency':
                                          isIndian ? 'INR' : 'USD',
                                    },
                                  );

                                  if (paymentResult.success) {
                                    paymentSucceeded = true;
                                    transactionOrderId =
                                        paymentResult.orderId;
                                  } else {
                                    if (paymentResult.errorMessage != null &&
                                        !paymentResult.errorMessage!
                                            .toLowerCase()
                                            .contains('cancel')) {
                                      AppSnackbar.error(
                                          paymentResult.errorMessage!);
                                    }
                                    return;
                                  }

                                  if (paymentSucceeded) {
                                    final currencySymbol =
                                        isIndian ? '₹' : r'$';
                                    if (commentsCtrl != null) {
                                      await commentsCtrl.submitComment(
                                        text: cleanText,
                                        donationAmount: amountVal,
                                        donationCurrency: currencySymbol,
                                        isDonatedComment: true,
                                        donationColorHex:
                                            currentTier['color']! as String,
                                      );
                                    } else if (onSubmit != null) {
                                      await onSubmit(cleanText, false, null);
                                    } else {
                                      final authService = AuthService.to;
                                      final hasChannel =
                                          authService.hasChannel.value &&
                                              authService.userChannel != null;
                                      final commentService = CommentService();
                                      await commentService.addComment(
                                        videoId: videoId,
                                        userId: authService.uid,
                                        userName: authService.activeDisplayName,
                                        userProfilePicUrl:
                                            authService.activePhotoUrl,
                                        channelId: hasChannel
                                            ? authService.userChannel!.id
                                            : authService.uid,
                                        channelName: hasChannel
                                            ? (authService.userChannel?.handle
                                                        .isNotEmpty ==
                                                    true
                                                ? authService
                                                    .userChannel!.handle
                                                : authService
                                                    .userChannel!.name)
                                            : authService.activeDisplayName,
                                        channelProfilePicUrl:
                                            authService.activePhotoUrl,
                                        text: cleanText,
                                        donationAmount: amountVal,
                                        donationCurrency: currencySymbol,
                                        isDonatedComment: true,
                                        donationColorHex:
                                            currentTier['color']! as String,
                                      );
                                    }

                                    if (effectiveChannelId.isNotEmpty) {
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection(
                                                FirestoreCollections.channels)
                                            .doc(effectiveChannelId)
                                            .collection('donations')
                                            .doc(transactionOrderId.isNotEmpty
                                                ? transactionOrderId
                                                : null)
                                            .set({
                                          'amount': amountINR,
                                          'currency': isIndian ? 'INR' : 'USD',
                                          'originalAmount': amountVal,
                                          'donorId': AuthService.to.uid,
                                          'donorName':
                                              AuthService.to.activeDisplayName,
                                          'videoId': videoId,
                                          'text': cleanText,
                                          'donatedAt':
                                              FieldValue.serverTimestamp(),
                                          'type': 'super_thanks',
                                          'status': 'completed',
                                        }, SetOptions(merge: true));
                                      } catch (e, stackTrace) {
                                        ErrorHandler.log(
                                          e,
                                          stackTrace: stackTrace,
                                          tag: 'PremiumCommentInput.recordDonationFallback',
                                        );
                                      }
                                    }

                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    HapticFeedback.heavyImpact();
                                    AppSnackbar.success(
                                      'Thank you for supporting the creator with $amountStr! 🎉',
                                      title: 'Super Thanks Sent!',
                                    );
                                  }
                                } catch (e, stackTrace) {
                                  ErrorHandler.log(
                                    e,
                                    stackTrace: stackTrace,
                                    tag: 'PremiumCommentInput.submitSuperThanks',
                                  );
                                  AppSnackbar.error(
                                    'Unable to complete Super Thanks payment. Please try again.',
                                  );
                                } finally {
                                  isSubmitting.value = false;
                                }
                              },
                        icon: Icon(
                          Icons.favorite,
                          color: buttonTextColor,
                        ),
                        label: Text(
                          'Buy & Send Super Thanks ($amountStr)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: buttonTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
