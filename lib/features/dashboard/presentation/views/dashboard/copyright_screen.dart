import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_barrel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/desktop_copyright_data_table.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_barrel.dart';

/// Studio screen for managing copyright claims, DMCA notices, and content re-upload matches.
class CopyrightScreen extends StatelessWidget {
  const CopyrightScreen({super.key, this.channelId});

  final String? channelId;

  CopyrightController get controller {
    final ctrl = Get.isRegistered<CopyrightController>()
        ? Get.find<CopyrightController>()
        : Get.put(CopyrightController(initialChannelId: channelId));
    if (channelId != null &&
        channelId!.isNotEmpty &&
        ctrl.channelId.value != channelId) {
      ctrl.setChannelContext(channelId!);
    }
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final ctrl = controller;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final pageBg = isDarkMode ? AppColors.bgPage : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: Text(
          'Copyright & Content Protection',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        backgroundColor: pageBg,
        elevation: 0,
        iconTheme: IconThemeData(
          color: primaryTextColor,
        ),
        actions: [
          // Education / Policy modal button
          IconButton(
            tooltip: 'Copyright Policies & Guidelines',
            icon: Icon(
              Icons.help_outline_rounded,
              color: primaryTextColor,
            ),
            onPressed: () => CopyrightDialogs.showCopyrightEducation(
              context: context,
              isDarkMode: isDarkMode,
            ),
          ),
          // YouTube Studio-style "+ New Removal Request" button
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                Get.toNamed(AppRoutes.copyrightComplaint);
              },
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.black,
              ),
              label: const Text(
                'New Removal Request',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: ctrl.tabController,
          indicatorColor: isDarkMode ? AppColors.brand : Colors.black87,
          indicatorWeight: 3,
          labelColor: primaryTextColor,
          unselectedLabelColor:
              isDarkMode ? AppColors.textSecondary : Colors.black54,
          labelStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: [
            Tab(
              icon: Icon(
                Icons.gavel_rounded,
                color: primaryTextColor,
                size: 18,
              ),
              text: 'Claims & Notices',
            ),
            Tab(
              icon: Icon(
                Icons.find_in_page_rounded,
                color: primaryTextColor,
                size: 18,
              ),
              text: 'Copyright Match Tool (Re-upload Finder)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: ctrl.tabController,
        children: [
          _buildClaimsTab(ctrl, isDarkMode),
          _buildMatchToolTab(ctrl, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildClaimsTab(CopyrightController ctrl, bool isDarkMode) {
    return Obx(() {
      final _ = ctrl.retryTrigger.value;
      return StreamBuilder<QuerySnapshot>(
        stream: ctrl.noticesStream(ctrl.activeChannelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const StudioLoadingIndicator(
              message: 'Loading copyright claims...',
            );
          }

          if (snapshot.hasError) {
            ErrorHandler.log(snapshot.error, tag: 'CopyrightScreen.snapshot');
            return CopyrightErrorState(
              onRetry: ctrl.retry,
              isDarkMode: isDarkMode,
            );
          }

          final allDocs = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};
              final aDate = aData['date'] as Timestamp? ??
                  aData['createdAt'] as Timestamp? ??
                  Timestamp.now();
              final bDate = bData['date'] as Timestamp? ??
                  bData['createdAt'] as Timestamp? ??
                  Timestamp.now();
              return bDate.compareTo(aDate);
            });

          // Apply search query filter if user typed in search
          final query = ctrl.searchQuery.value;
          final docs = query.isEmpty
              ? allDocs
              : allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final title =
                      (data['videoTitle'] ?? data['name'] ?? '').toString().toLowerCase();
                  final claimant =
                      (data['claimant'] ?? data['owner'] ?? '').toString().toLowerCase();
                  return title.contains(query) || claimant.contains(query);
                }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopWide = constraints.maxWidth >= 1100;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ClaimsSummaryCard(
                      totalClaims: allDocs.length,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  if (allDocs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildSearchBar(
                        ctrl: ctrl,
                        isDarkMode: isDarkMode,
                        hintText: 'Search claims by video or rights holder...',
                      ),
                    ),
                  if (docs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: CopyrightEmptyState(isDarkMode: isDarkMode),
                    )
                  else if (isDesktopWide)
                    SliverToBoxAdapter(
                      child: DesktopCopyrightDataTable(
                        docs: docs,
                        isDarkMode: isDarkMode,
                        controller: ctrl,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data =
                                docs[index].data()! as Map<String, dynamic>;
                            return ClaimCard(
                              data: data,
                              isDarkMode: isDarkMode,
                            );
                          },
                          childCount: docs.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          );
        },
      );
    });
  }

  Widget _buildMatchToolTab(CopyrightController ctrl, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: ctrl.matchedReuploadsStream(ctrl.activeChannelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const StudioLoadingIndicator(
            message: 'Loading matched videos...',
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MatchToolHeader(isDarkMode: isDarkMode),
            ),
            if (allDocs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MatchToolEmptyState(isDarkMode: isDarkMode),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data =
                          allDocs[index].data()! as Map<String, dynamic>;
                      return MatchVideoCard(
                        docId: allDocs[index].id,
                        data: data,
                        controller: ctrl,
                        isDarkMode: isDarkMode,
                      );
                    },
                    childCount: allDocs.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar({
    required CopyrightController ctrl,
    required bool isDarkMode,
    required String hintText,
  }) {
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        onChanged: ctrl.setSearchQuery,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontSize: 13,
          color: primaryTextColor,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 13,
            color: secondaryTextColor,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: secondaryTextColor,
          ),
          filled: true,
          fillColor: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.info),
          ),
        ),
      ),
    );
  }
}
