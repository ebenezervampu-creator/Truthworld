import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';

class CopyrightScreen extends StatefulWidget {
  final String? channelId;
  const CopyrightScreen({super.key, this.channelId});

  @override
  State<CopyrightScreen> createState() => _CopyrightScreenState();
}

class _CopyrightScreenState extends State<CopyrightScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final String _channelId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _channelId = widget.channelId ?? user?.uid ?? '';
  }

  Stream<QuerySnapshot> _notices() {
    if (_channelId.isEmpty) return const Stream.empty();
    // Industry Standard: Query by channelId and ensure descending order by date
    return _firestore
        .collection('copyrights')
        .where('channelId', isEqualTo: _channelId)
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

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          'Channel copyright',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notices(),
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
                        final data = docs[index].data() as Map<String, dynamic>;
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
      ),
    );
  }

  Widget _buildSummarySection(int totalClaims, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white10 : Colors.black12,
            width: 1,
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
                  color: totalClaims > 0 ? AppColors.error.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  totalClaims > 0 ? Icons.copyright : Icons.check_circle_outline,
                  color: totalClaims > 0 ? AppColors.error : Colors.green,
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
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalClaims > 0 
                        ? 'Review details to see how these affect your channel.' 
                        : 'Your channel is in good standing.',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
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
        Icon(icon, size: 20, color: isDarkMode ? Colors.white54 : Colors.black45),
        const SizedBox(width: 12),
        Text(
          '$title: ',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.roboto(
            color: isDarkMode ? Colors.white38 : Colors.black45,
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
          color: isDarkMode ? Colors.white10 : Colors.black12,
        ),
      ),
      color: isDarkMode ? AppColors.bgSurface : Colors.white,
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
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
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
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claimType,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.white24),
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
          style: GoogleFonts.roboto(
            fontSize: 11,
            color: isDarkMode ? Colors.white38 : Colors.black38,
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
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  void _showClaimDetailsBottomSheet(Map<String, dynamic> data, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
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
            color: Colors.green.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Channel content is claim-free',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep up the great work creating original content!',
            style: TextStyle(color: Colors.grey),
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
            Text(
              'Failed to load copyright data',
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
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
  final Map<String, dynamic> data;
  final bool isDarkMode;

  const _ClaimDetailsBottomSheet({required this.data, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
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
                style: GoogleFonts.roboto(
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
          Text(
            'SELECT ACTION',
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
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
              color: isDarkMode ? Colors.white38 : Colors.black38,
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
          color: isDestructive ? AppColors.error : (isDarkMode ? Colors.white : Colors.black),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
