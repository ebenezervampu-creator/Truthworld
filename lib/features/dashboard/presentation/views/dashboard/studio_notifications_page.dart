import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/fcm_notification_service.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';

class StudioNotificationsPage extends StatefulWidget {
  const StudioNotificationsPage({super.key});

  @override
  State<StudioNotificationsPage> createState() => _StudioNotificationsPageState();
}

class _StudioNotificationsPageState extends State<StudioNotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxMap<String, dynamic> notificationSettings = <String, dynamic>{
    'publishingAlerts': true,
    'communityAlerts': true,
    'monetizationAlerts': true,
    'copyrightAlerts': true,
  }.obs;

  final RxBool isLoadingSettings = true.obs;

  late final UserNotificationController _notificationController;

  @override
  void initState() {
    super.initState();
    _notificationController = Get.isRegistered<UserNotificationController>()
        ? Get.find<UserNotificationController>()
        : Get.put(UserNotificationController());
    _loadNotificationSettings();
  }

  IconData _getIconForNotification(UserNotification notification) {
    switch (notification.type.toLowerCase()) {
      case 'milestone_achieved':
        return Icons.insights_rounded;
      case 'trust_score_change':
        return Icons.verified_user_rounded;
      case 'tier_promotion':
        return Icons.trending_up_rounded;
      case 'tier_downgrade':
        return Icons.trending_down_rounded;
      case 'inactivity_warning':
      case 'performance_warning':
        return Icons.warning_rounded;
      case 'system_announcement':
        return Icons.announcement_rounded;
      case 'comment_like':
        return Icons.favorite_rounded;
      case 'comment_reply':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.flash_on_rounded;
    }
  }

  Color _getColorForNotification(UserNotification notification) {
    switch (notification.severity) {
      case NotificationSeverity.success:
        return const Color(0xFF10B981);
      case NotificationSeverity.warning:
        return const Color(0xFFEF4444);
      case NotificationSeverity.priority:
        return const Color(0xFFEC4899);
      case NotificationSeverity.info:
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  Future<void> _loadNotificationSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      isLoadingSettings.value = false;
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('studio_notification_settings')) {
          final settings = data['studio_notification_settings'] as Map<String, dynamic>;
          notificationSettings.addAll(settings);
        }
      }
    } catch (e) {
      debugPrint('Error loading creator settings: $e');
    } finally {
      isLoadingSettings.value = false;
    }
  }

  Future<void> _updateSetting(String key, bool val) async {
    final user = _auth.currentUser;
    if (user == null) return;

    notificationSettings[key] = val;
    HapticFeedback.lightImpact();

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'studio_notification_settings': Map<String, dynamic>.from(notificationSettings),
      }, SetOptions(merge: true));

      Get.snackbar(
        'Preferences Saved',
        'Notification alerts updated successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E1B4B),
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A1C),
      body: RefreshIndicator(
        color: const Color(0xFFEC4899),
        backgroundColor: const Color(0xFF16132D),
        onRefresh: () => _notificationController.refreshNotifications(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeaderSliver(),
            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverToBoxAdapter(
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildAlertsStreamList()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildPushControllerSidebar()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildPushControllerSidebar(),
                          const SizedBox(height: 24),
                          _buildAlertsStreamList(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSliver() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 140,
      backgroundColor: const Color(0xFF0F0F1A),
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6366F1).withOpacity(0.12),
                const Color(0xFFEC4899).withOpacity(0.08),
                const Color(0xFF0C0A1C),
              ],
            ),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Studio Alerts & Notifications',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your channel publishing pipeline, copyright checks, and real-time push subscriptions.',
              style: GoogleFonts.roboto(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPushControllerSidebar() {
    final fcmService = Get.find<FcmNotificationService>();

    return Obx(() {
      final status = fcmService.permissionStatus.value;
      final token = fcmService.fcmToken.value;
      final isInit = fcmService.isInitializing.value;

      Color borderGlow = (status == 'granted' ? const Color(0xFFEC4899) : Colors.white10);
      Color statusColor = status == 'granted' ? const Color(0xFF10B981) : (status == 'denied' ? const Color(0xFFEF4444) : Colors.grey);
      String statusTitle = status == 'granted' ? 'Alerts Active' : (status == 'denied' ? 'Alerts Blocked' : 'Push Inactive');

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderGlow.withOpacity(0.15), width: 1.5),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF16132D),
              Color(0xFF0F0F1A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Color(0xFFEC4899), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'FCM WEB PUSH DASHBOARD',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Push Permission: ',
                    style: GoogleFonts.roboto(color: Colors.white60, fontSize: 12),
                  ),
                  Text(
                    statusTitle,
                    style: GoogleFonts.roboto(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Spacer(),
                  if (status != 'granted') ...[
                    ElevatedButton(
                      onPressed: isInit ? null : () => fcmService.requestPushPermission(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isInit
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Setup', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.do_not_disturb_on_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => fcmService.removeFcmToken(),
                      tooltip: 'Disable on this device',
                    ),
                  ],
                ],
              ),
            ),
            if (token.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STUDIO DEVICE REGISTRATION TOKEN',
                    style: GoogleFonts.roboto(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: token));
                      Get.snackbar(
                        'Token Copied',
                        'Studio FCM token copied successfully.',
                        backgroundColor: const Color(0xFFEC4899),
                        colorText: Colors.white,
                      );
                    },
                    child: const Text(
                      'COPY TOKEN',
                      style: TextStyle(color: Color(0xFFEC4899), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  token,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white60, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              'CREATOR ALERTS SUBSCRIPTIONS',
              style: GoogleFonts.roboto(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Toggle alert tags that you want pushed to this active browser using dynamic FCM delivery.',
              style: GoogleFonts.roboto(color: Colors.white30, fontSize: 10),
            ),
            const SizedBox(height: 16),
            isLoadingSettings.value
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Color(0xFFEC4899))))
                : Column(
                    children: [
                      _buildSubscriptionTile(
                        'Video Ready Notifications',
                        'Get notified when HD/4K resolution conversion completes.',
                        'publishingAlerts',
                      ),
                      _buildSubscriptionTile(
                        'Community Responses',
                        'Get notified when subscribers submit comments or answers.',
                        'communityAlerts',
                      ),
                      _buildSubscriptionTile(
                        'Payout & Tips Alerts',
                        'Get alerts when premium tips or channel valuations increase.',
                        'monetizationAlerts',
                      ),
                      _buildSubscriptionTile(
                        'Copyright Status Updates',
                        'Critical notifications on copyright and content protection checks.',
                        'copyrightAlerts',
                      ),
                    ],
                  ),
          ],
        ),
      );
    });
  }

  Widget _buildSubscriptionTile(String title, String subtitle, String key) {
    return Obx(() {
      final value = notificationSettings[key] as bool? ?? false;
      return SwitchListTile.adaptive(
        activeTrackColor: const Color(0xFFEC4899),
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: GoogleFonts.roboto(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.roboto(color: Colors.white30, fontSize: 10)),
        value: value,
        onChanged: (val) => _updateSetting(key, val),
      );
    });
  }

  Widget _buildAlertsStreamList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        color: const Color(0xFF110E23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE CREATOR ALERTS CENTER',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_rounded, color: Color(0xFF6366F1), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'REALTIME SYNC',
                      style: TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Obx(() {
            if (_notificationController.isLoading.value &&
                _notificationController.notifications.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFFEC4899)),
                ),
              );
            }

            final alerts = _notificationController.notifications;
            if (alerts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.notifications_off_outlined,
                          color: Colors.white24, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'No alerts found',
                        style: GoogleFonts.roboto(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white10, height: 20),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertTile(alert);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertTile(UserNotification alert) {
    Color itemColor = _getColorForNotification(alert);
    IconData icon = _getIconForNotification(alert);
    bool isRead = alert.read;
    String timeAgo = _formatTimeAgo(alert.createdAt);

    return InkWell(
      onTap: () {
        _notificationController.markAsRead(alert.id);
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: itemColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.roboto(
                          color: Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.message,
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alert.type.toUpperCase(),
                          style: GoogleFonts.roboto(
                              color: Colors.white30,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEC4899),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
