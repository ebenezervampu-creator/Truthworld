import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/video_card/video_card_avatar.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_header_widget.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated full-page screen displaying complete channel description, stats,
/// metadata, verified credentials, and social links for mobile-sized devices.
class ChannelDescriptionScreen extends StatelessWidget {
  const ChannelDescriptionScreen({
    this.channel,
    this.controller,
    super.key,
  });

  final Channel? channel;
  final ChannelController? controller;

  /// Navigates to the Channel Description full-page screen with smooth hierarchical transition.
  static Future<T?>? open<T>(
    BuildContext context, {
    required Channel channel,
    ChannelController? controller,
  }) {
    final effectiveChannelCtrl = controller ??
        (Get.isRegistered<ChannelController>(tag: channel.channelId)
            ? Get.find<ChannelController>(tag: channel.channelId)
            : (Get.isRegistered<ChannelController>()
                ? Get.find<ChannelController>()
                : null));

    return Get.to<T>(
      () => ChannelDescriptionScreen(
        channel: channel,
        controller: effectiveChannelCtrl,
      ),
      routeName: '${AppRoutes.channelDescription}?channelId=${channel.channelId}',
      arguments: {
        'channel': channel,
        'controller': effectiveChannelCtrl,
        'channelId': channel.channelId,
      },
      transition: Transition.rightToLeftWithFade,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve Channel instance from parameters or route arguments
    var resolvedChannel = channel;
    var resolvedController = controller;

    final args = Get.arguments;
    if (resolvedChannel == null && args is Channel) {
      resolvedChannel = args;
    } else if (args is Map) {
      if (resolvedChannel == null && args['channel'] is Channel) {
        resolvedChannel = args['channel'] as Channel;
      }
      if (resolvedController == null && args['controller'] is ChannelController) {
        resolvedController = args['controller'] as ChannelController;
      }
    }

    final targetChannelId = resolvedChannel?.channelId ??
        (args is Map ? args['channelId']?.toString() : null) ??
        Get.parameters['channelId'] ??
        Get.parameters['handle'] ??
        Get.parameters['id'];

    if (resolvedChannel == null && targetChannelId != null && targetChannelId.isNotEmpty) {
      if (Get.isRegistered<ChannelController>()) {
        final activeCtrl = Get.find<ChannelController>();
        final sel = activeCtrl.selectedChannel.value;
        if (sel != null &&
            (sel.channelId == targetChannelId ||
                sel.id == targetChannelId ||
                sel.handle == targetChannelId ||
                '@${sel.handle}' == targetChannelId)) {
          resolvedChannel = sel;
          resolvedController ??= activeCtrl;
        }
      }
    }

    // 2. Direct deep link fallback: retrieve channel document from Firestore
    if (resolvedChannel == null) {
      if (targetChannelId == null || targetChannelId.isEmpty) {
        return _buildErrorScaffold(context, 'Channel reference not found.');
      }
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('channels').doc(targetChannelId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold(context);
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorScaffold(context, 'Unable to load channel details.');
          }
          final dataMap = snapshot.data!.data() ?? <String, dynamic>{};
          final loadedChannel = Channel.fromMap(dataMap, snapshot.data!.id);
          return _buildAboutScaffold(
            context,
            channel: loadedChannel,
            controller: resolvedController,
          );
        },
      );
    }

    return _buildAboutScaffold(
      context,
      channel: resolvedChannel,
      controller: resolvedController,
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _handleBack(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                label: const Text('Go Back', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutScaffold(
    BuildContext context, {
    required Channel channel,
    ChannelController? controller,
  }) {
    final effectiveController = controller ??
        (Get.isRegistered<ChannelController>(tag: channel.channelId)
            ? Get.find<ChannelController>(tag: channel.channelId)
            : (Get.isRegistered<ChannelController>()
                ? Get.find<ChannelController>()
                : Get.put(ChannelController())));

    final allLinks = ChannelHeaderWidget.parseChannelLinks(channel);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
          tooltip: 'Back',
          onPressed: () => _handleBack(context),
        ),
        titleSpacing: 0,
        title: Text(
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Close',
            onPressed: () => _handleBack(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Channel Identity Card
            _buildChannelIdentityCard(context, channel, effectiveController),
            const SizedBox(height: 14),

            // 2. Metrics Bar (Subscribers, Videos, Views, Joined Date)
            _buildMetricsBar(context, channel, effectiveController),
            const SizedBox(height: 16),

            // 3. Full Description Container
            _buildDescriptionContainer(context, channel),
            const SizedBox(height: 16),

            // 4. Channel Links Section
            if (allLinks.isNotEmpty) ...[
              _buildLinksSection(context, allLinks),
              const SizedBox(height: 16),
            ],

            // 5. Channel Details / Metadata Card
            _buildMoreInfoSection(context, channel),

            // Bottom safe padding
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelIdentityCard(
    BuildContext context,
    Channel channel,
    ChannelController? channelCtrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          VideoCardAvatar(
            radius: 26,
            imageUrl: channel.avatarUrl,
            placeholderText: channel.channelName,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        channel.channelName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (channel.isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.brand,
                        size: 15,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  channel.handle.startsWith('@') ? channel.handle : '@${channel.handle}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(
    BuildContext context,
    Channel channel,
    ChannelController? channelCtrl,
  ) {
    final showSubscribers = channel.showSubscriberCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (showSubscribers) ...[
            Expanded(
              child: _buildMetricItem(
                value: FormatUtils.formatCount(channel.subscriberCount),
                label: channel.subscriberCount == 1 ? 'Subscriber' : 'Subscribers',
              ),
            ),
            _buildMetricDivider(),
          ],
          Expanded(
            child: channelCtrl != null
                ? Obx(() {
                    final count = channelCtrl.channelVideoCount.value > 0
                        ? channelCtrl.channelVideoCount.value
                        : channel.videoCount;
                    return _buildMetricItem(
                      value: count.toString(),
                      label: count == 1 ? 'Video' : 'Videos',
                    );
                  })
                : _buildMetricItem(
                    value: channel.videoCount.toString(),
                    label: channel.videoCount == 1 ? 'Video' : 'Videos',
                  ),
          ),
          _buildMetricDivider(),
          Expanded(
            child: _buildMetricItem(
              value: FormatUtils.formatCount(channel.metrics.totalViews),
              label: 'Total Views',
            ),
          ),
          _buildMetricDivider(),
          Expanded(
            child: _buildMetricItem(
              value: DateFormat('MMM yyyy').format(channel.createdAt.toDate()),
              label: 'Joined',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  Widget _buildDescriptionContainer(BuildContext context, Channel channel) {
    final hasDescription = channel.description.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          if (hasDescription)
            ClickableUrlText(
              text: channel.description,
              overflow: TextOverflow.visible,
              selectable: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.55,
              ),
            )
          else
            Text(
              'No description provided for this channel.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinksSection(BuildContext context, List<Map<String, dynamic>> links) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LINKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: links.map((link) {
              final title = (link['title'] ?? 'Link').toString();
              final display = (link['display'] ?? '').toString();
              final url = (link['url'] ?? '').toString();
              final icon = link['icon'] as IconData? ?? Icons.link_rounded;

              return InkWell(
                onTap: () => ClickableUrlText.launchUrlString(url),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: AppColors.brand),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (display.isNotEmpty && display != title) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($display)',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreInfoSection(BuildContext context, Channel channel) {
    final cleanHandle = channel.handle.replaceAll('@', '').trim();
    final channelShareUrl = 'https://truthworld.ai/@$cleanHandle';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MORE INFO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Share link tile
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: channelShareUrl));
              AppToast.info('Channel link copied to clipboard');
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 18, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      channelShareUrl,
                      style: TextStyle(
                        color: AppColors.textLink,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 16, color: Colors.white54),
                ],
              ),
            ),
          ),

          // Country
          if (channel.country.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 18, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    channel.country,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Category
          if (channel.category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    channel.category,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Joined Date
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Joined ${DateFormat('MMMM d, yyyy').format(channel.createdAt.toDate())}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBack(BuildContext context) {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'ChannelDescriptionScreen.handleBack',
      );
      Get.back();
    }
  }
}
