import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';

class SubtitleStylePanel extends StatelessWidget {
  const SubtitleStylePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Subtitle Appearance',
          onBack: () => ctrl.activePanel.value = 'subtitles',
          onClose: null,
        ),
        const SizedBox(height: 4),
        // Live Video Scene Preview Box
        Obx(() {
          final fontSizeOpt =
              TowerPlayerController.globalSubtitleFontSizeOption.value;
          final textColor = TowerPlayerController.globalSubtitleTextColor.value;
          final bgColor = TowerPlayerController.globalSubtitleBgColor.value;
          final bgOpacity = TowerPlayerController.globalSubtitleBgOpacity.value;
          final edgeStyle = TowerPlayerController.globalSubtitleEdgeStyle.value;
          final fontFamily =
              TowerPlayerController.globalSubtitleFontFamily.value;

          var previewFontSize = 13.0;
          if (fontSizeOpt == 'Small') previewFontSize = 11.0;
          if (fontSizeOpt == 'Large') previewFontSize = 15.0;
          if (fontSizeOpt == 'Extra Large') previewFontSize = 17.0;

          var shadows = const <Shadow>[];
          if (edgeStyle == 'Drop Shadow') {
            shadows = const [
              Shadow(blurRadius: 4, offset: Offset(1, 1)),
            ];
          } else if (edgeStyle == 'Raised') {
            shadows = const [
              Shadow(
                blurRadius: 1,
                offset: Offset(-1, -1),
              ),
              Shadow(blurRadius: 3, offset: Offset(2, 2)),
            ];
          } else if (edgeStyle == 'Outline') {
            shadows = const [
              Shadow(
                blurRadius: 1,
                offset: Offset(-1, -1),
              ),
              Shadow(blurRadius: 1, offset: Offset(1, -1)),
              Shadow(blurRadius: 1, offset: Offset(-1, 1)),
              Shadow(blurRadius: 1, offset: Offset(1, 1)),
            ];
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                  Color(0xFF020617),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -20,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.indigo.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -25,
                          left: -10,
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.blueAccent.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 36,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 10,
                  right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.live_tv_rounded,
                            size: 12,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VIDEO PREVIEW',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'HD CC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 10,
                  right: 10,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor.withValues(alpha: bgOpacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'This is how your subtitles will look during video playback.',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TowerPlayerController.getSubtitleTextStyle(
                          fontFamily: fontFamily,
                          color: textColor,
                          fontSize: previewFontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          shadows: shadows,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const PlayerDivider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              // 1. Font Family
              _buildSectionHeader('Font Family'),
              Obx(
                () => Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      [
                        'Roboto',
                        'Merriweather',
                        'Roboto Mono',
                        'Oswald',
                        'Outfit',
                      ].map((familyOpt) {
                        final selected =
                            TowerPlayerController
                                .globalSubtitleFontFamily
                                .value ==
                            familyOpt;
                        return ChoiceChip(
                          label: Text(
                            familyOpt,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: selected,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white10,
                          showCheckmark: false,
                          onSelected: (_) =>
                              TowerPlayerController
                                      .globalSubtitleFontFamily
                                      .value =
                                  familyOpt,
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // 2. Font Size
              _buildSectionHeader('Font Size'),
              Obx(
                () => Row(
                  children: ['Small', 'Normal', 'Large', 'Extra Large'].map((
                    opt,
                  ) {
                    final selected =
                        TowerPlayerController
                            .globalSubtitleFontSizeOption
                            .value ==
                        opt;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: selected,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white10,
                          showCheckmark: false,
                          onSelected: (_) =>
                              TowerPlayerController
                                      .globalSubtitleFontSizeOption
                                      .value =
                                  opt,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Text Color Palette
              _buildSectionHeader('Font Color'),
              Obx(
                () => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ColorOption(
                        color: Colors.white,
                        label: 'White',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                    .globalSubtitleTextColor
                                    .value =
                                Colors.white,
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: const Color(0xFFFFEB3B),
                        label: 'Yellow',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                .globalSubtitleTextColor
                                .value = const Color(
                              0xFFFFEB3B,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: const Color(0xFF00E5FF),
                        label: 'Cyan',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                .globalSubtitleTextColor
                                .value = const Color(
                              0xFF00E5FF,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: const Color(0xFF76FF03),
                        label: 'Green',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                .globalSubtitleTextColor
                                .value = const Color(
                              0xFF76FF03,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: const Color(0xFFFF4081),
                        label: 'Pink',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                .globalSubtitleTextColor
                                .value = const Color(
                              0xFFFF4081,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: const Color(0xFFFF9800),
                        label: 'Orange',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                .globalSubtitleTextColor
                                .value = const Color(
                              0xFFFF9800,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: const Color(0xFFFF3D00),
                        label: 'Red',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                .globalSubtitleTextColor
                                .value = const Color(
                              0xFFFF3D00,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _ColorOption(
                        color: Colors.black,
                        label: 'Black',
                        current:
                            TowerPlayerController.globalSubtitleTextColor.value,
                        onTap: () =>
                            TowerPlayerController
                                    .globalSubtitleTextColor
                                    .value =
                                Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 4. Background Color & Opacity
              _buildSectionHeader('Background Color & Opacity'),
              Obx(
                () => Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _BgOption(
                      label: 'Black 75%',
                      color: Colors.black,
                      opacity: 0.75,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            Colors.black;
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            0.75;
                      },
                    ),
                    _BgOption(
                      label: 'Black 50%',
                      color: Colors.black,
                      opacity: 0.50,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            Colors.black;
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            0.50;
                      },
                    ),
                    _BgOption(
                      label: 'Solid Black',
                      color: Colors.black,
                      opacity: 1.0,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            Colors.black;
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            1.0;
                      },
                    ),
                    _BgOption(
                      label: 'Transparent',
                      color: Colors.transparent,
                      opacity: 0.0,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            Colors.transparent;
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            0.0;
                      },
                    ),
                    _BgOption(
                      label: 'Navy 75%',
                      color: const Color(0xFF0F172A),
                      opacity: 0.75,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            const Color(0xFF0F172A);
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            0.75;
                      },
                    ),
                    _BgOption(
                      label: 'Yellow 75%',
                      color: const Color(0xFFFBC02D),
                      opacity: 0.75,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            const Color(0xFFFBC02D);
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            0.75;
                      },
                    ),
                    _BgOption(
                      label: 'White 75%',
                      color: Colors.white,
                      opacity: 0.75,
                      curColor:
                          TowerPlayerController.globalSubtitleBgColor.value,
                      curOpacity:
                          TowerPlayerController.globalSubtitleBgOpacity.value,
                      onTap: () {
                        TowerPlayerController.globalSubtitleBgColor.value =
                            Colors.white;
                        TowerPlayerController.globalSubtitleBgOpacity.value =
                            0.75;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 5. Text Shadow / Edge Style
              _buildSectionHeader('Text Shadow / Edge'),
              Obx(
                () => Row(
                  children: ['Drop Shadow', 'Outline', 'Raised', 'None'].map((
                    styleOpt,
                  ) {
                    final selected =
                        TowerPlayerController.globalSubtitleEdgeStyle.value ==
                        styleOpt;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(
                            styleOpt,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: selected,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white10,
                          showCheckmark: false,
                          onSelected: (_) =>
                              TowerPlayerController
                                      .globalSubtitleEdgeStyle
                                      .value =
                                  styleOpt,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton.icon(
                  onPressed: TowerPlayerController.resetSubtitleStyleToDefault,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    'Reset to Industry Defaults',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TS.bodySm.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.label,
    required this.current,
    required this.onTap,
  });

  final Color color;
  final String label;
  final Color current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = current.value == color.value;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 13,
                    color:
                        color == Colors.white ||
                            color == const Color(0xFFFFEB3B) ||
                            color == const Color(0xFF76FF03) ||
                            color == const Color(0xFF00E5FF)
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _BgOption extends StatelessWidget {
  const _BgOption({
    required this.label,
    required this.color,
    required this.opacity,
    required this.curColor,
    required this.curOpacity,
    required this.onTap,
  });

  final String label;
  final Color color;
  final double opacity;
  final Color curColor;
  final double curOpacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected =
        curColor.value == color.value && (curOpacity - opacity).abs() < 0.05;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isSelected ? Colors.black : Colors.white,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.white,
      backgroundColor: Colors.white10,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}
