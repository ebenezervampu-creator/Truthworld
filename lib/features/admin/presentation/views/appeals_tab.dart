import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AppealsTab extends StatefulWidget {
  final AdminController controller;
  const AppealsTab({required this.controller, super.key});

  @override
  State<AppealsTab> createState() => _AppealsTabState();
}

class _AppealsTabState extends State<AppealsTab> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final appeals = widget.controller.appeals;
      final isLoading = widget.controller.isLoadingAppeals.value;

      if (isLoading && appeals.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.textPrimary),
        );
      }

      if (appeals.isEmpty) {
        return _buildEmptyState();
      }

      // Auto-select first appeal if none selected
      if (widget.controller.selectedAppeal.value == null && appeals.isNotEmpty) {
        widget.controller.selectedAppeal.value = appeals.first;
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAppealsList(appeals),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _buildAppealDetail(),
                ),
              ],
            ],
          );
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      padding: const EdgeInsets.all(48),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gavel_rounded,
              size: 64,
              color: AppColors.textPrimary,
            ),
            SizedBox(height: 16),
            Text(
              'No Content Appeals',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'There are currently no submitted content appeals requiring review.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppealsList(List<Map<String, dynamic>> appeals) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: ListView.separated(
        itemCount: appeals.length,
        separatorBuilder: (context, index) =>
            const Divider(color: AppColors.bgDivider, height: 1),
        itemBuilder: (context, index) {
          final appeal = appeals[index];
          final appealId = appeal['appealId'] ?? appeal['id'] ?? 'N/A';
          final user = appeal['userEmail'] ?? appeal['userId'] ?? appeal['user'] ?? 'Unknown User';
          final status = (appeal['status'] as String? ?? 'pending').toLowerCase();
          final isSelected = widget.controller.selectedAppeal.value?['id'] == appeal['id'];

          Color statusColor;
          if (status == 'overturned') {
            statusColor = Colors.green;
          } else if (status == 'upheld') {
            statusColor = AppColors.error;
          } else if (status == 'escalated') {
            statusColor = Colors.orange;
          } else {
            statusColor = Colors.amber;
          }

          return Material(
            color: isSelected ? AppColors.bgElevated : Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                'Appeal #$appealId',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'User: $user',
                    style: const TextStyle(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.textPrimary),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(appeal['submittedAt'] ?? appeal['createdAt']),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor, width: 0.5),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textPrimary,
              ),
              onTap: () {
                widget.controller.selectedAppeal.value = appeal;
                _reasonController.clear();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppealDetail() {
    final appeal = widget.controller.selectedAppeal.value;
    if (appeal == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Text(
            'Select an appeal to view details.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    final appealId = appeal['appealId'] ?? appeal['id'] ?? 'N/A';
    final category = appeal['category'] ?? appeal['violationCategory'] ?? appeal['contentDescription'] ?? 'N/A';
    final confidence = appeal['aiConfidence'] != null ? '${(appeal['aiConfidence'] * 100).toInt()}%' : 'N/A';
    final statement = appeal['appealReason'] ?? appeal['reason'] ?? appeal['statement'] ?? 'No statement provided.';
    final status = (appeal['status'] as String? ?? 'pending').toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Appeal Details (#$appealId)',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text(
                    'Status: $status',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildCard(
                              'Original Content & AI Analysis',
                              'Category: $category\nAI Confidence: $confidence',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCard(
                              "Creator's Appeal Statement",
                              '"$statement"',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCard(
                            'Original Content & AI Analysis',
                            'Category: $category\nAI Confidence: $confidence',
                          ),
                          const SizedBox(height: 16),
                          _buildCard(
                            "Creator's Appeal Statement",
                            '"$statement"',
                          ),
                        ],
                      );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Resolution Reason',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for decision...',
                hintStyle: const TextStyle(color: AppColors.textPrimary),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: () {
                    widget.controller.resolveAppeal(
                      appealId,
                      'uphold',
                      _reasonController.text.trim(),
                    );
                  },
                  child: const Text(
                    'Uphold Rejection',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    widget.controller.resolveAppeal(
                      appealId,
                      'overturn',
                      _reasonController.text.trim(),
                    );
                  },
                  child: const Text(
                    'Overturn (Restore)',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                  onPressed: () {
                    widget.controller.resolveAppeal(
                      appealId,
                      'escalate',
                      _reasonController.text.trim(),
                    );
                  },
                  child: const Text('Escalate to Senior'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    if (timestamp is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    return timestamp.toString();
  }
}
