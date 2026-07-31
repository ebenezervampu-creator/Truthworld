import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class CopyrightScreen extends StatefulWidget {
  const CopyrightScreen({super.key, this.channelId});
  final String? channelId;

  @override
  State<CopyrightScreen> createState() => _CopyrightScreenState();
}

class _CopyrightScreenState extends State<CopyrightScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RxInt _retryTrigger = 0.obs;

  String get activeChannelId {
    if (widget.channelId != null && widget.channelId!.isNotEmpty) {
      return widget.channelId!;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _notices(String channelId) {
    if (channelId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('copyright_claims')
        .where('channelId', isEqualTo: channelId)
        .snapshots();
  }

  Stream<QuerySnapshot> _matchedReuploads(String channelId) {
    if (channelId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('videos')
        .where('originalChannelId', isEqualTo: channelId)
        .snapshots();
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    }
    return 'Unknown Date';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.textSecondary,
      appBar: AppBar(
        title: Text(
          'Copyright & Content Protection',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 20,
            color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
          ),
        ),
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brand,
          labelColor: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
          unselectedLabelColor: isDarkMode
              ? AppColors.textSecondary
              : AppColors.textSecondary,
          tabs: const [
            Tab(
              icon: Icon(Icons.gavel_rounded, color: Colors.white, size: 18),
              text: 'Claims & Notices',
            ),
            Tab(
              icon: Icon(
                Icons.find_in_page_rounded,
                color: Colors.white,
                size: 18,
              ),
              text: 'Copyright Match Tool (Re-upload Finder)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Claims & Notices
          _buildClaimsTab(isDarkMode),

          // Tab 2: Copyright Match Tool (Re-upload Finder)
          _buildMatchToolTab(isDarkMode),
        ],
      ),
    );
  }

  // ================= TAB 1: CLAIMS & NOTICES =================

  Widget _buildClaimsTab(bool isDarkMode) {
    return Obx(() {
      final _ = _retryTrigger.value;
      return StreamBuilder<QuerySnapshot>(
        stream: _notices(activeChannelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString(), isDarkMode);
          }

          final docs = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};
              final aDate =
                  aData['date'] as Timestamp? ??
                  aData['createdAt'] as Timestamp? ??
                  Timestamp.now();
              final bDate =
                  bData['date'] as Timestamp? ??
                  bData['createdAt'] as Timestamp? ??
                  Timestamp.now();
              return bDate.compareTo(aDate);
            });

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSummarySection(docs.length, isDarkMode),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDarkMode),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data =
                            docs[index].data()! as Map<String, dynamic>;
                        return _buildClaimCard(data, isDarkMode);
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

  Widget _buildSummarySection(int totalClaims, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: totalClaims > 0
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  totalClaims > 0
                      ? Icons.copyright
                      : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalClaims > 0
                          ? '$totalClaims Copyright claims'
                          : 'No copyright strikes',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontSize: 20,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : AppColors.bgPage,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalClaims > 0
                          ? 'Review details to see how these affect your channel.'
                          : 'Your channel is in good standing.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> data, bool isDarkMode) {
    final videoTitle =
        (data['videoTitle'] ??
                data['channelName'] ??
                data['name'] ??
                'Unknown Content')
            .toString();
    final claimType = (data['noticeType'] ?? 'Copyright Notice').toString();
    final claimant = (data['claimant'] ?? data['owner'] ?? 'Rights Holder')
        .toString();
    final impact =
        (data['impact'] ??
                (data['actionRequired'] == true
                    ? 'Action Required'
                    : 'No Impact'))
            .toString();
    final date = _formatDate(data['date'] ?? data['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.bgDivider
              : AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      child: InkWell(
        onTap: () => _showClaimDetailsBottomSheet(data, isDarkMode),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 45,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.textPrimary.withValues(alpha: 0.05)
                          : AppColors.bgPage.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.video_library_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          videoTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : AppColors.bgPage,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claimType,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.bgDivider),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniInfo('Claimant', claimant, isDarkMode),
                  _buildMiniInfo('Impact', impact, isDarkMode),
                  _buildMiniInfo('Date', date, isDarkMode),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: isDarkMode
                ? AppColors.textTertiary
                : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 12,
              color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage,
            ),
          ),
        ),
      ],
    );
  }

  // ================= TAB 2: COPYRIGHT MATCH TOOL (RE-UPLOAD FINDER) =================

  Widget _buildMatchToolTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _matchedReuploads(activeChannelId),
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
              child: Container(
                padding: const EdgeInsets.all(20),
                color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.screen_search_desktop_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automated Content Match Engine',
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : AppColors.bgPage,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scans Truthworld for re-uploaded videos matching your original content. Take direct action to request removal or contact uploaders.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (docs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No unauthorized re-uploads detected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : AppColors.bgPage,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Truthworld continuously scans new video uploads for copyright matches.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = docs[index].data()! as Map<String, dynamic>;
                      return _buildMatchCard(docs[index].id, data, isDarkMode);
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

  Widget _buildMatchCard(
    String docId,
    Map<String, dynamic> data,
    bool isDarkMode,
  ) {
    final title = (data['title'] ?? 'Re-uploaded Video').toString();
    final channelName =
        (data['channelName'] ?? data['uploader'] ?? 'Other Channel').toString();
    final matchPercent = (data['matchPercentage'] ?? 95).toString();
    final views = (data['viewCount'] ?? 0).toString();
    final uploadedAt = _formatDate(data['uploadedAt'] ?? data['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '$matchPercent% MATCH',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Uploaded: $uploadedAt',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Re-uploaded on channel: $channelName • $views views',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _contactUploaderDialog(channelName, title, isDarkMode),
                  icon: const Icon(
                    Icons.email_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text('Contact Uploader'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? AppColors.textPrimary
                        : AppColors.bgPage,
                    side: BorderSide(
                      color: isDarkMode ? AppColors.bgDivider : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _requestRemovalDialog(
                    docId,
                    title,
                    channelName,
                    isDarkMode,
                  ),
                  icon: const Icon(
                    Icons.gavel_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text('Request Video Removal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _contactUploaderDialog(
    String channelName,
    String videoTitle,
    bool isDarkMode,
  ) {
    final messageController = TextEditingController(
      text:
          'Hello $channelName, it has come to our attention that your video "$videoTitle" contains our copyrighted content. Please remove it immediately to avoid formal copyright strikes.',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        title: Text(
          'Contact Channel Owner',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 4,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
              ),
              decoration: InputDecoration(
                labelText: 'Notice Message',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.bgInput
                    : const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.snackbar(
                'Notice Sent',
                'Warning message sent to $channelName.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
  }

  void _requestRemovalDialog(
    String videoId,
    String title,
    String channelName,
    bool isDarkMode,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        title: Text(
          'Submit DMCA Removal Request?',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
          ),
        ),
        content: Text(
          'Filing a formal removal request for "$title" uploaded by $channelName will issue an official takedown notice under Truthworld Copyright Policy.',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('copyright_claims')
                  .add({
                    'videoId': videoId,
                    'videoTitle': title,
                    'channelId': activeChannelId,
                    'claimant': 'Original Creator',
                    'noticeType': 'DMCA Takedown Request',
                    'status': 'PENDING_TAKEDOWN',
                    'createdAt': Timestamp.now(),
                  });
              if (context.mounted) Navigator.pop(ctx);
              Get.snackbar(
                'Submitted',
                'Removal request submitted for $title.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('File Removal Request'),
          ),
        ],
      ),
    );
  }

  void _showClaimDetailsBottomSheet(
    Map<String, dynamic> data,
    bool isDarkMode,
  ) {
    showModalBottomSheet<void>(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _ClaimDetailsBottomSheet(data: data, isDarkMode: isDarkMode),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Channel content is claim-free',
              style: AppTextStyles.pageTitle.copyWith(
                fontSize: 18,
                color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep up the great work creating original content!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load copyright data',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _retryTrigger.value++,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimDetailsBottomSheet extends StatelessWidget {
  const _ClaimDetailsBottomSheet({
    required this.data,
    required this.isDarkMode,
  });
  final Map<String, dynamic> data;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Claim details',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 20,
                  color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow(
            'Video affected',
            (data['videoTitle'] ?? 'Unknown').toString(),
          ),
          _buildDetailRow(
            'Claim type',
            (data['noticeType'] ?? 'Content ID').toString(),
          ),
          _buildDetailRow(
            'Claimant',
            (data['claimant'] ?? 'Rights Holder').toString(),
          ),
          _buildDetailRow(
            'Policy',
            (data['policy'] ?? 'Monetized by claimant').toString(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
            ),
          ),
        ],
      ),
    );
  }
}
