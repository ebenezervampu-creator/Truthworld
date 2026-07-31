import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class FeedbacksTab extends StatefulWidget {
  final AdminController controller;
  const FeedbacksTab({super.key, required this.controller});

  @override
  State<FeedbacksTab> createState() => _FeedbacksTabState();
}

class _FeedbacksTabState extends State<FeedbacksTab> {
  final RxList<Map<String, dynamic>> feedbacks = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedFeedback = Rxn<Map<String, dynamic>>();
  final RxBool isLoading = true.obs;
  final RxString filterType = 'All'.obs;
  final RxString filterStatus = 'All'.obs;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    isLoading.value = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      feedbacks.value = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      isLoading.value = false;
    } catch (e) {
      debugPrint('Error loading feedbacks: $e');
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredFeedbacks {
    return feedbacks.where((fb) {
      if (filterType.value != 'All' && fb['feedbackType'] != filterType.value) return false;
      if (filterStatus.value != 'All' && fb['status'] != filterStatus.value) return false;
      return true;
    }).toList();
  }

  String _formatTimestamp(dynamic val) {
    if (val == null) return 'N/A';
    DateTime? dt;
    if (val is Timestamp) {
      dt = val.toDate();
    } else if (val is String) {
      dt = DateTime.tryParse(val);
    }
    if (dt == null) return 'N/A';
    return DateFormat('MMM dd, yyyy · HH:mm').format(dt);
  }

  Future<void> _updateFeedbackStatus(String id, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('feedback').doc(id).update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await _loadFeedbacks();
      if (selectedFeedback.value != null && selectedFeedback.value!['id'] == id) {
        selectedFeedback.value = feedbacks.firstWhere((f) => f['id'] == id, orElse: () => selectedFeedback.value!);
      }
    } catch (e) {
      debugPrint('Error updating feedback status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        // Filter bar
        _buildFilterBar(),
        const Divider(color: AppColors.bgDivider, height: 1),
        // Content
        Expanded(
          child: Obx(() {
            final loading = isLoading.value;
            final selected = selectedFeedback.value;
            if (loading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));
            }
            return isDesktop
                ? Row(
                    children: [
                      Expanded(flex: 2, child: _buildFeedbackList()),
                      if (selected != null) ...[
                        const VerticalDivider(color: AppColors.bgDivider, width: 1),
                        Expanded(flex: 3, child: _buildFeedbackDetail()),
                      ],
                    ],
                  )
                : selected != null
                    ? _buildFeedbackDetail()
                    : _buildFeedbackList();
          }),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final types = ['All', 'Bug', 'Feature Request', 'General', 'Other'];
    final statuses = ['All', 'new', 'reviewed', 'resolved', 'archived'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.bgSurface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            // Type filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: Obx(() => DropdownButton<String>(
                  value: filterType.value,
                  dropdownColor: AppColors.bgElevated,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => filterType.value = v ?? 'All',
                )),
              ),
            ),
            const SizedBox(width: 12),
            // Status filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: Obx(() => DropdownButton<String>(
                  value: filterStatus.value,
                  dropdownColor: AppColors.bgElevated,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s == 'new' ? 'New' : s[0].toUpperCase() + s.substring(1)))).toList(),
                  onChanged: (v) => filterStatus.value = v ?? 'All',
                )),
              ),
            ),
            const SizedBox(width: 20),
            // Count
            Text(
              '${filteredFeedbacks.length} feedback${filteredFeedbacks.length != 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: _loadFeedbacks,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackList() {
    return Obx(() {
      final items = filteredFeedbacks;
      if (items.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.feedback_outlined, color: AppColors.textTertiary, size: 48),
              SizedBox(height: 16),
              Text('No feedback found', style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(0),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.bgDivider, height: 1),
      itemBuilder: (context, index) {
        final fb = items[index];
        final isSelected = selectedFeedback.value?['id'] == fb['id'];
        final type = fb['feedbackType'] ?? 'General';
        final status = fb['status'] ?? 'new';
        final rating = (fb['rating'] as num?)?.toInt() ?? 0;

        return Material(
          color: isSelected ? AppColors.bgElevated : Colors.transparent,
          child: InkWell(
            onTap: () => selectedFeedback.value = fb,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  // Type icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _typeColor(type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_typeIcon(type), color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fb['userEmail'] ?? 'Anonymous',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fb['feedbackText'] ?? '',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(type, style: TextStyle(color: _typeColor(type), fontSize: 11, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            if (rating > 0) ...[
                              ...List.generate(rating, (_) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12)),
                              ...List.generate(5 - rating, (_) => Icon(Icons.star_outline_rounded, color: AppColors.textTertiary, size: 12)),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                _formatTimestamp(fb['timestamp']),
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          ),
      },
    );
    });
  }

  Widget _buildFeedbackDetail() {
    final fb = selectedFeedback.value!;
    final type = fb['feedbackType'] ?? 'General';
    final status = fb['status'] ?? 'new';
    final rating = (fb['rating'] as num?)?.toInt() ?? 0;
    final attachments = (fb['attachments'] as List<dynamic>?) ?? [];
    final deviceInfo = fb['deviceInfo'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button for mobile
          if (MediaQuery.of(context).size.width <= 900)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: () => selectedFeedback.value = null,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                label: const Text('Back to list', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _typeColor(type).withValues(alpha: 0.2),
                      child: Text(
                        (fb['userEmail'] ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fb['userEmail'] ?? 'Anonymous',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User ID: ${fb['userId'] ?? 'N/A'}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 16),
                // Type + Rating + Time
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildDetailChip(type, _typeIcon(type), _typeColor(type)),
                    if (rating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(rating, (_) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16)),
                          ...List.generate(5 - rating, (_) => Icon(Icons.star_outline_rounded, color: AppColors.textTertiary, size: 16)),
                        ],
                      ),
                    Text(_formatTimestamp(fb['timestamp']), style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    if (fb['appVersion'] != null)
                      Text('v${fb['appVersion']}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Feedback Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Feedback Message', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Text(
                  fb['feedbackText'] ?? 'No message provided.',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attachments
          if (attachments.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attachments (${attachments.length})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: attachments.map<Widget>((url) {
                      final imgUrl = StorageUtils.getFastDownloadUrl(url.toString());
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(imgUrl, width: 120, height: 120, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.broken_image_outlined, color: Colors.white, size: 32),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Device Info
          if (deviceInfo != null && deviceInfo.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Device Information', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  ...deviceInfo.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text('${e.key}: ', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                        Text('${e.value}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (status == 'new')
                _buildActionButton('Mark Reviewed', Icons.check_circle_outline, const Color(0xFF2196F3), () => _updateFeedbackStatus(fb['id'], 'reviewed')),
              if (status != 'resolved')
                _buildActionButton('Resolve', Icons.done_all_rounded, const Color(0xFF2BA640), () => _updateFeedbackStatus(fb['id'], 'resolved')),
              if (status != 'archived')
                _buildActionButton('Archive', Icons.archive_outlined, AppColors.textTertiary, () => _updateFeedbackStatus(fb['id'], 'archived')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDetailChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'new':
        color = const Color(0xFF4CAF50);
        break;
      case 'reviewed':
        color = const Color(0xFF2196F3);
        break;
      case 'resolved':
        color = const Color(0xFF9E9E9E);
        break;
      case 'archived':
        color = const Color(0xFF616161);
        break;
      default:
        color = const Color(0xFF4CAF50);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Bug':
        return Icons.bug_report_outlined;
      case 'Feature Request':
        return Icons.lightbulb_outline_rounded;
      case 'Other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Bug':
        return const Color(0xFFFF6B6B);
      case 'Feature Request':
        return const Color(0xFF42A5F5);
      case 'Other':
        return const Color(0xFFFFB800);
      default:
        return const Color(0xFF4CAF50);
    }
  }
}
