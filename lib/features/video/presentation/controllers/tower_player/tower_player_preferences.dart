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
      return AudioPlayerTheme.fromStorage(saved.toString());
    }
    return AudioPlayerTheme.fluidAura;
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
  fluidAura,
  kineticSyllable,
  audiophileSpectral,
  obsidianMinimalist,
  truthPulseHologram;

  /// Migrates legacy and stored preference keys to the new 5-theme architecture.
  static AudioPlayerTheme fromStorage(String? raw) {
    if (raw == null) return AudioPlayerTheme.fluidAura;
    return switch (raw) {
      'fluidAura' || 'ambientGlow' || 'retroVinyl' || 'vintageCassette' ||
      'cosmicNebula' || 'holographicCd' || 'fluidHorizon' =>
        AudioPlayerTheme.fluidAura,
      'kineticSyllable' || 'lyricalStage' => AudioPlayerTheme.kineticSyllable,
      'audiophileSpectral' || 'cyberSpectrum' || 'analogVuMeter' =>
        AudioPlayerTheme.audiophileSpectral,
      'obsidianMinimalist' || 'zenAura' => AudioPlayerTheme.obsidianMinimalist,
      'truthPulseHologram' => AudioPlayerTheme.truthPulseHologram,
      _ => AudioPlayerTheme.fluidAura,
    };
  }

  // Backward-compatibility aliases for legacy enum references
  static AudioPlayerTheme get ambientGlow => fluidAura;
  static AudioPlayerTheme get retroVinyl => fluidAura;
  static AudioPlayerTheme get cyberSpectrum => audiophileSpectral;
  static AudioPlayerTheme get lyricalStage => kineticSyllable;
  static AudioPlayerTheme get zenAura => obsidianMinimalist;
  static AudioPlayerTheme get vintageCassette => fluidAura;
  static AudioPlayerTheme get analogVuMeter => audiophileSpectral;
  static AudioPlayerTheme get cosmicNebula => fluidAura;
  static AudioPlayerTheme get holographicCd => fluidAura;
  static AudioPlayerTheme get fluidHorizon => fluidAura;

  String get displayName {
    switch (this) {
      case AudioPlayerTheme.fluidAura:
        return 'Fluid Aura Canvas';
      case AudioPlayerTheme.kineticSyllable:
        return 'Kinetic Syllable Stage';
      case AudioPlayerTheme.audiophileSpectral:
        return 'Audiophile Studio Spectral';
      case AudioPlayerTheme.obsidianMinimalist:
        return 'Obsidian Minimalist';
      case AudioPlayerTheme.truthPulseHologram:
        return 'TruthPulse Spatial Hologram';
    }
  }

  String get description {
    switch (this) {
      case AudioPlayerTheme.fluidAura:
        return 'Artwork-driven dynamic living aura with responsive zero-overflow scaling';
      case AudioPlayerTheme.kineticSyllable:
        return 'Word and sentence synchronized transcripts with tap-to-seek and truth verification';
      case AudioPlayerTheme.audiophileSpectral:
        return 'Three-band frequency visualizer with real-time RMS/peak levels and verified metadata';
      case AudioPlayerTheme.obsidianMinimalist:
        return 'Pure OLED deep black canvas engineered for battery saving, zero glare, and high contrast';
      case AudioPlayerTheme.truthPulseHologram:
        return 'Geometric acoustic orbital pulse with evaluated-only credibility illumination';
    }
  }

  IconData get icon {
    switch (this) {
      case AudioPlayerTheme.fluidAura:
        return Icons.auto_awesome_rounded;
      case AudioPlayerTheme.kineticSyllable:
        return Icons.subtitles_rounded;
      case AudioPlayerTheme.audiophileSpectral:
        return Icons.graphic_eq_rounded;
      case AudioPlayerTheme.obsidianMinimalist:
        return Icons.dark_mode_rounded;
      case AudioPlayerTheme.truthPulseHologram:
        return Icons.blur_circular_rounded;
    }
  }
}

