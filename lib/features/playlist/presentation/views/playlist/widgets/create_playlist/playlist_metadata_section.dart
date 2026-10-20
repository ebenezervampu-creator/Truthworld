import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Step 1: Playlist Name input section.
class PlaylistNameSection extends StatelessWidget {
  const PlaylistNameSection({
    required this.controller,
    super.key,
  });

  final CreatePlaylistController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1. Playlist Name',
                style: context.themeTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: controller.nameController,
                maxLength: 100,
                inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter playlist name',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  counterText: '',
                  fillColor: const Color(0xFF0F0F11),
                  filled: true,
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 60, 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                child: Obx(
                  () => Text(
                    '${controller.nameLength.value}/100',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Give your playlist a clear and catchy name.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2: Playlist Description input section.
class PlaylistDescriptionSection extends StatelessWidget {
  const PlaylistDescriptionSection({
    required this.controller,
    this.isDesktop = false,
    super.key,
  });

  final CreatePlaylistController controller;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final inputWidget = Stack(
      children: [
        TextField(
          controller: controller.descController,
          maxLines: 5,
          minLines: 5,
          maxLength: 500,
          textAlignVertical: TextAlignVertical.top,
          inputFormatters: TruthworldTextInputFormatters.withLimit(500),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Describe your playlist',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
            ),
            counterText: '',
            fillColor: const Color(0xFF0F0F11),
            filled: true,
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 10,
          child: Obx(
            () => Text(
              '${controller.descLength.value}/500',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Description (Optional)',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          inputWidget,
          const SizedBox(height: 8),
          Text(
            'Tell viewers what your playlist is about.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
