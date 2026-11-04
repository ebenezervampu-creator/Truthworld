import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Tab dedicated to Channel-wide Authoritative Sources & Citations.
///
/// Directly inspired by the Consumer App's "Ai Check" sources section:
/// - Directory of all institutional registries and peer-reviewed journals cited
/// - Trust tier badges (Tier 1 Primary Registry, Academic, Government, Press)
/// - Direct clickable links with external browser launch
/// - Strictly follows TruthWorld's Zero setState Policy via GetX Rx reactive state.
class TruthVerificationSourcesTab extends StatelessWidget {
  TruthVerificationSourcesTab({
    required this.videos,
    required this.allClaims,
    required this.isDarkMode,
    super.key,
  });

  final List<VideoFactCheckItem> videos;
  final List<RealExtractedClaim> allClaims;
  final bool isDarkMode;

  final RxString _searchFilter = ''.obs;

  List<AuthoritativeSourceItem> _extractAllSources() {
    final Map<String, AuthoritativeSourceItem> uniqueSources = {};

    // 1. Extract from video items
    for (final v in videos) {
      for (final s in v.sources) {
        String title = '';
        String url = '';
        String domain = '';
        String publisher = '';

        if (s is Map) {
          title = (s['title'] ?? s['name'] ?? s['publisher'] ?? '').toString();
          url = (s['url'] ?? s['link'] ?? s['directUrl'] ?? '').toString();
          domain = (s['domain'] ?? s['sourceDomain'] ?? '').toString();
          publisher = (s['publisher'] ?? s['author'] ?? '').toString();
        } else if (s is String && s.isNotEmpty) {
          title = s;
          if (s.startsWith('http')) url = s;
        }

        if (title.isEmpty && url.isEmpty) continue;
        if (title.isEmpty) title = domain.isNotEmpty ? domain : url;

        final key = url.isNotEmpty ? url : title.toLowerCase();
        if (uniqueSources.containsKey(key)) {
          final existing = uniqueSources[key]!;
          uniqueSources[key] = AuthoritativeSourceItem(
            title: existing.title,
            url: existing.url,
            domain: existing.domain,
            publisher: existing.publisher,
            videoId: existing.videoId,
            videoTitle: existing.videoTitle,
            trustTier: existing.trustTier,
            count: existing.count + 1,
          );
        } else {
          uniqueSources[key] = AuthoritativeSourceItem(
            title: title,
            url: url,
            domain: domain.isNotEmpty ? domain : _resolveDomain(url),
            publisher: publisher,
            videoId: v.id,
            videoTitle: v.title,
            trustTier: _resolveTrustTier(url, title),
            count: 1,
          );
        }
      }
    }

    // 2. Extract from claims
    for (final c in allClaims) {
      if (c.sourceCitation.isNotEmpty &&
          c.sourceCitation != 'AI Epistemic Registry' &&
          c.sourceCitation != 'Authoritative Citation') {
        final key = c.sourceUrl?.isNotEmpty == true ? c.sourceUrl! : c.sourceCitation.toLowerCase();
        if (uniqueSources.containsKey(key)) {
          final existing = uniqueSources[key]!;
          uniqueSources[key] = AuthoritativeSourceItem(
            title: existing.title,
            url: existing.url,
            domain: existing.domain,
            publisher: existing.publisher,
            videoId: existing.videoId,
            videoTitle: existing.videoTitle,
            trustTier: existing.trustTier,
            count: existing.count + 1,
          );
        } else {
          uniqueSources[key] = AuthoritativeSourceItem(
            title: c.sourceCitation,
            url: c.sourceUrl ?? '',
            domain: _resolveDomain(c.sourceUrl ?? c.sourceCitation),
            publisher: c.sourceCitation,
            videoId: c.videoId,
            videoTitle: c.videoTitle,
            trustTier: _resolveTrustTier(c.sourceUrl ?? '', c.sourceCitation),
            count: 1,
          );
        }
      }
    }

    return uniqueSources.values.toList();
  }

  String _resolveDomain(String str) {
    if (str.startsWith('http://') || str.startsWith('https://')) {
      try {
        final uri = Uri.parse(str);
        return uri.host.replaceFirst('www.', '');
      } catch (_) {}
    }
    return str;
  }

  String _resolveTrustTier(String url, String title) {
    final lower = '$url $title'.toLowerCase();
    if (lower.contains('.gov') || lower.contains('usda') || lower.contains('who.int') || lower.contains('cdc.gov') || lower.contains('fda.gov')) {
      return 'Government Registry (Tier 1)';
    }
    if (lower.contains('.edu') || lower.contains('nature.com') || lower.contains('sciencedirect') || lower.contains('pubmed') || lower.contains('ieee')) {
      return 'Peer-Reviewed Academic (Tier 1)';
    }
    if (lower.contains('reuters') || lower.contains('apnews') || lower.contains('bbc') || lower.contains('bloomberg')) {
      return 'Verified Wire Agency (Tier 2)';
    }
    return 'Institutional Database';
  }

  @override
  Widget build(BuildContext context) {
    final allSources = _extractAllSources();

    return Obx(() {
      final q = _searchFilter.value.trim().toLowerCase();
      final filtered = q.isEmpty
          ? allSources
          : allSources.where((s) {
              return s.title.toLowerCase().contains(q) ||
                  s.domain.toLowerCase().contains(q) ||
                  s.trustTier.toLowerCase().contains(q);
            }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Bar for Sources
          Container(
            decoration: BoxDecoration(
              color: AppColors.appBarSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.bgSurface,
              ),
            ),
            child: TextField(
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Search authoritative citations by domain or publisher...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                        onPressed: () => _searchFilter.value = '',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) => _searchFilter.value = val,
            ),
          ),
          const SizedBox(height: 16),

          // 2. Sources Count Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Indexed Authorities & Citations (${filtered.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Primary Evidence Hierarchy',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Source List or Empty State
          if (filtered.isEmpty)
            _buildEmptySourcesState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildSourceCard(item);
              },
            ),
          const SizedBox(height: 24),
        ],
      );
    });
  }

  Widget _buildSourceCard(AuthoritativeSourceItem source) {
    Color tierBg = AppColors.bgInput;
    Color tierFg = AppColors.success;
    if (!source.trustTier.contains('Tier 1')) {
      tierFg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tierBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Icon(Icons.menu_book_rounded, size: 16, color: tierFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: tierBg,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      child: Text(
                        source.trustTier,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tierFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (source.count > 1)
                      Text(
                        'Cited in ${source.count} assertions',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  source.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (source.domain.isNotEmpty && source.domain != source.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    source.domain,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (source.url.isNotEmpty && source.url.startsWith('http')) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: Colors.white,
              ),
              tooltip: 'Open Citation in Browser',
              onPressed: () => ClickableUrlText.launchUrlString(source.url),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySourcesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No External Sources Indexed Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'When videos with empirical claims are evaluated, authoritative citations from national registries, peer-reviewed journals, and official repositories will be cataloged here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
