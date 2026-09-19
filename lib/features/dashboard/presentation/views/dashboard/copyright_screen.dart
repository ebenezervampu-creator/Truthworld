import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_barrel.dart';

/// Screen for managing copyright claims, DMCA notices, and content re-upload matches.
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

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          'Copyright & Content Protection',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 20,
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        backgroundColor:
            isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
        ),
        bottom: TabBar(
          controller: ctrl.tabController,
          indicatorColor: AppColors.brand,
          labelColor: isDarkMode ? AppColors.textPrimary : Colors.black,
          unselectedLabelColor:
              isDarkMode ? AppColors.textSecondary : Colors.black54,
          tabs: [
            Tab(
              icon: Icon(
                Icons.gavel_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 18,
              ),
              text: 'Claims & Notices',
            ),
            Tab(
              icon: Icon(
                Icons.find_in_page_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
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
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
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
    });
  }

  Widget _buildMatchToolTab(CopyrightController ctrl, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: ctrl.matchedReuploadsStream(ctrl.activeChannelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
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
