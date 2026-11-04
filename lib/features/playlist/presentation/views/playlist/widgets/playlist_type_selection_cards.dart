import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
/// Selection cards allowing users and creators to switch between Private and Public playlists.
class PlaylistTypeSelectionCards extends StatelessWidget {
  const PlaylistTypeSelectionCards({
    required this.selectedType,
    required this.onTypeSelected,
    super.key,
  });

  final RxString selectedType;
  final ValueChanged<String> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = selectedType.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Playlist Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a type to view and manage your playlists',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.normal,
                color: const Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 580;

                final privateCard = PlaylistSelectionCard(
                  type: 'private',
                  isSelected: selected == 'private',
                  icon: Icons.lock_outline_rounded,
                  title: 'Private Playlists',
                  subtitle: 'Personal saved playlists & private videos',
                  onTap: () => onTypeSelected('private'),
                );

                final publicCard = PlaylistSelectionCard(
                  type: 'public',
                  isSelected: selected == 'public',
                  icon: Icons.public_rounded,
                  title: 'Public Playlists',
                  subtitle: 'Public playlists hosted on your channel',
                  onTap: () => onTypeSelected('public'),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      privateCard,
                      const SizedBox(height: 10),
                      publicCard,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: privateCard),
                    const SizedBox(width: 14),
                    Expanded(child: publicCard),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

class PlaylistSelectionCard extends StatelessWidget {
  const PlaylistSelectionCard({
    required this.type,
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String type;
  final bool isSelected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _goldAccent = Color(0xFFEAB308);
  static const Color _goldBadge = AppColors.warning;
  static const Color _goldIconBg = Color(0xFF251E0E);
  static const Color _goldBorder = Color(0xFF785618);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _goldAccent : AppColors.bgSurface,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? _goldIconBg : const Color(0xFF222222),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _goldBorder : const Color(0xFF2C2C2C),
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isSelected ? _goldBadge : Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFF8E8E93),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _goldBadge,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 15,
                  ),
                ),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF3E3E3E),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
