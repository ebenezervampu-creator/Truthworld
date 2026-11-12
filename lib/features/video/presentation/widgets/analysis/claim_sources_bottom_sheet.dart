import 'package:flutter/material.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 ClaimSourcesBottomSheet
///
/// Displays the comprehensive, verified sources list for a specific claim
/// matching the exact design specification:
/// - Circular institution/publisher avatars
/// - Publisher, title, domain link, and published date
/// - External launch action
/// - Fixed bottom action bar with "Search web" and "Provide source"
class ClaimSourcesBottomSheet extends StatelessWidget {
  final List<UISource> sources;
  final String claimText;
  final Video video;
  final Map<dynamic, dynamic>? initialClaim;

  const ClaimSourcesBottomSheet({
    required this.sources,
    required this.claimText,
    required this.video,
    this.initialClaim,
    super.key,
  });

  /// Opens the modal bottom sheet smoothly.
  static Future<T?> show<T>(
    BuildContext context, {
    required List<UISource> sources,
    required String claimText,
    required Video video,
    Map<dynamic, dynamic>? initialClaim,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClaimSourcesBottomSheet(
        sources: sources,
        claimText: claimText,
        video: video,
        initialClaim: initialClaim,
      ),
    );
  }

  Future<void> _launchSource(UISource source) async {
    final claimId = (initialClaim?['claimId'] ?? initialClaim?['id'])?.toString();
    await SourceUrlSanitizer.launchSourceUrl(
      url: source.url,
      title: source.title,
      publisher: source.publisher,
      domain: source.domain,
      source: source.toMap(),
      videoId: video.id.isNotEmpty ? video.id : null,
      claimId: claimId,
    );
  }

  Future<void> _searchWeb(BuildContext context) async {
    final query = claimText.trim();
    if (query.isEmpty) return;
    await SourceUrlSanitizer.launchWebSearch(query: query);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.78;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Top Drag Handle
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  'Sources',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${sources.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.bgDivider),

          // Scrollable Sources List
          Expanded(
            child: sources.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Verified source links are currently unavailable for this claim. TruthWorld only displays sources confirmed live.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    physics: const BouncingScrollPhysics(),
                    itemCount: sources.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 18,
                      thickness: 0.5,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final s = sources[index];
                      return _buildSourceItem(context, s);
                    },
                  ),
          ),

          // Fixed Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding > 0 ? bottomPadding : 16),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // 1. Search Web Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _searchWeb(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Search web',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Provide Source Button (Pure White background with Black text & icon - WCAG AA Compliant)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ClaimSourceSubmissionDialog.show(
                        context: context,
                        video: video,
                        initialClaim: initialClaim ?? {'claim': claimText, 'text': claimText},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black, // Enforces high contrast!
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_link_rounded,
                          size: 18,
                          color: Colors.black, // Strictly black on white
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Provide source',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Strictly black on white
                          ),
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
    );
  }

  Widget _buildSourceItem(BuildContext context, UISource s) {
    final effectivePublisher = (s.publisher != null && s.publisher!.isNotEmpty)
        ? s.publisher!
        : (s.domain != null && s.domain!.isNotEmpty ? s.domain! : 'Verified Organization');

    return InkWell(
      onTap: () => _launchSource(s),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Avatar
            SourceAvatarService.buildAvatar(
              domain: s.domain,
              publisher: s.publisher,
              url: s.url,
              avatarUrl: s.avatarUrl,
              size: 46,
            ),
            const SizedBox(width: 12),

            // Source Metadata Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectivePublisher,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (s.domain != null && s.domain!.isNotEmpty) ...[
                    Text(
                      s.domain!,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF64B5F6),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (s.publishedAt != null && s.publishedAt!.isNotEmpty)
                    Text(
                      s.publishedAt!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // External Open Link Icon
            IconButton(
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _launchSource(s),
            ),
          ],
        ),
      ),
    );
  }
}
