class AccessibilitySettings {
  const AccessibilitySettings({
    this.reduceMotion = false,
    this.disableAnimations = false,
    this.largeText = false,
    this.boldText = false,
    this.highContrastSubtitles = false,
    this.screenReaderOptimization = false,
    this.captionsAlwaysOn = false,
    this.captionSize = 'Medium',
    this.captionBackground = 'Black Box',
    this.captionOpacity = 0.8,
    this.captionFont = 'Sans-Serif',
    this.hapticFeedback = true,
    this.colorBlindSupport = 'Off',
    this.focusIndicators = true,
  });

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    return AccessibilitySettings(
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      disableAnimations: json['disableAnimations'] as bool? ?? false,
      largeText: json['largeText'] as bool? ?? false,
      boldText: json['boldText'] as bool? ?? false,
      highContrastSubtitles: json['highContrastSubtitles'] as bool? ?? false,
      screenReaderOptimization:
          json['screenReaderOptimization'] as bool? ?? false,
      captionsAlwaysOn: json['captionsAlwaysOn'] as bool? ?? false,
      captionSize: json['captionSize'] as String? ?? 'Medium',
      captionBackground: json['captionBackground'] as String? ?? 'Black Box',
      captionOpacity: (json['captionOpacity'] as num?)?.toDouble() ?? 0.8,
      captionFont: json['captionFont'] as String? ?? 'Sans-Serif',
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      colorBlindSupport: json['colorBlindSupport'] as String? ?? 'Off',
      focusIndicators: json['focusIndicators'] as bool? ?? true,
    );
  }
  final bool reduceMotion;
  final bool disableAnimations;
  final bool largeText;
  final bool boldText;
  final bool highContrastSubtitles;
  final bool screenReaderOptimization;
  final bool captionsAlwaysOn;
  final String captionSize; // 'Small', 'Medium', 'Large', 'Extra Large'
  final String captionBackground; // 'Black Box', 'Outline', 'Transparent'
  final double captionOpacity; // 0.0 to 1.0
  final String captionFont; // 'Sans-Serif', 'Monospace', 'Serif'
  final bool hapticFeedback;
  final String
  colorBlindSupport; // 'Off', 'Protanopia', 'Deuteranopia', 'Tritanopia'
  final bool focusIndicators;

  AccessibilitySettings copyWith({
    bool? reduceMotion,
    bool? disableAnimations,
    bool? largeText,
    bool? boldText,
    bool? highContrastSubtitles,
    bool? screenReaderOptimization,
    bool? captionsAlwaysOn,
    String? captionSize,
    String? captionBackground,
    double? captionOpacity,
    String? captionFont,
    bool? hapticFeedback,
    String? colorBlindSupport,
    bool? focusIndicators,
  }) {
    return AccessibilitySettings(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      disableAnimations: disableAnimations ?? this.disableAnimations,
      largeText: largeText ?? this.largeText,
      boldText: boldText ?? this.boldText,
      highContrastSubtitles:
          highContrastSubtitles ?? this.highContrastSubtitles,
      screenReaderOptimization:
          screenReaderOptimization ?? this.screenReaderOptimization,
      captionsAlwaysOn: captionsAlwaysOn ?? this.captionsAlwaysOn,
      captionSize: captionSize ?? this.captionSize,
      captionBackground: captionBackground ?? this.captionBackground,
      captionOpacity: captionOpacity ?? this.captionOpacity,
      captionFont: captionFont ?? this.captionFont,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      colorBlindSupport: colorBlindSupport ?? this.colorBlindSupport,
      focusIndicators: focusIndicators ?? this.focusIndicators,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reduceMotion': reduceMotion,
      'disableAnimations': disableAnimations,
      'largeText': largeText,
      'boldText': boldText,
      'highContrastSubtitles': highContrastSubtitles,
      'screenReaderOptimization': screenReaderOptimization,
      'captionsAlwaysOn': captionsAlwaysOn,
      'captionSize': captionSize,
      'captionBackground': captionBackground,
      'captionOpacity': captionOpacity,
      'captionFont': captionFont,
      'hapticFeedback': hapticFeedback,
      'colorBlindSupport': colorBlindSupport,
      'focusIndicators': focusIndicators,
    };
  }
}
