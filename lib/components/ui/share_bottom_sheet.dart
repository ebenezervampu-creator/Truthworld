import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/theme/app_theme.dart';

class ShareBottomSheet extends StatelessWidget {
  final String title;
  final String url;
  final String? thumbnailUrl;

  const ShareBottomSheet({
    super.key,
    required this.title,
    required this.url,
    this.thumbnailUrl,
  });

  static void show({
    required String title,
    required String url,
    String? thumbnailUrl,
  }) {
    Get.bottomSheet(
      ShareBottomSheet(
        title: title,
        url: url,
        thumbnailUrl: thumbnailUrl,
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 300),
      exitBottomSheetDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Share',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.bgDivider, height: 1),

          // Social Icons Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              children: [
                _buildSocialIcon(
                  icon: Icons.chat_bubble_rounded,
                  color: const Color(0xFF25D366),
                  label: 'WhatsApp',
                  onTap: () => _shareToSocial('whatsapp'),
                ),
                _buildSocialIcon(
                  icon: Icons.facebook_rounded,
                  color: const Color(0xFF1877F2),
                  label: 'Facebook',
                  onTap: () => _shareToSocial('facebook'),
                ),
                _buildSocialIcon(
                  icon: Icons.alternate_email_rounded,
                  color: const Color(0xFF1DA1F2),
                  label: 'X',
                  onTap: () => _shareToSocial('twitter'),
                ),
                _buildSocialIcon(
                  icon: Icons.telegram_rounded,
                  color: const Color(0xFF0088CC),
                  label: 'Telegram',
                  onTap: () => _shareToSocial('telegram'),
                ),
                _buildSocialIcon(
                  icon: Icons.mail_rounded,
                  color: const Color(0xFFEA4335),
                  label: 'Email',
                  onTap: () => _shareToSocial('email'),
                ),
                _buildSocialIcon(
                  icon: Icons.more_horiz_rounded,
                  color: AppColors.textSecondary,
                  label: 'More',
                  onTap: () => _shareNative(),
                ),
              ],
            ),
          ),

          // Link Copy Section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copy Link',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.bgDivider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          url,
                          style: GoogleFonts.robotoMono(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _copyToClipboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Copy'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToSocial(String platform) async {
    // For now, we'll use the native share sheet for all of them
    // but in a real app you might use url_launcher for specific platforms
    _shareNative();
  }

  void _shareNative() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Check this out on Truthworld: $title\n$url',
        subject: title,
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: url));
    Get.back();
    Get.snackbar(
      'Copied',
      'Link copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }
}
