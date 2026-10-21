import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';

/// Reactive user profile header displayed at the top of the Library screen.
class LibraryProfileHeader extends StatelessWidget {
  const LibraryProfileHeader({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value && authService.userChannel != null;
      final channel = authService.userChannel;

      final displayName = authService.activeDisplayName;
      final handleOrEmail = hasChannel
          ? (channel!.handle.startsWith('@') ? channel.handle : '@${channel.handle}')
          : (authService.user?.email ?? '');
      final avatarUrl = authService.activePhotoUrl;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: (hasChannel && channel != null)
                  ? StudioLauncher.openStudio
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    UserAvatar(
                      radius: 40,
                      photoUrl: avatarUrl,
                      displayName: displayName,
                      backgroundColor: buttonBg,
                      textColor: primaryText,
                      fontSize: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          if (handleOrEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              handleOrEmail,
                              style: const TextStyle(
                                fontSize: 14,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
