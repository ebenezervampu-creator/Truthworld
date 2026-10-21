import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Overlapping member avatar stack (facepile) for displaying channel members cleanly.
class MemberAvatarStack extends StatelessWidget {
  const MemberAvatarStack({
    required this.members,
    this.avatarRadius = 13,
    this.maxDisplay = 4,
    this.isDarkMode = true,
    this.borderWidth = 2,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final List<ChannelMember> members;
  final double avatarRadius;
  final int maxDisplay;
  final bool isDarkMode;
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    final displayMembers = members.take(maxDisplay).toList();
    final remaining = members.length - displayMembers.length;
    final diameter = avatarRadius * 2;
    final overlap = avatarRadius * 0.55;
    final itemExtent = diameter - overlap;
    final effectiveBorderColor = borderColor ??
        (isDarkMode ? AppColors.bgSurface : Colors.white);

    final totalWidth =
        (displayMembers.length + (remaining > 0 ? 1 : 0)) * itemExtent + overlap;

    final Widget stackWidget = SizedBox(
      height: diameter,
      width: totalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < displayMembers.length; i++)
            Positioned(
              left: i * itemExtent,
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: effectiveBorderColor,
                    width: borderWidth,
                  ),
                ),
                child: UserAvatar(
                  photoUrl: displayMembers[i].userAvatarUrl,
                  displayName: displayMembers[i].userName,
                  radius: (avatarRadius - borderWidth).clamp(6.0, 40.0),
                  showBorder: false,
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayMembers.length * itemExtent,
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode
                      ? AppColors.bgSurfaceHigh
                      : Colors.grey.shade300,
                  border: Border.all(
                    color: effectiveBorderColor,
                    width: borderWidth,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      fontSize: (avatarRadius * 0.72).clamp(8.0, 12.0),
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: stackWidget);
    }
    return stackWidget;
  }
}
