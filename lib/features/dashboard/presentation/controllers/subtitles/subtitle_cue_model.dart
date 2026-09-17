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
