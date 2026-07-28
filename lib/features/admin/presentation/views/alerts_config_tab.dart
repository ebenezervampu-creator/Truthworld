import 'package:flutter/material.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AlertsConfigTab extends StatelessWidget {
  final AdminController controller;
  const AlertsConfigTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveAlertsPanel(),
              const SizedBox(height: 32),
              _buildAlertRulesPanel(),
              const SizedBox(height: 32),
              _buildEscalationTiersPanel(),
            ],
          ),
        );
      }
    );
  }

  Widget _buildActiveAlertsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Active Alerts', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              final severities = ['Critical', 'High', 'Medium'];
              final colors = [AppColors.error, Colors.orange, Colors.amber];
              return Card(
                color: AppColors.bgElevated,
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.warning, color: colors[index]),
                    title: Text('Spam Spike Detected in Region ${index + 1}', style: const TextStyle(color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                    subtitle: Text('Threshold exceeded by ${(index + 1) * 15}%', style: const TextStyle(color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                    trailing: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Chip(
                        label: Text(severities[index], style: TextStyle(color: colors[index])),
                        backgroundColor: colors[index].withOpacity(0.1),
                        side: BorderSide(color: colors[index]),
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildAlertRulesPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alert Rules Configuration', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildAlertRuleItem('Queue Backlog Alert', '500 items', true),
          const Divider(color: AppColors.bgDivider),
          _buildAlertRuleItem('Repeat Offender Alert', '3 strikes/day', true),
          const Divider(color: AppColors.bgDivider),
          _buildAlertRuleItem('Auto-approval Drop Alert', '< 75% rate', false),
        ],
      ),
    );
  }

  Widget _buildAlertRuleItem(String ruleName, String threshold, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ruleName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Threshold: ', style: TextStyle(color: AppColors.textSecondary)),
                  SizedBox(
                    width: 120,
                    height: 32,
                    child: TextField(
                      controller: TextEditingController(text: threshold),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(label: const Text('Push', style: TextStyle(color: AppColors.textPrimary)), onSelected: (_) {}, selected: true, selectedColor: AppColors.brand.withOpacity(0.3), backgroundColor: AppColors.bgElevated),
                  FilterChip(label: const Text('Email', style: TextStyle(color: AppColors.textPrimary)), onSelected: (_) {}, selected: false, backgroundColor: AppColors.bgElevated),
                  FilterChip(label: const Text('Slack', style: TextStyle(color: AppColors.textPrimary)), onSelected: (_) {}, selected: true, selectedColor: AppColors.brand.withOpacity(0.3), backgroundColor: AppColors.bgElevated),
                ],
              ),
              const SizedBox(width: 12),
              Switch(
                value: enabled,
                onChanged: (val) {},
                activeColor: AppColors.brand,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationTiersPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escalation Tiers', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTierItem('Tier 1: Automated', 'Handled by AI model, auto-approved/rejected based on clear guidelines.'),
          _buildTierItem('Tier 2: Junior Mod', 'Appeals and borderline cases requiring human review.'),
          _buildTierItem('Tier 3: Senior Mod', 'Complex cases, VIP accounts, and high-severity violations.'),
          _buildTierItem('Tier 4: Admin/Legal', 'Law enforcement requests, severe illegal content, platform-wide threats.'),
        ],
      ),
    );
  }

  Widget _buildTierItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
