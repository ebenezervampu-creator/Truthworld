import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/theme/app_theme.dart';

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

  static String? get globalQualityPreference {
    final val = _box.read('pref_global_quality_preference');
    if (val == null || val == '144p') return 'Auto';
    return val as String;
  }
  static set globalQualityPreference(String? value) =>
      _box.write('pref_global_quality_preference', value);

  // Audio-only mode themes
  static final Rx<AudioPlayerTheme> globalAudioTheme = Rx<AudioPlayerTheme>(
    _loadSavedAudioTheme(),
  );

  static AudioPlayerTheme _loadSavedAudioTheme() {
    final saved = _box.read('pref_global_audio_theme');
    if (saved != null) {
      for (final theme in AudioPlayerTheme.values) {
        if (theme.name == saved) return theme;
      }
    }
    return AudioPlayerTheme.ambientGlow;
  }

  static AudioPlayerTheme get globalAudioThemeValue => globalAudioTheme.value;

  static set globalAudioThemeValue(AudioPlayerTheme theme) {
    globalAudioTheme.value = theme;
    _box.write('pref_global_audio_theme', theme.name);
  }

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
    final resolvedFamily = switch (fontFamily) {
      'Merriweather' => 'serif',
      'Roboto Mono' => 'monospace',
      'Oswald' || 'Outfit' => TWTypography.brandFamily,
      'Roboto' || _ => TWTypography.uiFamily,
    };

    return TextStyle(
      fontFamily: resolvedFamily,
      fontFamilyFallback: TWTypography.fallbackFamilies,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      shadows: shadows,
    );
  }
}

/// Available aesthetic themes for TruthWorld Audio-Only mode.
enum AudioPlayerTheme {
  ambientGlow,
  retroVinyl,
  cyberSpectrum,
  lyricalStage,
  zenAura,
  vintageCassette,
  analogVuMeter,
  cosmicNebula,
  holographicCd,
  fluidHorizon;

  String get displayName {
    switch (this) {
      case AudioPlayerTheme.ambientGlow:
        return 'Ambient Studio Glow';
      case AudioPlayerTheme.retroVinyl:
        return 'Classic Vinyl Turntable';
      case AudioPlayerTheme.cyberSpectrum:
        return 'Studio Acoustic Spectrum';
      case AudioPlayerTheme.lyricalStage:
        return 'Lyrical Stage';
      case AudioPlayerTheme.zenAura:
        return 'Minimalist Zen Flow';
      case AudioPlayerTheme.vintageCassette:
        return 'Vintage Reel-to-Reel Tape';
      case AudioPlayerTheme.analogVuMeter:
        return 'Precision VU Meters';
      case AudioPlayerTheme.cosmicNebula:
        return 'Celestial Orbit';
      case AudioPlayerTheme.holographicCd:
        return 'Prism Compact Disc';
      case AudioPlayerTheme.fluidHorizon:
        return 'Fluid Horizon Waves';
    }
  }

  String get description {
    switch (this) {
      case AudioPlayerTheme.ambientGlow:
        return 'Dynamic album ambient diffusion with breathing halo';
      case AudioPlayerTheme.retroVinyl:
        return 'Audiophile grooved disc with rotating album artwork';
      case AudioPlayerTheme.cyberSpectrum:
        return 'Precision acoustic equalizer with reflective studio bars';
      case AudioPlayerTheme.lyricalStage:
        return 'Kinetic typographic presentation with frosted glass backdrop';
      case AudioPlayerTheme.zenAura:
        return 'Tranquil harmonic acoustic ripples on velvet obsidian';
      case AudioPlayerTheme.vintageCassette:
        return 'Analog studio master tape machine with rotating precision reels';
      case AudioPlayerTheme.analogVuMeter:
        return 'Dual high-end dark glass analog meters with ballistic response';
      case AudioPlayerTheme.cosmicNebula:
        return 'Deep space void with planetary orb and orbiting stardust';
      case AudioPlayerTheme.holographicCd:
        return 'Precision metallic mirror disc with frosted jewel case';
      case AudioPlayerTheme.fluidHorizon:
        return 'Silky multi-layered harmonic ribbon waves across obsidian horizon';
    }
  }

  IconData get icon {
    switch (this) {
      case AudioPlayerTheme.ambientGlow:
        return Icons.auto_awesome_rounded;
      case AudioPlayerTheme.retroVinyl:
        return Icons.album_rounded;
      case AudioPlayerTheme.cyberSpectrum:
        return Icons.graphic_eq_rounded;
      case AudioPlayerTheme.lyricalStage:
        return Icons.mic_external_on_rounded;
      case AudioPlayerTheme.zenAura:
        return Icons.spa_rounded;
      case AudioPlayerTheme.vintageCassette:
        return Icons.radio_rounded;
      case AudioPlayerTheme.analogVuMeter:
        return Icons.speed_rounded;
      case AudioPlayerTheme.cosmicNebula:
        return Icons.brightness_medium_rounded;
      case AudioPlayerTheme.holographicCd:
        return Icons.disc_full_rounded;
      case AudioPlayerTheme.fluidHorizon:
        return Icons.waves_rounded;
    }
  }
}

