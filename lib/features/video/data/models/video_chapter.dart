class VideoChapter {
  VideoChapter({
    required this.title,
    required this.startTime,
    this.thumbnailUrl,
  });

  factory VideoChapter.fromMap(Map<String, dynamic> map) {
    // Support 'startTimeMs' (manual chapters in Firestore), 'startMs' (AI pipeline), and 'startTime' (seconds or ms or Duration)
    var parsedStartTime = Duration.zero;
    final rawStart =
        map['startTimeMs'] ??
        map['startMs'] ??
        map['startTime'] ??
        map['startSeconds'];

    if (rawStart is Duration) {
      parsedStartTime = rawStart;
    } else if (rawStart is num) {
      if (map.containsKey('startTimeMs') || map.containsKey('startMs')) {
        parsedStartTime = Duration(milliseconds: rawStart.toInt());
      } else if (rawStart > 100000) {
        parsedStartTime = Duration(milliseconds: rawStart.toInt());
      } else {
        parsedStartTime = Duration(seconds: rawStart.toInt());
      }
    }

    return VideoChapter(
      title: map['title'] ?? '',
      startTime: parsedStartTime,
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
