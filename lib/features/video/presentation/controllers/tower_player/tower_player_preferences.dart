import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

/// Manages persistent media preferences and global subtitle typography options.
class TowerPlayerPreferences {
  static final _box = GetStorage();

  // Persistent media preferences
  static bool get globalSubtitlesEnabled =>
      _box.read('pref_global_subtitles_enabled') ?? false;
  static set globalSubtitlesEnabled(bool value) =>
      _box.write('pref_global_subtitles_enabled', value);

  static String get globalActiveSubLang =>
      _box.read('pref_global_active_sub_lang') ?? 'Off';
  static set globalActiveSubLang(String value) =>
      _box.write('pref_global_active_sub_lang', value);

  static bool get globalAudioOnly =>
      _box.read('pref_global_audio_only') ?? false;
  static set globalAudioOnly(bool value) =>
      _box.write('pref_global_audio_only', value);

  static double get globalPlaybackSpeed =>
      _box.read('pref_global_playback_speed') ?? 1.0;
  static set globalPlaybackSpeed(double value) =>
      _box.write('pref_global_playback_speed', value);

  static String? get globalQualityPreference =>
      _box.read('pref_global_quality_preference') ?? 'Auto';
  static set globalQualityPreference(String? value) =>
      _box.write('pref_global_quality_preference', value);

  // Global Subtitle Appearance Options
  static final RxString globalSubtitleFontSizeOption = 'Normal'.obs;
  static final Rx<Color> globalSubtitleTextColor = Colors.white.obs;
  static final Rx<Color> globalSubtitleBgColor = Colors.black.obs;
  static final RxDouble globalSubtitleBgOpacity = 0.75.obs;
  static final RxString globalSubtitleEdgeStyle = 'Drop Shadow'.obs;
  static final RxString globalSubtitleFontFamily = 'Roboto'.obs;

  static void resetSubtitleStyleToDefault() {
    globalSubtitleFontSizeOption.value = 'Normal';
    globalSubtitleTextColor.value = Colors.white;
    globalSubtitleBgColor.value = Colors.black;
    globalSubtitleBgOpacity.value = 0.75;
    globalSubtitleEdgeStyle.value = 'Drop Shadow';
    globalSubtitleFontFamily.value = 'Roboto';
  }

  static TextStyle getSubtitleTextStyle({
    required String fontFamily,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required List<Shadow> shadows,
  }) {
    switch (fontFamily) {
      case 'Merriweather':
        return GoogleFonts.merriweather(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Roboto Mono':
        return GoogleFonts.robotoMono(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Oswald':
        return GoogleFonts.oswald(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Outfit':
        return GoogleFonts.outfit(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Roboto':
      default:
        return GoogleFonts.roboto(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
    }
  }
}
