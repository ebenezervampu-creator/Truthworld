import 'package:flutter/material.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

  class FactCheckSourcesSection extends StatelessWidget {
  const FactCheckSourcesSection({required this.sources, super.key});
  final List<Map<String, dynamic>> sources;

  @override
  Widget build(BuildContext context) {
    final validSources =
        sources.where(SourceUrlSanitizer.isValidSource).toList();
    if (validSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'VERIFIED SOURCES & CITATIONS (${validSources.length})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...validSources.map((s) => FactCheckSourceCard(source: s)),
      ],
    );
  }
}

class FactCheckSourceCard extends StatelessWidget {
  const FactCheckSourceCard({required this.source, super.key});
  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final cleanSource = SourceUrlSanitizer.sanitizeSourceMap(source);
    final sourceType = cleanSource['sourceType']?.toString() ?? 'default';
    final author = cleanSource['author']?.toString();
    final bookTitle = cleanSource['bookTitle']?.toString();
    final chapter = cleanSource['chapter']?.toString();
    final pageNumbers = cleanSource['pageNumbers']?.toString();
    final journalName = cleanSource['journalName']?.toString();
    final yearPublished = cleanSource['yearPublished'];
    final title = cleanSource['title']?.toString();
    final domain = cleanSource['domain']?.toString();
    final trustLevel = cleanSource['trustLevel']?.toString();
    final snippet = cleanSource['snippet']?.toString();
    final directUrl = cleanSource['directUrl']?.toString();
    final url = cleanSource['url']?.toString();
    final publisher = cleanSource['publisher']?.toString();
    final avatarUrl = cleanSource['avatarUrl']?.toString();

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
      if (pageNumbers != null) citationParts.add(pageNumbers);
    } else {
      if (domain != null) citationParts.add(domain);
    }
    if (yearPublished != null) citationParts.add(yearPublished.toString());

    final citationText = '$prefix${citationParts.join(', ')}';

    const trustColor = Colors.white70;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: () async {
          await SourceUrlSanitizer.launchSourceUrl(
            url: directUrl ?? url,
            title: title ?? bookTitle ?? author,
            domain: domain,
            source: cleanSource,
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SourceAvatarService.buildAvatar(
              domain: domain,
              publisher: publisher ?? author,
              url: directUrl ?? url,
              avatarUrl: avatarUrl,
              fallbackIcon: icon,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author ?? title ?? 'Source Reference',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (citationText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      citationText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"$snippet"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (trustLevel != null) ...[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: trustColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trustLevel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8,
                            color: trustColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (domain != null &&
                          domain.isNotEmpty &&
                          domain.toLowerCase() != (author ?? '').toLowerCase() &&
                          domain.toLowerCase() != (title ?? '').toLowerCase())
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.open_in_new_rounded,
              color: Colors.white,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }


}
