import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Configuration presets for Avatar crop (1:1 circular/square crop, max quality up to 2048x2048).
class AvatarCropConfig {
  const AvatarCropConfig._();
  static const int maxWidth = 2048;
  static const int maxHeight = 2048;
  static const CropAspectRatio aspectRatio = CropAspectRatio(ratioX: 1, ratioY: 1);
  static const CropStyle cropStyle = CropStyle.circle;
  static const ImageCompressFormat compressFormat = ImageCompressFormat.jpg;
  static const int compressQuality = 100; // Maximum available quality
}

/// Configuration presets for Banner crop (16:9 widescreen canvas, max quality up to 2560x1440).
class BannerCropConfig {
  const BannerCropConfig._();
  static const int maxWidth = 2560;
  static const int maxHeight = 1440;
  static const CropAspectRatio aspectRatio = CropAspectRatio(ratioX: 16, ratioY: 9);
  static const CropStyle cropStyle = CropStyle.rectangle;
  static const ImageCompressFormat compressFormat = ImageCompressFormat.jpg;
  static const int compressQuality = 100; // Maximum available quality
}

/// Centralized service for cropping Channel Avatar, Channel Banner, Custom Topic images, and Playlist Artwork.
/// Implements YouTube & Spotify industry standards:
/// - Channel Avatar: 1:1 square aspect ratio with circular crop style/preview.
/// - Channel Banner: 16:9 widescreen canvas (2560x1440).
/// - Dynamic Image Cropping (Topics & Playlists): Unlocked multi-aspect ratio editor (1:1, 4:5, 16:9, 3:2, Original).
/// - Playlist Artwork: Dynamic aspect ratios with 16:9 default preset.
/// Preserves maximum image quality with zero unnecessary downscaling (compressQuality: 100).
/// Adheres strictly to icon color guidelines (Icons must always be white).
class ImageCropperService {
  ImageCropperService._();

  static final ImageCropper _cropper = ImageCropper();

  /// Generic dynamic crop editor supporting flexible aspect ratio selection.
  static Future<CroppedFile?> cropDynamicImage({
    required String imagePath,
    required String title,
    BuildContext? context,
    CropAspectRatioPreset initAspectRatio = CropAspectRatioPreset.square,
    bool lockAspectRatio = false,
    List<CropAspectRatioPreset> aspectRatioPresets = const [
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio16x9,
      CropAspectRatioPreset.ratio4x3,
      CropAspectRatioPreset.ratio5x4,
      CropAspectRatioPreset.ratio7x5,
      CropAspectRatioPreset.ratio3x2,
      CropAspectRatioPreset.original,
    ],
    int maxWidth = 2048,
    int maxHeight = 2048,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 100,
  }) async {
    try {
      return await _cropper.cropImage(
        sourcePath: imagePath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        compressFormat: compressFormat,
        compressQuality: compressQuality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: Colors.white, // Rule: Icons must be white
            activeControlsWidgetColor: Colors.white,
            initAspectRatio: initAspectRatio,
            lockAspectRatio: lockAspectRatio,
            aspectRatioPresets: aspectRatioPresets,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: lockAspectRatio,
            aspectRatioPresets: aspectRatioPresets,
          ),
          if (context != null)
            _buildWebUiSettings(
              context: context,
              title: title,
              initAspectRatio: initAspectRatio,
            ),
        ],
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageCropperService] Error cropping dynamic image: $e\n$stackTrace');
      return null;
    }
  }

  /// Crop image for Channel Avatar according to YouTube standard (1:1 circular crop UI).
  static Future<CroppedFile?> cropChannelAvatar({
    required String imagePath,
    BuildContext? context,
  }) async {
    try {
      return await _cropper.cropImage(
        sourcePath: imagePath,
        maxWidth: AvatarCropConfig.maxWidth,
        maxHeight: AvatarCropConfig.maxHeight,
        aspectRatio: AvatarCropConfig.aspectRatio,
        compressQuality: AvatarCropConfig.compressQuality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Channel Avatar',
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: Colors.white, // Rule: Icons must be white
            activeControlsWidgetColor: Colors.white,
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Channel Avatar',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          if (context != null)
            _buildWebUiSettings(
              context: context,
              title: 'Crop Channel Avatar',
              aspectRatio: AvatarCropConfig.aspectRatio,
              initAspectRatio: CropAspectRatioPreset.square,
            ),
        ],
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageCropperService] Error cropping channel avatar: $e\n$stackTrace');
      return null;
    }
  }

  /// Crop image for Channel Banner according to YouTube standard (16:9 canvas).
  static Future<CroppedFile?> cropChannelBanner({
    required String imagePath,
    BuildContext? context,
  }) async {
    try {
      return await _cropper.cropImage(
        sourcePath: imagePath,
        maxWidth: BannerCropConfig.maxWidth,
        maxHeight: BannerCropConfig.maxHeight,
        aspectRatio: BannerCropConfig.aspectRatio,
        compressQuality: BannerCropConfig.compressQuality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Channel Banner (16:9 Canvas)',
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: Colors.white, // Rule: Icons must be white
            activeControlsWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Channel Banner (16:9 Canvas)',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          if (context != null)
            _buildWebUiSettings(
              context: context,
              title: 'Crop Channel Banner (16:9 Canvas)',
              aspectRatio: BannerCropConfig.aspectRatio,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              isBannerCrop: true,
            ),
        ],
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageCropperService] Error cropping channel banner: $e\n$stackTrace');
      return null;
    }
  }

  /// Builds a responsive, dark-themed WebUiSettings dialog that prevents RenderFlex overflow on Web.
  static WebUiSettings _buildWebUiSettings({
    required BuildContext context,
    required String title,
    CropAspectRatio? aspectRatio,
    CropAspectRatioPreset? initAspectRatio,
    bool isBannerCrop = false,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    // Reserve ~260px for dialog header, sliders, dividers, footer buttons, and dialog padding
    final maxAvailableHeight = (screenSize.height - 260.0).clamp(180.0, 480.0);
    final maxAvailableWidth = (screenSize.width - 64.0).clamp(240.0, 520.0);

    double cropperWidth;
    double cropperHeight;

    if (aspectRatio != null && aspectRatio.ratioY > 0) {
      final targetRatio = aspectRatio.ratioX / aspectRatio.ratioY;
      cropperWidth = maxAvailableWidth;
      cropperHeight = cropperWidth / targetRatio;

      if (cropperHeight > maxAvailableHeight) {
        cropperHeight = maxAvailableHeight;
        cropperWidth = cropperHeight * targetRatio;
      }
    } else if (initAspectRatio == CropAspectRatioPreset.ratio16x9) {
      const targetRatio = 16.0 / 9.0;
      cropperWidth = maxAvailableWidth;
      cropperHeight = cropperWidth / targetRatio;
      if (cropperHeight > maxAvailableHeight) {
        cropperHeight = maxAvailableHeight;
        cropperWidth = cropperHeight * targetRatio;
      }
    } else {
      // Dynamic / square default
      final minDimension = maxAvailableWidth < maxAvailableHeight ? maxAvailableWidth : maxAvailableHeight;
      cropperWidth = minDimension.clamp(260.0, 440.0);
      cropperHeight = minDimension.clamp(200.0, 380.0);
    }

    return WebUiSettings(
      context: context,
      barrierColor: AppColors.bgPage54,
      size: CropperSize(
        width: cropperWidth.toInt(),
        height: cropperHeight.toInt(),
      ),
      customDialogBuilder: (cropper, initCropper, crop, rotate, scale) {
        return _TruthworldWebCropperDialog(
          cropper: cropper,
          initCropper: initCropper,
          crop: crop,
          rotate: rotate,
          scale: scale,
          title: title,
          cropperWidth: cropperWidth,
          cropperHeight: cropperHeight,
          showBannerGuide: isBannerCrop,
        );
      },
    );
  }

  /// Crop image for Custom Topic Artwork supporting dynamic multi-aspect ratios.
  static Future<CroppedFile?> cropTopicThumbnail({
    required String imagePath,
    BuildContext? context,
  }) async {
    return cropDynamicImage(
      imagePath: imagePath,
      title: 'Crop Topic Artwork',
      context: context,
    );
  }

  /// Crop image for Custom Playlist Artwork (Default: 16:9 preset, dynamic ratios supported).
  static Future<CroppedFile?> cropPlaylistArtwork({
    required String imagePath,
    BuildContext? context,
  }) async {
    return cropDynamicImage(
      imagePath: imagePath,
      title: 'Crop Playlist Artwork',
      context: context,
      initAspectRatio: CropAspectRatioPreset.ratio16x9, // Default 16:9 for playlist cover
    );
  }

  /// Crop image for Community Posts (Default: Original preset, flexible dynamic ratios).
  /// Preserves screenshots, infographics, and photos without forced auto-cropping.
  static Future<CroppedFile?> cropCommunityPostImage({
    required String imagePath,
    BuildContext? context,
  }) async {
    return cropDynamicImage(
      imagePath: imagePath,
      title: 'Crop Post Image',
      context: context,
      initAspectRatio: CropAspectRatioPreset.original, // Default Original so infographics/screenshots are preserved
      aspectRatioPresets: const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio5x4,
        CropAspectRatioPreset.ratio16x9,
      ],
    );
  }

  /// Crop image for Video / Short Thumbnail (Dynamic presets: Original, 16:9, 1:1, 4:5, 3:2).
  static Future<CroppedFile?> cropVideoThumbnail({
    required String imagePath,
    BuildContext? context,
  }) async {
    return cropDynamicImage(
      imagePath: imagePath,
      title: 'Crop Video Thumbnail',
      context: context,
      initAspectRatio: CropAspectRatioPreset.original,
      aspectRatioPresets: const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio16x9,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio5x4,
        CropAspectRatioPreset.ratio7x5,
        CropAspectRatioPreset.ratio3x2,
      ],
    );
  }
}

/// Custom responsive dialog for Web platform image cropping.
/// Prevents RenderFlex bottom overflow on smaller screens/viewports by providing scrollability,
/// dynamic sizing, and branded dark UI (strictly adhering to white icon guidelines).
class _TruthworldWebCropperDialog extends StatefulWidget {
  final Widget cropper;
  final VoidCallback initCropper;
  final Future<String?> Function() crop;
  final void Function(RotationAngle) rotate;
  final void Function(num) scale;
  final String title;
  final double cropperWidth;
  final double cropperHeight;
  final bool showBannerGuide;

  const _TruthworldWebCropperDialog({
    required this.cropper,
    required this.initCropper,
    required this.crop,
    required this.rotate,
    required this.scale,
    required this.title,
    required this.cropperWidth,
    required this.cropperHeight,
    this.showBannerGuide = false,
  });

  @override
  State<_TruthworldWebCropperDialog> createState() => _TruthworldWebCropperDialogState();
}

class _TruthworldWebCropperDialogState extends State<_TruthworldWebCropperDialog> {
  final RxBool _isCropping = false.obs;
  final RxDouble _scaleValue = 1.0.obs;

  @override
  void initState() {
    super.initState();
    widget.initCropper();
  }

  Future<void> _handleCrop() async {
    if (_isCropping.value) return;
    _isCropping.value = true;
    try {
      final result = await widget.crop();
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e, stackTrace) {
      debugPrint('[ImageCropper] Web crop error: $e\n$stackTrace');
      _isCropping.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.cropperWidth + 48.0,
          maxHeight: MediaQuery.sizeOf(context).height - 32.0,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const Divider(color: AppColors.bgDivider, height: 1.0),
                const SizedBox(height: 16.0),

                // Cropper View Area
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: SizedBox(
                      width: widget.cropperWidth,
                      height: widget.cropperHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.cropper,
                          if (widget.showBannerGuide)
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _YouTubeBannerGuidePainter(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.showBannerGuide) ...[
                  const SizedBox(height: 10.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'YouTube Safe Area: Text and logos stay safe inside the central box on all devices (mobile, tablet & desktop).',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16.0),

                // Action Bar (Rotate + Scale Controls)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Rotate Counter-Clockwise',
                      icon: const Icon(
                        Icons.rotate_90_degrees_ccw_rounded,
                        color: Colors.white, // Rule: White icon
                        size: 22,
                      ),
                      onPressed: () => widget.rotate(RotationAngle.counterClockwise90),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: AppColors.bgDivider,
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.12),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          trackHeight: 3.0,
                        ),
                        child: Obx(
                          () => Slider(
                            value: _scaleValue.value,
                            min: 1.0,
                            max: 3.0,
                            onChanged: (val) {
                              _scaleValue.value = val;
                              widget.scale(val);
                            },
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Rotate Clockwise',
                      icon: const Icon(
                        Icons.rotate_90_degrees_cw_outlined,
                        color: Colors.white, // Rule: White icon
                        size: 22,
                      ),
                      onPressed: () => widget.rotate(RotationAngle.clockwise90),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const Divider(color: AppColors.bgDivider, height: 1.0),
                const SizedBox(height: 16.0),

                // Footer Buttons
                Obx(() {
                  final isCropping = _isCropping.value;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        ),
                        onPressed: isCropping ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.bgPage,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: isCropping ? null : _handleCrop,
                        child: isCropping
                            ? const SizedBox(
                                width: 18.0,
                                height: 18.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: AppColors.bgPage,
                                ),
                              )
                            : const Text(
                                'Crop & Save',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for drawing YouTube Standard Safe Area overlays during Banner Cropping.
/// Displays TV viewable (16:9 full canvas), Desktop viewable (2560x423), and All Devices Safe Area (1546x423).
class _YouTubeBannerGuidePainter extends CustomPainter {
  const _YouTubeBannerGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Desktop band (height: 29.375% = 423 / 1440, centered vertically)
    final desktopTop = h * 0.353125;
    final desktopBottom = h * 0.646875;

    // Safe area (width: 60.39% = 1546 / 2560, centered horizontally)
    final safeLeft = w * 0.198047;
    final safeRight = w * 0.801953;

    final shadePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // Shaded TV regions (top and bottom)
    canvas.drawRect(Rect.fromLTRB(0, 0, w, desktopTop), shadePaint);
    canvas.drawRect(Rect.fromLTRB(0, desktopBottom, w, h), shadePaint);

    // Shaded Desktop side regions (left and right)
    canvas.drawRect(Rect.fromLTRB(0, desktopTop, safeLeft, desktopBottom), shadePaint);
    canvas.drawRect(Rect.fromLTRB(safeRight, desktopTop, w, desktopBottom), shadePaint);

    // Safe Area boundary
    final safeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTRB(safeLeft, desktopTop, safeRight, desktopBottom), safeBorderPaint);

    // Desktop boundary lines (horizontal across canvas)
    final guideLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, desktopTop), Offset(safeLeft, desktopTop), guideLinePaint);
    canvas.drawLine(Offset(safeRight, desktopTop), Offset(w, desktopTop), guideLinePaint);
    canvas.drawLine(Offset(0, desktopBottom), Offset(safeLeft, desktopBottom), guideLinePaint);
    canvas.drawLine(Offset(safeRight, desktopBottom), Offset(w, desktopBottom), guideLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
