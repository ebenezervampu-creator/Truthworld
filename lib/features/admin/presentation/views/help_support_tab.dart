import 'package:flutter/material.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class HelpSupportTab extends StatelessWidget {
  final AdminController controller;
  const HelpSupportTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Card
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1A1A2E),
                  AppColors.bgSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Help & Support Center',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Everything you need to manage the Truthworld moderation portal effectively.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900
                  ? 3
                  : (constraints.maxWidth > 500 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: cols > 2 ? 2.0 : (cols > 1 ? 1.8 : 3.0),
                children: [
                  _buildQuickGuideCard(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard Overview',
                    description:
                        'View real-time platform health, pending queue counts, and recent moderation activity at a glance.',
                    color: const Color(0xFF4CAF50),
                  ),
                  _buildQuickGuideCard(
                    icon: Icons.video_library_outlined,
                    title: 'Video Moderation',
                    description:
                        'Review AI-analyzed videos. Use the embedded player and our verification system analysis to approve or reject content.',
                    color: const Color(0xFF2196F3),
                  ),
                  _buildQuickGuideCard(
                    icon: Icons.image_outlined,
                    title: 'Image Moderation',
                    description:
                        'Review flagged images with SafeSearch scores. Each image shows Adult, Racy, Violence, Medical, and Spoof ratings.',
                    color: const Color(0xFFFF9800),
                  ),
                  _buildQuickGuideCard(
                    icon: Icons.account_circle_outlined,
                    title: 'Channel Verification',
                    description:
                        'Review channel registrations analyzed by our Verification System for policy compliance on names, descriptions, and tags.',
                    color: const Color(0xFF9C27B0),
                  ),
                  _buildQuickGuideCard(
                    icon: Icons.report_gmailerrorred_rounded,
                    title: 'Video Reports',
                    description:
                        'Review user-submitted video reports. Dismiss false reports or reject and quarantine violating videos.',
                    color: const Color(0xFFE91E63),
                  ),
                  _buildQuickGuideCard(
                    icon: Icons.people_outline_rounded,
                    title: 'User Management',
                    description:
                        'Search users, view trust scores and strike history. Warn, suspend, or ban accounts that violate policies.',
                    color: const Color(0xFF00BCD4),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Moderation Workflow Guide
          _buildSectionCard(
            title: 'Moderation Workflow',
            icon: Icons.route_rounded,
            children: [
              _buildStep(
                '1',
                'Content Uploaded',
                'User uploads a video, image, or creates a channel on Truthworld.',
              ),
              _buildStep(
                '2',
                'AI Pre-Screening',
                'Our Verification System automatically analyzes videos, channels, and images for policy compliance.',
              ),
              _buildStep(
                '3',
                'Auto Decision',
                'Content is auto-approved (safe), auto-rejected (clear violation), or flagged for manual review (borderline).',
              ),
              _buildStep(
                '4',
                'Admin Review',
                'Flagged items appear in your moderation queues. Review AI analysis and make the final decision.',
              ),
              _buildStep(
                '5',
                'Action Applied',
                'Approved: content goes live. Rejected: content quarantined, user trust score updated, audit log created.',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Trust Scoring Guide
          _buildSectionCard(
            title: 'Trust Score System',
            icon: Icons.shield_outlined,
            children: [
              _buildTrustTierRow(
                'HIGH',
                '≥ 75',
                const Color(0xFF4CAF50),
                '15% of uploads scanned by Vision AI (cost savings)',
              ),
              _buildTrustTierRow(
                'MEDIUM',
                '40 – 74',
                const Color(0xFFFF9800),
                '50% of uploads scanned',
              ),
              _buildTrustTierRow(
                'LOW',
                '10 – 39',
                const Color(0xFFFF5722),
                '100% of uploads scanned',
              ),
              _buildTrustTierRow(
                'NEW',
                '< 40',
                const Color(0xFF9E9E9E),
                '100% of uploads scanned (new users)',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score Changes',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Content Approved:  +2 points',
                      style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                    ),
                    Text(
                      '• Content Flagged:   -5 points',
                      style: TextStyle(color: Color(0xFFFF9800), fontSize: 12),
                    ),
                    Text(
                      '• Content Rejected: -15 points + strike',
                      style: TextStyle(color: Color(0xFFFF5722), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Escalation Tiers
          _buildSectionCard(
            title: 'Escalation Tiers',
            icon: Icons.trending_up_rounded,
            children: [
              _buildEscalationTier(
                'Tier 1',
                'Auto-Handled',
                'Content within normal thresholds is auto-approved or auto-rejected.',
                const Color(0xFF4CAF50),
              ),
              _buildEscalationTier(
                'Tier 2',
                'Standard Review',
                'Borderline content flagged for regular admin queue review.',
                const Color(0xFF2196F3),
              ),
              _buildEscalationTier(
                'Tier 3',
                'Senior Review',
                'Extreme scores or repeat offenders. Requires senior admin action.',
                const Color(0xFFFF9800),
              ),
              _buildEscalationTier(
                'Tier 4',
                'Emergency',
                'Potential CSAM/terrorism. Immediate quarantine + law enforcement.',
                const Color(0xFFFF1744),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Keyboard Shortcuts
          _buildSectionCard(
            title: 'Quick Reference',
            icon: Icons.keyboard_rounded,
            children: [
              _buildRefRow('API Region', 'asia-south1 (Mumbai)'),
              _buildRefRow(
                'Storage Bucket',
                'truthworld-1.firebasestorage.app',
              ),
              _buildRefRow('Admin Portal URL', 'truthworld-1-admin.web.app'),
              _buildRefRow(
                'Quarantine Path',
                '_quarantine/rejected/YYYY-MM-DD/',
              ),
              _buildRefRow(
                'Image Hash Registry',
                'imageHashes collection (MD5 + pHash)',
              ),
              _buildRefRow('Max Queue Fetch', '100 items per collection'),
              _buildRefRow(
                'Rate Limits',
                '100 uploads/hour, 1000/day per user',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Contact Support
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need More Help?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'For technical issues, emergency escalations, or platform incidents, contact the engineering team directly.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'ebenezervampu4@gmail.com',
                        style: TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuickGuideCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF42A5F5),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustTierRow(
    String tier,
    String range,
    Color color,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                tier,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              range,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationTier(
    String tier,
    String label,
    String desc,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$tier — ',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
