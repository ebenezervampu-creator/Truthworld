import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/live_chat_message.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/live_chat_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive Real-Time Live Chat Overlay with Bounded Sliding Window,
/// Pinned Superchats, Moderation actions, and Cooldown Slow-Mode.
class LiveChatOverlay extends StatelessWidget {
  const LiveChatOverlay({
    required this.videoId,
    this.video,
    this.onClose,
    super.key,
  });

  final String videoId;
  final Video? video;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tag = 'live_chat_$videoId';
    final controller = Get.put(
      LiveChatController(videoId: videoId, video: video),
      tag: tag,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        children: [
          // 1. Header Bar
          _buildHeader(context, controller),

          // 2. Pinned Superchat Banner (if active)
          Obx(() {
            final pinned = controller.pinnedMessage.value;
            if (pinned == null) return const SizedBox.shrink();
            return _buildPinnedSuperchatBanner(context, pinned);
          }),

          // 3. Message Stream List
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(context, controller),
                // Auto-scroll resume pill
                Obx(() {
                  if (controller.isAutoScrollEnabled.value ||
                      controller.unreadCount.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return _buildResumeScrollPill(controller);
                }),
              ],
            ),
          ),

          // 4. Chat Input Bar
          _buildInputBar(context, controller),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LiveChatController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Live Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedSuperchatBanner(
    BuildContext context,
    LiveChatMessage pinned,
  ) {
    final tierColor = pinned.tierColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: tierColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: tierColor,
            backgroundImage: pinned.userProfilePicUrl.isNotEmpty
                ? CachedNetworkImageProvider(pinned.userProfilePicUrl)
                : null,
            child: pinned.userProfilePicUrl.isEmpty
                ? const Icon(Icons.person_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pinned.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${pinned.superchatCurrency} ${pinned.superchatAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (pinned.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pinned.text,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.push_pin_rounded, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    LiveChatController controller,
  ) {
    return Obx(() {
      if (controller.isLoading && controller.messages.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      }

      if (controller.messages.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 36),
              SizedBox(height: 8),
              Text(
                'Welcome to Live Chat!\nSay hello to start the conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          return _buildMessageItem(context, controller, message);
        },
      );
    });
  }

  Widget _buildMessageItem(
    BuildContext context,
    LiveChatController controller,
    LiveChatMessage message,
  ) {
    if (message.isSuperchat) {
      return _buildSuperchatCard(context, controller, message);
    }

    return InkWell(
      onLongPress: () {
        if (controller.isCreator) {
          _showModerationSheet(context, controller, message);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.bgSurface,
              backgroundImage: message.userProfilePicUrl.isNotEmpty
                  ? CachedNetworkImageProvider(message.userProfilePicUrl)
                  : null,
              child: message.userProfilePicUrl.isEmpty
                  ? const Icon(Icons.person_rounded, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            // Content
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: message.userName,
                      style: TextStyle(
                        color: message.isCreator
                            ? Colors.amberAccent
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (message.isCreator)
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(left: 4, right: 4),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperchatCard(
    BuildContext context,
    LiveChatController controller,
    LiveChatMessage message,
  ) {
    final tierColor = message.tierColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tierColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tierColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white24,
                  backgroundImage: message.userProfilePicUrl.isNotEmpty
                      ? CachedNetworkImageProvider(message.userProfilePicUrl)
                      : null,
                  child: message.userProfilePicUrl.isEmpty
                      ? const Icon(Icons.person_rounded, size: 10, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${message.superchatCurrency} ${message.superchatAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumeScrollPill(LiveChatController controller) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: InkWell(
          onTap: controller.resumeAutoScroll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Chat paused  •  ${controller.unreadCount.value} new',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    LiveChatController controller,
  ) {
    return Obx(() {
      final isAuthed = AuthService.to.isAuthenticated.value;
      if (!isAuthed) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(top: BorderSide(color: AppColors.bgDivider)),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Center(
            child: TextButton.icon(
              onPressed: () => AuthBottomSheet.show(context),
              icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Sign in to chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          border: Border(top: BorderSide(color: AppColors.bgDivider)),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Row(
          children: [
            // Superchat button
            IconButton(
              icon: const Icon(Icons.monetization_on_outlined, color: Colors.white, size: 22),
              onPressed: () => _showSuperchatDialog(context, controller),
              tooltip: 'Send Superchat',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Text Input
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: TextField(
                  controller: controller.textController,
                  maxLength: ContentValidator.defaultMaxLiveChatLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(
                    ContentValidator.defaultMaxLiveChatLength,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Chat publicly as...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => controller.sendChatMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send / Cooldown Button
            Obx(() {
              final cooldown = controller.cooldownSeconds.value;
              if (cooldown > 0) {
                return Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.bgDivider,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${cooldown}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              return IconButton(
                icon: controller.isSending.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: controller.isSending.value ? null : controller.sendChatMessage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            }),
          ],
        ),
      );
    });
  }

  Future<void> _showSuperchatDialog(
    BuildContext context,
    LiveChatController controller,
  ) async {
    if (!AuthService.to.isAuthenticated.value) {
      AppSnackbar.info(
        'Please sign in to send a Superchat.',
        title: 'Sign In Required',
        actionLabel: 'SIGN IN',
        onAction: () => AuthBottomSheet.show(context),
      );
      return;
    }

    await CurrencyLocalizationService.to.fetchRealtimeRate();
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;
    final currencySymbol = isIndian ? '₹' : r'$';
    final amountController = TextEditingController(text: isIndian ? '20' : '1');
    final messageController = TextEditingController();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send Superchat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Highlight your message and directly support the creator.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
                labelText: isIndian ? 'Amount (INR)' : 'Amount (USD)',
                helperText: isIndian
                    ? 'Direct creator tip in Indian Rupees (INR)'
                    : 'Direct creator tip in US Dollars (USD)',
                helperStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgPage,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLength: ContentValidator.defaultMaxLiveChatLength,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(
                ContentValidator.defaultMaxLiveChatLength,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Message (Optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgPage,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (amount <= 0) {
                    AppSnackbar.warning('Please enter an amount to send Super Chat.');
                    return;
                  }
                  final minAmount = isIndian ? 1.0 : 0.50;
                  if (amount < minAmount) {
                    final minStr = isIndian ? '₹1.00' : r'$0.50';
                    AppSnackbar.warning('Minimum Super Chat amount is $minStr.');
                    return;
                  }
                  final amountINR = isIndian ? amount : (amount * rate);
                  Get.back();
                  controller.sendSuperchatWithCashfree(
                    amountINR: amountINR,
                    text: messageController.text.trim(),
                    originalAmount: isIndian ? null : amount,
                    originalCurrency: isIndian ? 'INR' : 'USD',
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Pay with Cashfree',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 5),
                  Text(
                    'Secured by Cashfree • ${CashfreeCountrySupport.getPaymentMethodsSummary(isIndian ? "IN" : (Get.isRegistered<CurrencyLocalizationService>() ? CurrencyLocalizationService.to.userCountryCode.value : "US"))}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModerationSheet(
    BuildContext context,
    LiveChatController controller,
    LiveChatMessage message,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moderate ${message.userName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.timer_outlined, color: Colors.white),
              title: const Text('Timeout (5 minutes)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                controller.moderateUser(
                  targetUserId: message.userId,
                  action: 'timeout',
                  deleteMessageId: message.id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.white),
              title: const Text('Hide/Ban user on this channel', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                controller.moderateUser(
                  targetUserId: message.userId,
                  action: 'ban',
                  deleteMessageId: message.id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                controller.moderateUser(
                  targetUserId: message.userId,
                  action: 'delete',
                  deleteMessageId: message.id,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
