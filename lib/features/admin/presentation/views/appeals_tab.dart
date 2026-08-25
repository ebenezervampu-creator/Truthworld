import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AppealsTab extends StatelessWidget {
  final AdminController controller;
  const AppealsTab({required this.controller, super.key});

  TextEditingController get _reasonController => controller.appealReasonController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final appeals = controller.appeals;
      final isLoading = controller.isLoadingAppeals.value;

      if (isLoading && appeals.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.textPrimary),
        );
      }

      if (appeals.isEmpty) {
        return _buildEmptyState();
      }

      // Auto-select first appeal if none selected
      if (controller.selectedAppeal.value == null && appeals.isNotEmpty) {
        controller.selectedAppeal.value = appeals.first;
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(48),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gavel_rounded,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'No Content Appeals',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'There are currently no submitted content appeals requiring review.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListView.separated(
        itemCount: appeals.length,
        separatorBuilder: (context, index) =>
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        itemBuilder: (context, index) {
          final appeal = appeals[index];
          final appealId = appeal['appealId'] ?? appeal['id'] ?? 'N/A';
          final user = appeal['userEmail'] ?? appeal['userId'] ?? appeal['user'] ?? 'Unknown User';
          final status = (appeal['status'] as String? ?? 'pending').toLowerCase();
          final isSelected = controller.selectedAppeal.value?['id'] == appeal['id'];

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
            color: isSelected ? const Color(0xFF212121) : Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                'Appeal #$appealId',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
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
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(appeal['submittedAt'] ?? appeal['createdAt']),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor, width: 0.5),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
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
                color: Colors.white,
              ),
              onTap: () {
                controller.selectedAppeal.value = appeal;
                _reasonController.clear();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppealDetail() {
    final appeal = controller.selectedAppeal.value;
    if (appeal == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Text(
            'Select an appeal to view details.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
            ),
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    fontFamily: TWTypography.brandFamily,
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
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text(
                    'Status: $status',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
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
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
              ),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for decision...',
                hintStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                    controller.resolveAppeal(
                      appealId,
                      'uphold',
                      _reasonController.text.trim(),
                    );
                  },
                  child: const Text(
                    'Uphold Rejection',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    controller.resolveAppeal(
                      appealId,
                      'overturn',
                      _reasonController.text.trim(),
                    );
                  },
                  child: const Text(
                    'Overturn (Restore)',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                  onPressed: () {
                    controller.resolveAppeal(
                      appealId,
                      'escalate',
                      _reasonController.text.trim(),
                    );
                  },
                  child: const Text(
                    'Escalate to Senior',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                    ),
                  ),
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
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
            ),
          ),
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
