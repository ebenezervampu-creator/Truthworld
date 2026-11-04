import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/copyright_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/claim_details_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_formatters.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Ultra-wide and desktop sticky-header sortable data table for Copyright Claims.
/// Built strictly following the Zero `setState` policy using GetX reactivity.
class DesktopCopyrightDataTable extends StatelessWidget {
  const DesktopCopyrightDataTable({
    required this.docs,
    required this.isDarkMode,
    this.controller,
    super.key,
  });

  final List<QueryDocumentSnapshot> docs;
  final bool isDarkMode;
  final CopyrightController? controller;

  CopyrightController get _ctrl {
    if (controller != null) return controller!;
    if (Get.isRegistered<CopyrightController>()) {
      return Get.find<CopyrightController>();
    }
    return Get.put(CopyrightController());
  }

  List<QueryDocumentSnapshot> _getSortedDocs(
    CopyrightSortColumn sortColumn,
    bool sortAscending,
  ) {
    final list = List<QueryDocumentSnapshot>.from(docs);
    list.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>? ?? {};
      final bData = b.data() as Map<String, dynamic>? ?? {};
      var cmp = 0;
      switch (sortColumn) {
        case CopyrightSortColumn.videoTitle:
          final aTitle =
              (aData['videoTitle'] ?? aData['name'] ?? '').toString();
          final bTitle =
              (bData['videoTitle'] ?? bData['name'] ?? '').toString();
          cmp = aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
        case CopyrightSortColumn.claimant:
          final aClaimant =
              (aData['claimant'] ?? aData['owner'] ?? '').toString();
          final bClaimant =
              (bData['claimant'] ?? bData['owner'] ?? '').toString();
          cmp = aClaimant.toLowerCase().compareTo(bClaimant.toLowerCase());
        case CopyrightSortColumn.date:
          final aDate = aData['date'] as Timestamp? ??
              aData['createdAt'] as Timestamp? ??
              Timestamp.now();
          final bDate = bData['date'] as Timestamp? ??
              bData['createdAt'] as Timestamp? ??
              Timestamp.now();
          cmp = aDate.compareTo(bDate);
        case CopyrightSortColumn.impact:
          final aImpact = (aData['impact'] ?? '').toString();
          final bImpact = (bData['impact'] ?? '').toString();
          cmp = aImpact.compareTo(bImpact);
      }
      return sortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;
    final tableBg = isDarkMode ? AppColors.bgPage : Colors.white;
    final borderColor = isDarkMode ? AppColors.bgDivider : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: tableBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        final sortedDocs = _getSortedDocs(
          ctrl.sortColumn.value,
          ctrl.sortAscending.value,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTableHeader(context, ctrl, primaryTextColor, secondaryTextColor),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDocs.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: borderColor,
              ),
              itemBuilder: (context, index) {
                final doc = sortedDocs[index];
                final data = doc.data()! as Map<String, dynamic>;

                final rowBg = index.isEven
                    ? (isDarkMode ? AppColors.bgSurface : Colors.white)
                    : (isDarkMode ? AppColors.bgSurface : Colors.grey.shade50);

                return InkWell(
                  onTap: () => _showClaimDetails(context, data),
                  child: Container(
                    color: rowBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Video Title Cell (Flex 4)
                        Expanded(
                          flex: 4,
                          child: _buildVideoCell(data, primaryTextColor),
                        ),

                        // Claimant Cell (Flex 3)
                        Expanded(
                          flex: 3,
                          child: _buildClaimantCell(data, primaryTextColor),
                        ),

                        // Notice Type Cell (Flex 2)
                        Expanded(
                          flex: 2,
                          child: _buildNoticeTypeCell(data, secondaryTextColor),
                        ),

                        // Date Cell (Flex 2)
                        Expanded(
                          flex: 2,
                          child: _buildDateCell(data, secondaryTextColor),
                        ),

                        // Impact Cell (Flex 2)
                        Expanded(
                          flex: 2,
                          child: _buildImpactCell(data),
                        ),

                        // Actions Cell (Flex 2)
                        Expanded(
                          flex: 2,
                          child: _buildActionsCell(context, data, primaryTextColor),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTableHeader(
    BuildContext context,
    CopyrightController ctrl,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final headerBg =
        isDarkMode ? AppColors.appBarSurface : Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildSortableHeaderItem(
              'Video Affected',
              CopyrightSortColumn.videoTitle,
              ctrl,
              secondaryTextColor,
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildSortableHeaderItem(
              'Claimant',
              CopyrightSortColumn.claimant,
              ctrl,
              secondaryTextColor,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Claim Type',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildSortableHeaderItem(
              'Date Filed',
              CopyrightSortColumn.date,
              ctrl,
              secondaryTextColor,
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildSortableHeaderItem(
              'Impact',
              CopyrightSortColumn.impact,
              ctrl,
              secondaryTextColor,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Actions',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeaderItem(
    String label,
    CopyrightSortColumn column,
    CopyrightController ctrl,
    Color secondaryTextColor,
  ) {
    final isSelected = ctrl.sortColumn.value == column;
    final sortAscending = ctrl.sortAscending.value;
    final sortDirection = isSelected
        ? (sortAscending ? 'ascending' : 'descending')
        : 'not sorted';

    return Semantics(
      button: true,
      label: 'Sort by $label, currently $sortDirection',
      child: Tooltip(
        message: 'Sort by $label',
        child: InkWell(
          onTap: () => ctrl.setSort(column),
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
                    color: isSelected ? AppColors.info : secondaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected
                    ? (sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: isSelected ? AppColors.info : secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCell(Map<String, dynamic> data, Color primaryTextColor) {
    final title =
        (data['videoTitle'] ?? data['name'] ?? 'Unknown Content').toString();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
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
            style: TextStyle(
              color: primaryTextColor,
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

  Widget _buildClaimantCell(Map<String, dynamic> data, Color primaryTextColor) {
    final claimant =
        (data['claimant'] ?? data['owner'] ?? 'Rights Holder').toString();
    return Text(
      claimant,
      style: TextStyle(
        color: primaryTextColor,
        fontSize: 12,
        fontFamily: TWTypography.uiFamily,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNoticeTypeCell(
    Map<String, dynamic> data,
    Color secondaryTextColor,
  ) {
    final claimType = (data['noticeType'] ?? 'Copyright Claim').toString();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgInput : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
          ),
        ),
        child: Text(
          claimType,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 11,
            fontFamily: TWTypography.uiFamily,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDateCell(Map<String, dynamic> data, Color secondaryTextColor) {
    final dateStr = CopyrightFormatters.formatDate(
      data['date'] ?? data['createdAt'],
    );
    return Text(
      dateStr,
      style: TextStyle(
        color: secondaryTextColor,
        fontSize: 12,
        fontFamily: TWTypography.uiFamily,
      ),
    );
  }

  Widget _buildImpactCell(Map<String, dynamic> data) {
    final impact = (data['impact'] ??
            (data['actionRequired'] == true
                ? 'Action Required'
                : 'No Impact'))
        .toString();
    final isActionReq = impact.toLowerCase().contains('action') ||
        data['actionRequired'] == true;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
      ),
    );
  }

  Widget _buildActionsCell(
    BuildContext context,
    Map<String, dynamic> data,
    Color primaryTextColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Review copyright claim details',
          child: OutlinedButton(
            onPressed: () => _showClaimDetails(context, data),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: primaryTextColor,
              side: BorderSide(
                color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  void _showClaimDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          ClaimDetailsBottomSheet(data: data, isDarkMode: isDarkMode),
    );
  }
}
