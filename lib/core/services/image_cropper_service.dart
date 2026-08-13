import 'dart:async';
import 'package:flutter/material.dart';
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
            cropStyle: CropStyle.rectangle,
            initAspectRatio: initAspectRatio,
            lockAspectRatio: lockAspectRatio,
            aspectRatioPresets: aspectRatioPresets,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: title,
            cropStyle: CropStyle.rectangle,
            aspectRatioLockEnabled: lockAspectRatio,
            resetAspectRatioEnabled: true,
            aspectRatioPresets: aspectRatioPresets,
          ),
          if (context != null)
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
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
        compressFormat: AvatarCropConfig.compressFormat,
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
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
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
        compressFormat: BannerCropConfig.compressFormat,
        compressQuality: BannerCropConfig.compressQuality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Channel Banner (16:9 Canvas)',
            toolbarColor: AppColors.bgSurface,
            toolbarWidgetColor: Colors.white, // Rule: Icons must be white
            activeControlsWidgetColor: Colors.white,
            cropStyle: CropStyle.rectangle,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Channel Banner (16:9 Canvas)',
            cropStyle: CropStyle.rectangle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          if (context != null)
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
            ),
        ],
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageCropperService] Error cropping channel banner: $e\n$stackTrace');
      return null;
    }
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
      initAspectRatio: CropAspectRatioPreset.square,
      lockAspectRatio: false,
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
      lockAspectRatio: false, // Allows creators to choose 1:1, 4:5, 16:9, 3:2, original
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
      lockAspectRatio: false,
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
      lockAspectRatio: false,
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
