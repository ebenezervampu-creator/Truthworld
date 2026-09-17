import 'package:flutter/material.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

  class FactCheckSourcesSection extends StatelessWidget {
  const FactCheckSourcesSection({required this.sources, super.key});
  final List<Map<String, dynamic>> sources;

  @override
  Widget build(BuildContext context) {
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
              'VERIFIED SOURCES & CITATIONS (${sources.length})',
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
        ...sources.map((s) => FactCheckSourceCard(source: s)),
      ],
    );
  }
}

class FactCheckSourceCard extends StatelessWidget {
  const FactCheckSourceCard({required this.source, super.key});
  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final sourceType = source['sourceType']?.toString() ?? 'default';
    final author = source['author']?.toString();
    final bookTitle = source['bookTitle']?.toString();
    final chapter = source['chapter']?.toString();
    final pageNumbers = source['pageNumbers']?.toString();
    final journalName = source['journalName']?.toString();
    final yearPublished = source['yearPublished'];
    final title = source['title']?.toString();
    final domain = source['domain']?.toString();
    final trustLevel = source['trustLevel']?.toString();
    final snippet = source['snippet']?.toString();
    final directUrl = source['directUrl']?.toString();
    final url = source['url']?.toString();

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

    var trustColor = AppColors.textTertiary;
    if (trustLevel == 'High') trustColor = AppColors.success;
    if (trustLevel == 'Medium') trustColor = AppColors.warning;
    if (trustLevel == 'Low') trustColor = AppColors.error;

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
          final link = directUrl ?? url;
          if (link != null && link.isNotEmpty) {
            try {
              final uri =
                  Uri.parse(link.startsWith('http') ? link : 'https://$link');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e, s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'FactCheckSourcesSection.openSourceLink',
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 18),
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
                          decoration: BoxDecoration(
                            color: trustColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trustLevel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            color: trustColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (domain != null)
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
