import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section rendering verified citation sources.
class FactCheckSourcesSection extends StatelessWidget {
  const FactCheckSourcesSection({
    required this.sources,
    super.key,
  });

  final List<dynamic> sources;

  @override
  Widget build(BuildContext context) {
    final validSources =
        sources.where(SourceUrlSanitizer.isValidSource).toList();
    if (validSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VERIFIED SOURCES',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: validSources
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FactCheckSourceCard(
                    source: s as Map<dynamic, dynamic>,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Single verified source card with publication metadata and external link.
class FactCheckSourceCard extends StatelessWidget {
  const FactCheckSourceCard({
    required this.source,
    super.key,
  });

  final Map<dynamic, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final cleanSource = SourceUrlSanitizer.sanitizeSourceMap(source);
    final sourceType = cleanSource['sourceType']?.toString() ?? 'default';
    final author = cleanSource['author']?.toString();
    final bookTitle = cleanSource['bookTitle']?.toString();
    final chapter = cleanSource['chapter']?.toString();
    final pageNumbers = cleanSource['pageNumbers']?.toString();
    final volume = cleanSource['volume']?.toString();
    final journalName = cleanSource['journalName']?.toString();
    final yearPublished = cleanSource['yearPublished'];
    final title = cleanSource['title']?.toString();
    final domain = cleanSource['domain']?.toString();
    final trustLevel = cleanSource['trustLevel']?.toString();
    final snippet = cleanSource['snippet']?.toString();
    final directUrl = cleanSource['directUrl']?.toString();
    final url = cleanSource['url']?.toString();

    IconData icon;
    switch (sourceType) {
      case 'book':
        icon = Icons.menu_book_rounded;
      case 'journal':
        icon = Icons.science_rounded;
      case 'newspaper':
        icon = Icons.newspaper_rounded;
      case 'website':
        icon = Icons.language_rounded;
      case 'government':
        icon = Icons.account_balance_rounded;
      case 'scripture':
        icon = Icons.auto_stories_rounded;
      case 'legal':
        icon = Icons.gavel_rounded;
      case 'encyclopedia':
        icon = Icons.library_books_rounded;
      case 'academic_press':
        icon = Icons.school_rounded;
      case 'archive':
        icon = Icons.archive_rounded;
      default:
        icon = Icons.link_rounded;
    }

    final citationParts = <String>[];
    var prefix = '';
    if (sourceType == 'book') {
      prefix = '📖 ';
      if (bookTitle != null) citationParts.add(bookTitle);
      if (chapter != null) citationParts.add(chapter);
      if (pageNumbers != null) citationParts.add(pageNumbers);
    } else if (sourceType == 'journal') {
      prefix = '📰 ';
      if (journalName != null) citationParts.add(journalName);
      if (volume != null) citationParts.add(volume);
      if (pageNumbers != null) citationParts.add(pageNumbers);
    } else {
      if (domain != null) citationParts.add(domain);
    }
    if (yearPublished != null) citationParts.add(yearPublished.toString());

    final citationText = '$prefix${citationParts.join(', ')}';

    const trustColor = Colors.white70;

    return GestureDetector(
      onTap: () async {
        await SourceUrlSanitizer.launchSourceUrl(
          url: directUrl ?? url,
          title: author ?? title,
          domain: domain,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author ?? title ?? 'Source',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (citationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      citationText,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"$snippet"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (trustLevel != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: trustColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trustLevel.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 8,
                            color: trustColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (domain != null)
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
