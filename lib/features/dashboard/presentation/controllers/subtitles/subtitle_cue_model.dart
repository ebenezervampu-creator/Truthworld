/// Status of a subtitle language track
enum SubtitleTrackStatus {
  published,
  draft,
  notAdded;

  String get label {
    switch (this) {
      case SubtitleTrackStatus.published:
        return 'Published';
      case SubtitleTrackStatus.draft:
        return 'Draft';
      case SubtitleTrackStatus.notAdded:
        return 'Not added';
    }
  }
}

/// Internal Cue Representation for visual preview and editing
class SubtitleCue {
  SubtitleCue({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  String id;
  String startTime;
  String endTime;
  String text;

  SubtitleCue copyWith({
    String? id,
    String? startTime,
    String? endTime,
    String? text,
  }) {
    return SubtitleCue(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      text: text ?? this.text,
    );
  }

  @override
  String toString() => 'SubtitleCue(id: $id, $startTime --> $endTime, text: $text)';
}
