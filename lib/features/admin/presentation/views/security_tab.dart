import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class SecurityTab extends StatelessWidget {
  final AdminController controller;
  const SecurityTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.securityMetrics.isEmpty && !controller.isLoadingSecurity.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.fetchSecurityMetrics();
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              if (constraints.maxWidth > 850)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildUploadVelocityChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildAnomalyAlerts()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildUploadVelocityChart(),
                    const SizedBox(height: 24),
                    _buildAnomalyAlerts(),
                  ],
                ),
              const SizedBox(height: 32),
              if (constraints.maxWidth > 850)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAccountClusters()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildRateLimitControls()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildAccountClusters(),
                    const SizedBox(height: 24),
                    _buildRateLimitControls(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security & Fraud Detection',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Automated anti-abuse monitoring, botnet detection, and rate limits',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text(
              'Lockdown Mode',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Obx(
              () => Switch(
                value: controller.isLockdownMode.value,
                onChanged: (_) => controller.toggleLockdownMode(),
                activeColor: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadVelocityChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Velocity (Last 24h)',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hourly upload volume across all channels',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          Obx(() {
            final raw = controller.securityMetrics['hourlyUploads'];
            final hourlyUploads = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            final entries = hourlyUploads.entries.toList();

            if (entries.isEmpty) {
              return const SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'No upload traffic in the last 24 hours.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            final maxCount = entries.fold<int>(1, (max, e) {
              final val = (e.value is num) ? (e.value as num).toInt() : 0;
              return val > max ? val : max;
            });

            return SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(entries.length, (index) {
                  final entry = entries[index];
                  final count = (entry.value is num) ? (entry.value as num).toInt() : 0;
                  final factor = (count / maxCount).clamp(0.05, 1.0);
                  final height = factor * 140.0;

                  return Tooltip(
                    message: '${entry.key}: $count upload${count == 1 ? '' : 's'}',
                    child: Container(
                      width: 10,
                      height: height,
                      decoration: BoxDecoration(
                        color: count > 10 ? AppColors.error : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnomalyAlerts() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anomaly Alerts',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Detected unusual activity or abuse attempts',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final alerts = controller.anomalyAlerts;

            if (alerts.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Zero Anomaly Alerts',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No suspicious traffic patterns detected.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 12,
              ),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final title = alert['title'] ?? alert['type'] ?? 'Security Alert';
                final desc = alert['description'] ?? alert['details'] ?? 'Anomaly detected';

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    title: Text(
                      title.toString(),
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      desc.toString(),
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => controller.investigateAnomaly(alert),
                      child: const Text(
                        'Investigate',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAccountClusters() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Clusters',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coordinated account groups linked by IP or Device ID',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final clusters = controller.accountClusters;

            if (clusters.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hub_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Suspicious Clusters',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No coordinated multi-account bot networks identified.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clusters.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withValues(alpha: 0.08),
                height: 12,
              ),
              itemBuilder: (context, index) {
                final cluster = clusters[index];
                final name = cluster['name'] ?? 'Cluster #${index + 1}';
                final desc = cluster['description'] ?? '${cluster['accountCount'] ?? 0} accounts linked';

                return _buildClusterItem(cluster, name.toString(), desc.toString());
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClusterItem(Map<String, dynamic> cluster, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => controller.investigateAnomaly(cluster),
            child: const Text(
              'Investigate',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.info,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateLimitControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Obx(() {
        final isSaving = controller.isSavingRateLimits.value;
        final perUser = controller.perUserUploadRateLimit.value;
        final global = controller.globalUploadRateLimit.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate Limit Controls',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Global upload rate throttling configuration',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _buildRateLimitInput(
              label: 'Per-User (Uploads/hr)',
              currentVal: perUser,
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null && parsed > 0) {
                  controller.perUserUploadRateLimit.value = parsed;
                }
              },
            ),
            const SizedBox(height: 12),
            _buildRateLimitInput(
              label: 'Global (Uploads/min)',
              currentVal: global,
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null && parsed > 0) {
                  controller.globalUploadRateLimit.value = parsed;
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgSurface,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              onPressed: isSaving ? null : controller.saveRateLimits,
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Apply Changes',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildRateLimitInput({
    required String label,
    required int currentVal,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        SizedBox(
          width: 110,
          height: 36,
          child: TextFormField(
            key: ValueKey(currentVal),
            initialValue: currentVal.toString(),
            maxLength: 8,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
        ),
      ],
    );
  }
}

