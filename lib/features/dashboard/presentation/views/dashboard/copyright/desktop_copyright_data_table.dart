import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/claim_details_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_formatters.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Ultra-wide and desktop sticky-header sortable data table for Copyright Claims.
class DesktopCopyrightDataTable extends StatefulWidget {
  const DesktopCopyrightDataTable({
    required this.docs,
    required this.isDarkMode,
    super.key,
  });

  final List<QueryDocumentSnapshot> docs;
  final bool isDarkMode;

  @override
  State<DesktopCopyrightDataTable> createState() => _DesktopCopyrightDataTableState();
}

enum CopyrightSortColumn { videoTitle, claimant, date, impact }

class _DesktopCopyrightDataTableState extends State<DesktopCopyrightDataTable> {
  CopyrightSortColumn _sortColumn = CopyrightSortColumn.date;
  bool _sortAscending = false;

  bool _showClaimant = true;
  bool _showNoticeType = true;
  bool _showDate = true;
  bool _showImpact = true;

  String? _hoveredDocId;

  List<QueryDocumentSnapshot> get _sortedDocs {
    final list = List<QueryDocumentSnapshot>.from(widget.docs);
    list.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>? ?? {};
      final bData = b.data() as Map<String, dynamic>? ?? {};
      var cmp = 0;
      switch (_sortColumn) {
        case CopyrightSortColumn.videoTitle:
          final aTitle = (aData['videoTitle'] ?? aData['name'] ?? '').toString();
          final bTitle = (bData['videoTitle'] ?? bData['name'] ?? '').toString();
          cmp = aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
        case CopyrightSortColumn.claimant:
          final aClaimant = (aData['claimant'] ?? aData['owner'] ?? '').toString();
          final bClaimant = (bData['claimant'] ?? bData['owner'] ?? '').toString();
          cmp = aClaimant.toLowerCase().compareTo(bClaimant.toLowerCase());
        case CopyrightSortColumn.date:
          final aDate = aData['date'] as Timestamp? ?? aData['createdAt'] as Timestamp? ?? Timestamp.now();
          final bDate = bData['date'] as Timestamp? ?? bData['createdAt'] as Timestamp? ?? Timestamp.now();
          cmp = aDate.compareTo(bDate);
        case CopyrightSortColumn.impact:
          final aImpact = (aData['impact'] ?? '').toString();
          final bImpact = (bData['impact'] ?? '').toString();
          cmp = aImpact.compareTo(bImpact);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(CopyrightSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final docs = _sortedDocs;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTableHeader(context),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: AppColors.bgDivider,
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;
              final isHovered = _hoveredDocId == doc.id;

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredDocId = doc.id),
                onExit: (_) => setState(() => _hoveredDocId = null),
                child: InkWell(
                  onTap: () => _showClaimDetails(data),
                  child: Container(
                    color: isHovered
                        ? AppColors.bgSurfaceHover
                        : (index.isEven
                            ? AppColors.bgSurface
                            : const Color(0xFF1E1E1E)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Video Title Cell (Flex 4)
                        Expanded(
                          flex: 4,
                          child: _buildVideoCell(data, isHovered),
                        ),

                        // Claimant Cell (Flex 3)
                        if (_showClaimant)
                          Expanded(
                            flex: 3,
                            child: _buildClaimantCell(data),
                          ),

                        // Notice Type Cell (Flex 2)
                        if (_showNoticeType)
                          Expanded(
                            flex: 2,
                            child: _buildNoticeTypeCell(data),
                          ),

                        // Date Cell (Flex 2)
                        if (_showDate)
                          Expanded(
                            flex: 2,
                            child: _buildDateCell(data),
                          ),

                        // Impact Cell (Flex 2)
                        if (_showImpact)
                          Expanded(
                            flex: 2,
                            child: _buildImpactCell(data),
                          ),

                        // Actions Cell (Flex 2)
                        Expanded(
                          flex: 2,
                          child: _buildActionsCell(data),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildSortableHeaderItem(
              'Video Affected',
              CopyrightSortColumn.videoTitle,
            ),
          ),
          if (_showClaimant)
            Expanded(
              flex: 3,
              child: _buildSortableHeaderItem(
                'Claimant',
                CopyrightSortColumn.claimant,
              ),
            ),
          if (_showNoticeType)
            const Expanded(
              flex: 2,
              child: Text(
                'Claim Type',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (_showDate)
            Expanded(
              flex: 2,
              child: _buildSortableHeaderItem(
                'Date Filed',
                CopyrightSortColumn.date,
              ),
            ),
          if (_showImpact)
            Expanded(
              flex: 2,
              child: _buildSortableHeaderItem(
                'Impact',
                CopyrightSortColumn.impact,
              ),
            ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                _buildColumnToggleMenu(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeaderItem(String label, CopyrightSortColumn column) {
    final isSelected = _sortColumn == column;
    final sortDirection = isSelected ? (_sortAscending ? 'ascending' : 'descending') : 'not sorted';
    return Semantics(
      button: true,
      label: 'Sort by $label, currently $sortDirection',
      child: Tooltip(
        message: 'Sort by $label',
        child: InkWell(
          onTap: () => _onSort(column),
          borderRadius: BorderRadius.circular(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSelected ? AppColors.brand : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected
                    ? (_sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: isSelected ? AppColors.brand : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnToggleMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Customize columns',
      icon: const Icon(
        Icons.view_column_rounded,
        size: 16,
        color: AppColors.textSecondary,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          checked: _showClaimant,
          value: 'claimant',
          child: const Text('Claimant', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showNoticeType,
          value: 'noticeType',
          child: const Text('Claim Type', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showDate,
          value: 'date',
          child: const Text('Date Filed', style: TextStyle(color: Colors.white)),
        ),
        CheckedPopupMenuItem(
          checked: _showImpact,
          value: 'impact',
          child: const Text('Impact', style: TextStyle(color: Colors.white)),
        ),
      ],
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'claimant':
              _showClaimant = !_showClaimant;
            case 'noticeType':
              _showNoticeType = !_showNoticeType;
            case 'date':
              _showDate = !_showDate;
            case 'impact':
              _showImpact = !_showImpact;
          }
        });
      },
    );
  }

  Widget _buildVideoCell(Map<String, dynamic> data, bool isHovered) {
    final title = (data['videoTitle'] ?? data['name'] ?? 'Unknown Content').toString();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.gavel_rounded,
            size: 16,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: TWTypography.uiFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildClaimantCell(Map<String, dynamic> data) {
    final claimant = (data['claimant'] ?? data['owner'] ?? 'Rights Holder').toString();
    return Text(
      claimant,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontFamily: TWTypography.uiFamily,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNoticeTypeCell(Map<String, dynamic> data) {
    final claimType = (data['noticeType'] ?? 'Copyright Claim').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Text(
        claimType,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontFamily: TWTypography.uiFamily,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDateCell(Map<String, dynamic> data) {
    final dateStr = CopyrightFormatters.formatDate(
      data['date'] ?? data['createdAt'],
    );
    return Text(
      dateStr,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontFamily: TWTypography.uiFamily,
      ),
    );
  }

  Widget _buildImpactCell(Map<String, dynamic> data) {
    final impact = (data['impact'] ?? (data['actionRequired'] == true ? 'Action Required' : 'No Impact')).toString();
    final isActionReq = impact.toLowerCase().contains('action') || data['actionRequired'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActionReq
            ? AppColors.error.withValues(alpha: 0.15)
            : AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActionReq
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        impact,
        style: TextStyle(
          color: isActionReq ? AppColors.error : AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: TWTypography.uiFamily,
        ),
      ),
    );
  }

  Widget _buildActionsCell(Map<String, dynamic> data) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Review copyright claim details',
          child: OutlinedButton(
            onPressed: () => _showClaimDetails(data),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.bgDivider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  void _showClaimDetails(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          ClaimDetailsBottomSheet(data: data, isDarkMode: widget.isDarkMode),
    );
  }
}
