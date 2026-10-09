import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section detailing global corporate identity, worldwide intermediary safe harbors
/// (US Section 230 & DMCA, EU Digital Services Act & GDPR, India Section 79 IT Act),
/// epistemic public trust architecture, and international grievance redressal channels.
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
            'Global corporate identity, worldwide statutory safe harbors (US CDA 230, EU DSA, India IT Act), and international grievance channels.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 44),
          Container(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              children: [
                if (isDesktop || isTablet) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCard(_buildCorporateCard())),
                      const SizedBox(width: 24),
                      Expanded(child: _buildCard(_buildGrievanceCard())),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCard(_buildPublicTrustCard())),
                      const SizedBox(width: 24),
                      Expanded(child: _buildCard(_buildLegalDefenseCard())),
                    ],
                  ),
                ] else ...[
                  _buildCard(_buildCorporateCard()),
                  const SizedBox(height: 20),
                  _buildCard(_buildGrievanceCard()),
                  const SizedBox(height: 20),
                  _buildCard(_buildPublicTrustCard()),
                  const SizedBox(height: 20),
                  _buildCard(_buildLegalDefenseCard()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget content) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: content,
    );
  }

  Widget _buildCardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorporateCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(Icons.account_balance_outlined, 'GLOBAL CORPORATE IDENTITY'),
        const SizedBox(height: 18),
        _buildInfoRow('Legal Entity', 'TOWERVSP SERVICES (OPC) PRIVATE LIMITED'),
        _buildInfoRow('CIN', 'U63111TS2025OPC207488'),
        _buildInfoRow('Global Scope', 'Operating worldwide (truthworld.in) across 70+ languages'),
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
  }

  Widget _buildGrievanceCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(Icons.gavel_rounded, 'GLOBAL COMPLIANCE & GRIEVANCE DIRECTORY'),
        const SizedBox(height: 18),
        _buildInfoRow('Global Grievance Officer', 'Vampu Ebenezer'),
        _buildInfoRow('Universal Legal Email', 'hello@truthworld.in'),
        _buildInfoRow('US DMCA Designated Agent', 'Vampu Ebenezer (hello@truthworld.in)'),
        _buildInfoRow('EU DSA Point of Contact', 'Articles 11/12 DSA Representative (hello@truthworld.in)'),
        _buildInfoRow('India Statutory Compliance', 'Rule 3(2) & 3(1)(j), IT (Intermediary Guidelines) Rules, 2021'),
        _buildInfoRow('International Response SLAs', '24h Acknowledgment • 72h Law Enforcement • 15d Dispute Resolution'),
      ],
    );
  }

  Widget _buildPublicTrustCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(Icons.verified_user_outlined, 'WORLDWIDE PUBLIC TRUST & EPISTEMIC INTEGRITY'),
        const SizedBox(height: 18),
        _buildInfoRow(
          'Claim-Level Grounding',
          'Decomposes content into timestamped atomic assertions rather than applying opaque binary "Fake/Real" stamps.',
        ),
        _buildInfoRow(
          'Universal Freedom of Conscience',
          'Theological assertions and subjective opinions are protected globally (US 1st Amendment, EU Charter Art. 10, India Art. 25) without empirical penalties.',
        ),
        _buildInfoRow(
          'Primary Source Grounding',
          'Direct citations to official Gazettes, peer-reviewed registries, and verified international wire services inside the player overlay.',
        ),
        _buildInfoRow(
          'Bilateral Natural Justice Recourse',
          'In-app dispute dialog (Audi Alteram Partem) with certified EU DSA Article 21 out-of-court dispute rights.',
        ),
      ],
    );
  }

  Widget _buildLegalDefenseCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(Icons.shield_outlined, 'TRI-CONTINENTAL INTERMEDIARY SAFE HARBOR'),
        const SizedBox(height: 18),
        _buildInfoRow(
          'United States Safe Harbor',
          'Full statutory immunity under Section 230 CDA (47 U.S.C. § 230) & Title 17 § 512 DMCA for third-party user uploads.',
        ),
        _buildInfoRow(
          'European Union & UK Safe Harbor',
          'Digital Services Act (Regulation 2022/2065, Arts. 6, 20, 21) hosting exemptions & GDPR cross-border SCC compliance.',
        ),
        _buildInfoRow(
          'India & APAC Safe Harbor',
          'Section 79 IT Act, 2000 intermediary immunity and BNS Section 356 good-faith public truth defense (Sec 499 IPC).',
        ),
        _buildInfoRow(
          'Non-Destructive Overlays',
          'Fact-checks operate strictly as informational transparency annotations (analogous to Community Notes), keeping raw videos intact worldwide.',
        ),
      ],
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
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}
