import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_barrel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/desktop_copyright_data_table.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_barrel.dart';

/// Screen for managing copyright claims, DMCA notices, and content re-upload matches.
class CopyrightScreen extends StatelessWidget {
  const CopyrightScreen({super.key, this.channelId});

  final String? channelId;

  Widget _buildCopyrightSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: AppColors.bgSurfaceHover,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

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

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Copyright & Content Protection',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
        bottom: TabBar(
          controller: ctrl.tabController,
          indicatorColor: AppColors.brand,
          indicatorWeight: 3,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
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
          tabs: const [
            Tab(
              icon: Icon(
                Icons.gavel_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              text: 'Claims & Notices',
            ),
            Tab(
              icon: Icon(
                Icons.find_in_page_rounded,
                color: AppColors.textPrimary,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCopyrightSkeleton();
          }

          if (snapshot.hasError) {
            ErrorHandler.log(snapshot.error, tag: 'CopyrightScreen.snapshot');
            return CopyrightErrorState(
              onRetry: ctrl.retry,
              isDarkMode: isDarkMode,
            );
          }

          final docs = (snapshot.data?.docs ?? []).toList()
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopWide = constraints.maxWidth >= 1100;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ClaimsSummaryCard(
                      totalClaims: docs.length,
                      isDarkMode: isDarkMode,
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
                            return ClaimCard(data: data, isDarkMode: isDarkMode);
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCopyrightSkeleton();
        }

        final docs = snapshot.data?.docs ?? [];

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MatchToolHeader(isDarkMode: isDarkMode),
            ),
            if (docs.isEmpty)
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
                      final data = docs[index].data()! as Map<String, dynamic>;
                      return MatchVideoCard(
                        docId: docs[index].id,
                        data: data,
                        controller: ctrl,
                        isDarkMode: isDarkMode,
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
