import 'package:flutter/material.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisSourceCard extends StatelessWidget {
  final Map<dynamic, dynamic> source;

  const VideoAnalysisSourceCard({required this.source, super.key});

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
    final publisher = cleanSource['publisher']?.toString();
    final avatarUrl = cleanSource['avatarUrl']?.toString();
    final trustLevel = cleanSource['trustLevel']?.toString();
    final snippet = cleanSource['snippet']?.toString();
    final directUrl = cleanSource['directUrl']?.toString();
    final url = cleanSource['url']?.toString();

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
          title: title ?? bookTitle ?? author,
          domain: domain,
          source: cleanSource,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.7)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SourceAvatarService.buildAvatar(
              domain: domain,
              url: directUrl ?? url,
              publisher: publisher ?? author,
              avatarUrl: avatarUrl,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author ?? title ?? 'Source Reference',
                    style: context.twTypography.title.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: TWTypography.uiFamily,
                    ),
                  ),
                  if (citationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      citationText,
                      style: context.twTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ],
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"$snippet"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.twTypography.caption.copyWith(
                        fontSize: 11,
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
                          style: context.twTypography.caption.copyWith(
                            fontSize: 9,
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
                            style: context.twTypography.caption.copyWith(
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
              Icons.open_in_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

}
