import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section detailing statutory MCA corporate identity and IT Rules grievance officer details.
class AboutCorporateAndGrievanceSection extends StatelessWidget {
  const AboutCorporateAndGrievanceSection({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    super.key,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    final corporateInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CORPORATE IDENTITY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 18),
        _buildInfoRow('Legal Entity', 'TOWERVSP SERVICES (OPC) PRIVATE LIMITED'),
        _buildInfoRow('CIN', 'U63111TS2025OPC207488'),
        _buildInfoRow('Incorporation Date', 'December 10, 2025'),
        _buildInfoRow('RoC Jurisdiction', 'RoC Hyderabad, Telangana, India'),
        _buildInfoRow(
          'Registered Office',
          'Ramaram, Yadadri Bhuvanagiri, Telangana - 508116',
        ),
        _buildInfoRow(
          'Status',
          'Active (Registered with MCA, Govt. of India)',
          isStatus: true,
        ),
      ],
    );

    final grievanceInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATUTORY GRIEVANCE & SUPPORT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 18),
        _buildInfoRow('Grievance Officer', 'Vampu Ebenezer'),
        _buildInfoRow('Grievance Email', 'hello@truthworld.in'),
        _buildInfoRow('Customer Support', 'hello@truthworld.in'),
        _buildInfoRow('Business Contact', '+91 9390617877'),
        _buildInfoRow('Support Hours', 'Mon – Fri, 9:00 AM – 6:00 PM IST'),
        _buildInfoRow('Compliance', 'IT (Intermediary Guidelines) Rules, 2021'),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Corporate & Legal Information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Official entity registration, compliance details, and grievance redressal channels.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 44),
          Container(
            constraints: const BoxConstraints(maxWidth: 860),
            padding: EdgeInsets.all(isDesktop ? 36 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: isDesktop || isTablet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: corporateInfo),
                      const SizedBox(width: 40),
                      Expanded(child: grievanceInfo),
                    ],
                  )
                : Column(
                    children: [
                      corporateInfo,
                      const SizedBox(height: 28),
                      const Divider(color: AppColors.bgDivider),
                      const SizedBox(height: 28),
                      grievanceInfo,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String val, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.success),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              val,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
