
class VideoChapter {

  VideoChapter({
    required this.title,
    required this.startTime,
    this.thumbnailUrl,
  });

  factory VideoChapter.fromMap(Map<String, dynamic> map) {
    return VideoChapter(
      title: map['title'] ?? '',
      startTime: Duration(milliseconds: map['startTimeMs'] ?? 0),
      thumbnailUrl: map['thumbnailUrl'],
    );
  }
  final String title;
  final Duration startTime;
  final String? thumbnailUrl;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startTimeMs': startTime.inMilliseconds,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  String get formattedStartTime {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(startTime.inMinutes.remainder(60));
    final seconds = twoDigits(startTime.inSeconds.remainder(60));
    if (startTime.inHours > 0) {
      return '${twoDigits(startTime.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoChapter &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          startTime == other.startTime;

  @override
  int get hashCode => title.hashCode ^ startTime.hashCode;
}




