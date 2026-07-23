import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class CopyrightScreen extends StatelessWidget {
  CopyrightScreen({super.key, this.channelId});
  final String? channelId;

  final RxInt _retryTrigger = 0.obs;

  Stream<QuerySnapshot> _notices(String activeChannelId) {
    if (activeChannelId.isEmpty) return const Stream.empty();
    // Industry Standard: Query by channelId and ensure descending order by date
    return FirebaseFirestore.instance
        .collection('copyright_claims')
        .where('channelId', isEqualTo: activeChannelId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    }
    return 'Unknown Date';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final activeChannelId = channelId ?? user?.uid ?? '';

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Channel copyright',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: Obx(() {
        final _ = _retryTrigger.value;
        return StreamBuilder<QuerySnapshot>(
          stream: _notices(activeChannelId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final docs = snapshot.data?.docs ?? [];
            
            return CustomScrollView(
              slivers: [
                // Summary Section
                SliverToBoxAdapter(
                  child: _buildSummarySection(docs.length, isDarkMode),
                ),

                if (docs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final data = docs[index].data()! as Map<String, dynamic>;
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
      }),
    );
  }

  Widget _buildSummarySection(int totalClaims, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : Colors.black12,
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
                  color: totalClaims > 0 ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  totalClaims > 0 ? Icons.copyright : Icons.check_circle_outline,
                  color: totalClaims > 0 ? AppColors.error : AppColors.success,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalClaims > 0 ? '$totalClaims Copyright claims' : 'No copyright strikes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalClaims > 0 
                        ? 'Review details to see how these affect your channel.' 
                        : 'Your channel is in good standing.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalClaims > 0) ...[
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildStatusItem(
              Icons.visibility_outlined,
              'Visibility',
              'Multiple videos affected',
              isDarkMode,
            ),
            const SizedBox(height: 12),
            _buildStatusItem(
              Icons.monetization_on_outlined,
              'Monetization',
              'Ineligible or Shared',
              isDarkMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String title, String subtitle, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDarkMode ? AppColors.textSecondary : Colors.black45),
        const SizedBox(width: 12),
        Text(
          '$title: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? AppColors.textTertiary : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> data, bool isDarkMode) {
    final videoTitle = data['videoTitle'] ?? data['channelName'] ?? data['name'] ?? 'Unknown Content';
    final claimType = data['noticeType'] ?? 'Copyright Notice';
    final claimant = data['claimant'] ?? data['owner'] ?? 'Rights Holder';
    final impact = data['impact'] ?? (data['actionRequired'] == true ? 'Action Required' : 'No Impact');
    final date = _formatDate(data['date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? AppColors.bgDivider : Colors.black12,
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.video_library_outlined, size: 20),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claimType,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textDisabled),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
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
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? AppColors.textTertiary : Colors.black38,
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
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage,
            ),
          ),
        ),
      ],
    );
  }

  void _showClaimDetailsBottomSheet(Map<String, dynamic> data, bool isDarkMode) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ClaimDetailsBottomSheet(data: data, isDarkMode: isDarkMode),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppColors.success.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Channel content is claim-free',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep up the great work creating original content!',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Failed to load copyright data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _retryTrigger.value++,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimDetailsBottomSheet extends StatelessWidget {

  const _ClaimDetailsBottomSheet({required this.data, required this.isDarkMode});
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
              const Text(
                'Claim details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Video affected', data['videoTitle'] ?? 'Unknown'),
          _buildDetailRow('Claim type', data['noticeType'] ?? 'Content ID'),
          _buildDetailRow('Claimant', data['claimant'] ?? 'Rights Holder'),
          _buildDetailRow('Policy', data['policy'] ?? 'Monetized by claimant'),
          _buildDetailRow('Description', data['description'] ?? 'No additional details provided.'),
          
          const SizedBox(height: 32),
          const Text(
            'SELECT ACTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(Icons.content_cut, 'Trim out segment', () {}),
          _buildActionButton(Icons.music_note, 'Replace song', () {}),
          _buildActionButton(Icons.volume_off, 'Mute song', () {}),
          _buildActionButton(Icons.gavel, 'Dispute claim', () {}, isDestructive: true),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? AppColors.textTertiary : Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.brand),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? AppColors.error : (isDarkMode ? AppColors.textPrimary : AppColors.bgPage),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
