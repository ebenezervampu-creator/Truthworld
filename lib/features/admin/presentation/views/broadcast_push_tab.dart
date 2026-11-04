import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/controllers/broadcast_push_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Super Admin screen for broadcasting Zomato-style push notifications
/// to every installed device on Android and iOS.
class BroadcastPushTab extends StatelessWidget {
  final AdminController controller;

  const BroadcastPushTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    final pushController = Get.isRegistered<BroadcastPushController>()
        ? BroadcastPushController.to
        : Get.put(BroadcastPushController());

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(pushController),
              const SizedBox(height: 20),
              _buildPresetsRibbon(pushController),
              const SizedBox(height: 24),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildComposerCard(context, pushController),
                          const SizedBox(height: 24),
                          _buildHistorySection(pushController),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: _buildLiveDevicePreview(context, pushController),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLiveDevicePreview(context, pushController),
                    const SizedBox(height: 24),
                    _buildComposerCard(context, pushController),
                    const SizedBox(height: 24),
                    _buildHistorySection(pushController),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header with Title and Super Admin badge
  Widget _buildHeader(BroadcastPushController pushController) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(
            Icons.cell_tower_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Push Broadcast Console',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'SUPER ADMIN',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Broadcast catchy, Zomato-style push notifications with rich banners to every installed device on Android & iOS.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Carousel of Curated Zomato-Style Push Presets
  Widget _buildPresetsRibbon(BroadcastPushController pushController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'ZOMATO-STYLE VIRAL INSPIRATION (1-CLICK LOAD)',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pushController.presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final preset = pushController.presets[index];
              return Obx(() {
                final isSelected = pushController.selectedPresetId.value == preset.id;
                return InkWell(
                  onTap: () => pushController.applyPreset(preset),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 260,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.bgSurface
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(preset.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                preset.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 10,
                            color: AppColors.textTertiary,
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
      ],
    );
  }

  /// Composer form card
  Widget _buildComposerCard(BuildContext context, BroadcastPushController pushController) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notification Composer',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: pushController.clearDraft,
                icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.textSecondary),
                label: const Text(
                  'Reset Draft',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dispatch Mode Selector
          _buildFieldHeader('Notification Mode', 'Broadcast to every device or direct message a specific user'),
          const SizedBox(height: 8),
          Obx(() {
            final isDirect = pushController.targetMode.value == 'direct_user';
            return Row(
              children: [
                Expanded(
                  child: _buildAudienceChoice(
                    label: '📢 Broadcast to Every Device',
                    value: 'broadcast',
                    isSelected: !isDirect,
                    onTap: () => pushController.targetMode.value = 'broadcast',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAudienceChoice(
                    label: '👤 1-to-1 Direct User Message',
                    value: 'direct_user',
                    isSelected: isDirect,
                    onTap: () => pushController.targetMode.value = 'direct_user',
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Direct User Target Field (Visible only in direct_user mode)
          Obx(() {
            if (pushController.targetMode.value != 'direct_user') return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldHeader('Target User', 'Enter user Email, UID, or Username'),
                const SizedBox(height: 6),
                TextField(
                  controller: pushController.targetUserController,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'e.g. user@truthworld.in or user_uid',
                    prefixIcon: const Icon(Icons.person_search_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Delivers a high-priority push notification to their physical devices AND saves in their in-app inbox.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),

          // Title field
          _buildFieldHeader('Notification Title', 'Keep it catchy & witty with emojis'),
          const SizedBox(height: 6),
          TextField(
            controller: pushController.titleController,
            maxLength: 100,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: _inputDecoration(
              hintText: 'e.g. 🍕 Hungry for the truth?',
            ),
          ),
          const SizedBox(height: 4),
          Obx(() {
            final len = pushController.titleRx.value.length;
            final isGood = len >= 15 && len <= 50;
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$len / 100 chars ${isGood ? "• Optimal Zomato length" : ""}',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 11,
                  color: isGood ? AppColors.success : AppColors.textTertiary,
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Message Body field
          _buildFieldHeader('Message Body', 'The punchline, cliffhanger, or curiosity spark'),
          const SizedBox(height: 6),
          TextField(
            controller: pushController.bodyController,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: _inputDecoration(
              hintText: "e.g. A fresh 2-minute snack of today's most verified stories is piping hot. Dig in!",
            ),
          ),
          const SizedBox(height: 4),
          Obx(() {
            final len = pushController.bodyRx.value.length;
            final isGood = len >= 40 && len <= 120;
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$len / 300 chars ${isGood ? "• Perfect readable length" : ""}',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 11,
                  color: isGood ? AppColors.success : AppColors.textTertiary,
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Platform Audience Selector (Only visible for global broadcast mode)
          Obx(() {
            if (pushController.targetMode.value == 'direct_user') {
              return const SizedBox.shrink();
            }
            final current = pushController.selectedPlatform.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldHeader('Target Audience', 'Select operating systems to receive push'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildAudienceChoice(
                      label: '📱 All Devices (Android & iOS)',
                      value: 'all',
                      isSelected: current == 'all',
                      onTap: () => pushController.selectedPlatform.value = 'all',
                    ),
                    _buildAudienceChoice(
                      label: '🤖 Android Only',
                      value: 'android',
                      isSelected: current == 'android',
                      onTap: () => pushController.selectedPlatform.value = 'android',
                    ),
                    _buildAudienceChoice(
                      label: '🍏 iOS Only',
                      value: 'ios',
                      isSelected: current == 'ios',
                      onTap: () => pushController.selectedPlatform.value = 'ios',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            );
          }),

          // Action URL / Route
          _buildFieldHeader('Action Deep-Link', 'Where should tapping the notification take users?'),
          const SizedBox(height: 6),
          TextField(
            controller: pushController.actionUrlController,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: _inputDecoration(
              hintText: '/feed, /trending, or /video/{id}',
              prefixIcon: const Icon(Icons.link_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildRouteChip(pushController, 'Home Feed', '/feed'),
              _buildRouteChip(pushController, 'Trending Verifications', '/trending'),
              _buildRouteChip(pushController, 'Fact Check Hub', '/verify'),
              _buildRouteChip(pushController, 'Explore Topics', '/topics'),
            ],
          ),
          const SizedBox(height: 16),

          // Rich Banner Image URL
          _buildFieldHeader('Rich Banner Image (Optional)', 'Displays as expanded photo card like Zomato deals'),
          const SizedBox(height: 6),
          TextField(
            controller: pushController.imageUrlController,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: _inputDecoration(
              hintText: 'https://images.truthworld.in/banners/...',
              prefixIcon: const Icon(Icons.image_outlined, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              // Dry Run Validation Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => pushController.sendBroadcast(isDryRun: true),
                icon: const Icon(Icons.science_outlined, size: 18, color: Colors.white),
                label: const Text(
                  'Dry Run Test',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Main Broadcast Button (High Contrast compliant: black text/spinner on white surface!)
              Expanded(
                child: Obx(() {
                  final sending = pushController.isSending.value;
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: sending ? null : () => _confirmAndSendBroadcast(context, pushController),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            pushController.targetMode.value == 'direct_user'
                                ? Icons.send_rounded
                                : Icons.rocket_launch_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                    label: Text(
                      sending
                          ? 'DISPATCHING...'
                          : (pushController.targetMode.value == 'direct_user'
                              ? 'SEND DIRECT MESSAGE NOTIFICATION'
                              : 'BROADCAST TO EVERY DEVICE'),
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Live Phone Device Mockup with real-time iOS/Android preview
  Widget _buildLiveDevicePreview(BuildContext context, BroadcastPushController pushController) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Device Preview',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              // Device toggle (iOS vs Android)
              Obx(() {
                final device = pushController.previewDevice.value;
                return Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      _buildDeviceTogglePill(
                        label: '🍏 iOS',
                        isSelected: device == 'ios',
                        onTap: () => pushController.previewDevice.value = 'ios',
                      ),
                      _buildDeviceTogglePill(
                        label: '🤖 Android',
                        isSelected: device == 'android',
                        onTap: () => pushController.previewDevice.value = 'android',
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 18),

          // Smartphone Mockup Bezel
          Container(
            width: 320,
            constraints: const BoxConstraints(minHeight: 460),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.bgDivider, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top notch / dynamic island
                Center(
                  child: Container(
                    width: 90,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Simulated Lockscreen Clock
                Center(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('h:mm').format(DateTime.now()),
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Mockup Targeting Mode Badge
                Obx(() {
                  final isDirect = pushController.targetMode.value == 'direct_user';
                  final target = pushController.targetUserRx.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDirect
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDirect
                          ? (target.isNotEmpty ? '👤 Direct to: $target' : '👤 1-to-1 Direct User Notification')
                          : '📢 Broadcast to All Devices',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDirect ? Colors.lightBlueAccent : Colors.white70,
                      ),
                    ),
                  );
                }),

                // Notification Banner Mockup
                Obx(() {
                  final isIos = pushController.previewDevice.value == 'ios';
                  final title = pushController.titleRx.value.isNotEmpty
                      ? pushController.titleRx.value
                      : 'Notification Title';
                  final body = pushController.bodyRx.value.isNotEmpty
                      ? pushController.bodyRx.value
                      : 'Notification message body will appear here...';
                  final imageUrl = pushController.imageUrlRx.value;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isIos
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(isIos ? 16 : 12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: isIos ? 0.15 : 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App Brand Row
                        const Row(
                          children: [
                            AppLogo(size: 18, borderRadius: 4),
                            SizedBox(width: 6),
                            Text(
                              'TRUTHWORLD',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'now',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Body
                        Text(
                          body,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),

                        // Big Picture Rich Media Banner
                        if (imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                height: 120,
                                color: AppColors.bgDivider,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                height: 120,
                                color: AppColors.bgSurface,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 30),

                // Mock Home Bar
                Center(
                  child: Container(
                    width: 100,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// History of dispatched push broadcasts
  Widget _buildHistorySection(BroadcastPushController pushController) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Broadcast Campaign History',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Obx(() {
            if (pushController.isLoadingHistory.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            final history = pushController.broadcastHistory;
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.mark_email_unread_outlined, size: 36, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      const Text(
                        'No push broadcasts dispatched yet.',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 18),
              itemBuilder: (context, index) {
                final item = history[index];
                final title = item['title'] as String? ?? 'Untitled';
                final body = item['body'] as String? ?? '';
                final target = (item['targetPlatform'] as String? ?? 'all').toUpperCase();
                final mode = item['targetMode'] as String? ?? 'broadcast';
                final isDirect = mode == 'direct_user';
                final badgeText = isDirect ? 'DIRECT' : target;
                final sender = item['senderEmail'] as String? ?? 'Admin';
                final recipient = item['targetUserEmail'] as String? ??
                    item['targetDisplayName'] as String? ??
                    item['targetUid'] as String?;
                final sentAtRaw = item['sentAt'];
                var sentTimeStr = 'Just now';
                if (sentAtRaw is Timestamp) {
                  sentTimeStr = DateFormat('MMM d, h:mm a').format(sentAtRaw.toDate());
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDirect
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: isDirect
                            ? Border.all(color: Colors.blue.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDirect ? Colors.lightBlueAccent : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$sentTimeStr • By $sender${isDirect && recipient != null ? " • Recipient: $recipient" : ""}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Copy into Composer',
                      onPressed: () => pushController.copyFromHistory(item),
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                    ),
                  ],
                );
              },
            );
          }),
        ],
      ),
    );
  }

  /// Confirmation Modal before executing a platform-wide push broadcast
  void _confirmAndSendBroadcast(BuildContext context, BroadcastPushController pushController) {
    final title = pushController.titleController.text.trim();
    final body = pushController.bodyController.text.trim();
    final target = pushController.selectedPlatform.value;

    if (title.isEmpty || body.isEmpty) {
      pushController.sendBroadcast(); // Will trigger field validation warnings
      return;
    }

    final isDirect = pushController.targetMode.value == 'direct_user';
    final targetUser = pushController.targetUserController.text.trim();
    if (isDirect && targetUser.isEmpty) {
      pushController.sendBroadcast(); // Triggers target user field validation warning
      return;
    }

    final targetLabel = isDirect
        ? 'Direct User Message ($targetUser)'
        : (target == 'all'
            ? 'Every Installed Device (Android & iOS)'
            : (target == 'android' ? 'All Android Devices' : 'All iOS Devices'));

    final modalTitle = isDirect ? 'Confirm Direct Notification' : 'Confirm Push Broadcast';
    final modalPrompt = isDirect
        ? 'Are you sure you want to send this direct notification to $targetUser? It will be pushed to their devices and delivered directly into their in-app inbox.'
        : 'Are you sure you want to broadcast this push notification immediately to all devices?';

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 10),
            Text(
              modalTitle,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              modalPrompt,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target: $targetLabel',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Get.back();
              pushController.sendBroadcast();
            },
            child: const Text(
              'SEND NOW',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String title, String hint) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          hint,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? counterText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.bgSurface,
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: TWTypography.uiFamily,
        color: AppColors.textTertiary,
        fontSize: 13,
      ),
      counterText: counterText,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  Widget _buildAudienceChoice({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteChip(BroadcastPushController pushController, String label, String route) {
    return ActionChip(
      backgroundColor: AppColors.bgSurface,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontSize: 11,
          color: AppColors.textPrimary,
        ),
      ),
      onPressed: () {
        pushController.actionUrlController.text = route;
        pushController.actionUrlRx.value = route;
      },
    );
  }

  Widget _buildDeviceTogglePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
