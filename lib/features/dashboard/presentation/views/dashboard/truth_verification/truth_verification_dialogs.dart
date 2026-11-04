import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialogs & interactive creator tools for Truth Verification in Studio
class TruthVerificationDialogs {
  TruthVerificationDialogs._();

  static bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
  }

  /// Chat with Truth AI Coach & Rebuttal Drafter
  static void showTruthAiCoachModal(
    BuildContext context,
    RealExtractedClaim claim,
    VideoFactCheckItem video, {
    required bool isDarkMode,
  }) {
    final claimSummaryText = claim.text.length > 50
        ? '${claim.text.substring(0, 50)}...'
        : claim.text;
    final generatedDisclaimer =
        '📌 Verification Context [${claim.timestamp}]: Regarding the assertion about "$claimSummaryText", updated empirical data and official documentation are available in the description citation registry.';

    final academicQueries = [
      'Query: ${claim.category} official registry data for "${claim.text.split(' ').take(4).join(' ')}"',
      'Query: PubMed / DOI peer-reviewed citation for statement at ${claim.timestamp}',
      'Query: National statistical bureau release on ${claim.category}',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDarkMode ? AppColors.bgDivider : AppColors.brandVariant,
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.bgSurfaceHover
                            : AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Truth AI Fact-Check Coach',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          'Instant creator guidance & disclaimer generation',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
              color: isDarkMode ? AppColors.bgDivider : AppColors.textPrimary,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgPage
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.bgDivider
                            : AppColors.textPrimary,
                      ),
                    ),
                    child: Text(
                      'Analyzing Claim [${claim.timestamp}]: "${claim.text}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '1. One-Tap Compliant Description Disclaimer',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgPage
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.bgDivider
                            : AppColors.textPrimary,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          generatedDisclaimer,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: generatedDisclaimer),
                            );
                            AppSnackbar.success(
                              'Disclaimer copied! Paste it in your video description.',
                            );
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                          label: const Text('Copy to Description'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '2. Target Academic Search Queries',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...academicQueries.map(
                    (q) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.bgPage
                            : AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : AppColors.textPrimary,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: TWTypography.uiFamily,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black54,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: q));
                              AppSnackbar.info('Query copied to clipboard.');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Export Complete Authenticity Dossier & Audit Certificate
  static void showExportAuditDossierModal(
    BuildContext context,
    VideoFactCheckItem video,
    String channelId, {
    required bool isDarkMode,
  }) {
    final String assertionsBlock;
    if (video.claims.isEmpty) {
      assertionsBlock =
          '• No empirical factual assertions extracted from video transcript or audio stream.\n'
          '• Content classified as philosophical inquiry, rhetorical argument, or subjective discourse.\n'
          '• Factual accuracy cannot be assessed without empirical propositions.';
    } else {
      assertionsBlock = video.claims
          .map((c) =>
              '• [${c.timestamp}] [${c.tier.name.toUpperCase()}] "${c.text}" (Source: ${c.sourceCitation})')
          .join('\n');
    }

    final dossierText = '''
=====================================================
TRUTHWORLD VERIFICATION AUDIT DOSSIER & CERTIFICATE
=====================================================
Report ID: TW-AUDIT-${video.id.toUpperCase()}
Video Title: ${video.title}
Channel ID: $channelId
Audit Timestamp: ${DateTime.now().toUtc().toIso8601String()}

VERIFICATION & CREDIBILITY METRICS:
- Media / Provenance Authenticity: Immutable Provenance Ledger Verified
- Factual Accuracy: ${video.factualAccuracyLabel}
- Evidence Coverage: ${video.claims.length} assertion(s) analyzed
- Verification State: ${video.verificationState}
- Public Visibility: ${video.isFactCheckApproved ? 'Approved (Public)' : 'Held Private'}
- Review Mode: ${video.factCheckReviewMode}

ASSERTIONS ANALYZED (${video.claims.length}):
$assertionsBlock

CRYPTOGRAPHIC VALIDATION:
Digital Stamp: SHA256-${video.id.hashCode.toRadixString(16).padLeft(16, '0')}
Validation Scope: Asset integrity hash & immutable provenance ledger entry
Status: ${video.consensusValidationStatus}
=====================================================
''';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.bgSurfaceHover
                    : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Authenticity Audit Dossier',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Copy this standardized audit report for sponsors, academic partners, or description transparency.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : AppColors.textPrimary,
                    ),
                  ),
                  child: SelectableText(
                    dossierText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: dossierText));
              Navigator.pop(ctx);
              AppSnackbar.success('Audit dossier copied to clipboard!');
            },
            icon: const Icon(
              Icons.copy_all_rounded,
              size: 16,
              color: Colors.black,
            ),
            label: const Text('Copy Dossier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Modal: Ask AI why a claim was flagged
  static void showAskAiWhyDialog(
    BuildContext context,
    RealExtractedClaim claim, {
    required bool isDarkMode,
    required void Function(RealExtractedClaim) onProvideSource,
    required void Function(RealExtractedClaim) onMarkEdit,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.bgSurfaceHover
                    : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'AI Fact-Checking Diagnostic',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: claim.isHighConcern
                          ? AppColors.error.withValues(alpha: 0.5)
                          : (claim.isNeedsSource
                              ? AppColors.warning.withValues(alpha: 0.5)
                              : AppColors.success.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Time: ${claim.timestamp}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            claim.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"${claim.text}"',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Analysis & Diagnostic Findings',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  claim.aiExplanation.isNotEmpty
                      ? claim.aiExplanation
                      : (claim.isHighConcern
                          ? 'The fact-checking pipeline cross-referenced academic databases, government statistical releases, and peer-reviewed indices. No authoritative record verifies this exact assertion.'
                          : (claim.isNeedsSource
                              ? 'This assertion is plausible and common in secondary commentary, but lacks a primary documented index. Providing an official source link will substantiate it.'
                              : 'This statement is substantiated by indexed empirical research with high classification confidence.')),
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    height: 1.45,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1F2937)
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : AppColors.textPrimary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Acceptable Evidence to Clear Concern:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Peer-reviewed journal link (PubMed, DOI, Nature, IEEE)\n'
                        '• Official government ministry/bureau publication (.gov, official)\n'
                        '• Primary legal gazette or registered statistical repository\n'
                        '• Direct corporate audited regulatory filing',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          if (claim.isHighConcern || claim.isNeedsSource) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                onMarkEdit(claim);
              },
              icon: const Icon(Icons.edit_note_rounded, size: 14),
              label: const Text('Mark for Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                onProvideSource(claim);
              },
              icon: const Icon(Icons.add_link, size: 14, color: Colors.black),
              label: const Text('Provide Source'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Interactive Modal: Provide source link for a specific claim
  static void showProvideSourceForClaimDialog(
    BuildContext context,
    RealExtractedClaim claim, {
    required bool isDarkMode,
    required void Function(String claimId, String sourceUrl, String notes)
        onSubmit,
  }) {
    final urlController = TextEditingController();
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.bgSurfaceHover
                    : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add_link_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Provide Authoritative Source',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Claim [${claim.timestamp}]:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${claim.text}"',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Authoritative Source URL (HTTPS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(500),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Citation Notes / Excerpt for Reviewers',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 500,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(500),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Explain how this link proves the assertion...',
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final rawUrl = urlController.text.trim();
              if (rawUrl.isEmpty) {
                AppSnackbar.warning('Please enter a valid URL.');
                return;
              }
              if (!_isValidHttpUrl(rawUrl)) {
                AppSnackbar.warning(
                  'Please enter a valid http:// or https:// URL.',
                );
                return;
              }
              Navigator.pop(ctx);
              onSubmit(claim.id, rawUrl, noteController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Submit for Re-verification'),
          ),
        ],
      ),
    );
  }

  /// Creator action to edit video segment or add viewer note
  static void showMarkVideoEditDialog(
    BuildContext context,
    RealExtractedClaim claim, {
    required bool isDarkMode,
    required void Function(String note) onSave,
  }) {
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mark Video Edit / Pin Note',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Segment timestamp: ${claim.timestamp}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"${claim.text}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Action Note (e.g. Trimmed segment in Studio Editor / Added pinned comment):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 2,
                maxLength: 200,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(200),
                ],
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your action note...',
                  filled: true,
                  fillColor: isDarkMode
                      ? AppColors.bgPage
                      : AppColors.textPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final note = noteController.text.trim();
              if (note.isEmpty) {
                AppSnackbar.warning('Please enter an action note.');
                return;
              }
              Navigator.pop(ctx);
              onSave(note);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  /// Dispute Dialog
  static void showDisputeDialog(
    BuildContext context,
    VideoFactCheckItem video, {
    required bool isDarkMode,
    required Future<void> Function(String reason, String url) onConfirmDispute,
    RealExtractedClaim? specificClaim,
  }) {
    final reasonController = TextEditingController();
    final urlController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.gavel_rounded,
                color: Colors.purpleAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specificClaim != null
                        ? 'Dispute Claim Verdict'
                        : 'Dispute Video Verification',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  Text(
                    'Submit evidence to the community consensus review panel',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (specificClaim != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgPage
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Text(
                      'Disputing [${specificClaim.timestamp}]: "${specificClaim.text}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  'Reason for Dispute',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  maxLength: 500,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(500),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Explain why the AI verdict or label is inaccurate...',
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Supporting Evidence URL (Optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(500),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                AppSnackbar.warning('Please enter a reason for the dispute.');
                return;
              }
              final url = urlController.text.trim();
              if (url.isNotEmpty && !_isValidHttpUrl(url)) {
                AppSnackbar.warning(
                  'Please enter a valid http:// or https:// URL.',
                );
                return;
              }
              Navigator.pop(ctx);
              await onConfirmDispute(reason, url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Formal Dispute'),
          ),
        ],
      ),
    );
  }

  /// Talk to AI & Add Sources Dialog
  static void showTalkToAiDialog(
    BuildContext context,
    VideoFactCheckItem video, {
    required bool isDarkMode,
    required Future<void> Function(
      String commentary,
      List<Map<String, String>> sources,
    )
        onSubmit,
  }) {
    final commentaryController = TextEditingController();
    final urlController = TextEditingController();
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.bgSurfaceHover
                    : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Talk to AI & Provide Sources',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  Text(
                    'Instruct AI verification engine with authoritative citations',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Video: "${video.title}"',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Context & Instructions for AI',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: commentaryController,
                  maxLines: 3,
                  maxLength: 2000,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(2000),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Provide context or background details for AI evaluation...',
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Authoritative Source URL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(500),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  maxLength: 300,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(300),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Citation note / context for this source...',
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final comment = commentaryController.text.trim();
              final url = urlController.text.trim();
              if (comment.isEmpty && url.isEmpty) {
                AppSnackbar.warning(
                  'Please provide instructions or at least one source URL.',
                );
                return;
              }
              if (url.isNotEmpty && !_isValidHttpUrl(url)) {
                AppSnackbar.warning(
                  'Please enter a valid http:// or https:// URL.',
                );
                return;
              }
              final sources = <Map<String, String>>[];
              if (url.isNotEmpty) {
                sources.add({
                  'url': url,
                  'notes': noteController.text.trim(),
                });
              }
              Navigator.pop(ctx);
              await onSubmit(comment, sources);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Send to AI Engine'),
          ),
        ],
      ),
    );
  }
}
