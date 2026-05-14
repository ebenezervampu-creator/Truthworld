/// Poll types supported for community posts.
enum PollType { yesNo, multiChoice }

/// A single option inside a poll.
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterIds;

  const PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.voterIds = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'voteCount': voteCount,
    'voterIds': voterIds,
  };

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
    id: map['id'] ?? '',
    text: map['text'] ?? '',
    voteCount: map['voteCount'] ?? 0,
    voterIds: List<String>.from(map['voterIds'] ?? []),
  );

  PollOption copyWith({
    String? id,
    String? text,
    int? voteCount,
    List<String>? voterIds,
  }) => PollOption(
    id: id ?? this.id,
    text: text ?? this.text,
    voteCount: voteCount ?? this.voteCount,
    voterIds: voterIds ?? this.voterIds,
  );
}

/// Poll model supporting yes/no and multi-choice polls.
///
/// - [PollType.yesNo]: 2 options ("Yes", "No")
/// - [PollType.multiChoice]: 3–5 custom options
class PollModel {
  final String question;
  final PollType type;
  final List<PollOption> options;
  final DateTime? expiresAt;
  final bool isClosed;

  const PollModel({
    required this.question,
    required this.type,
    required this.options,
    this.expiresAt,
    this.isClosed = false,
  });

  /// Total votes across all options.
  int get totalVotes => options.fold(0, (sum, o) => sum + o.voteCount);

  /// Quick factory for a yes/no poll.
  factory PollModel.yesNo({required String question, DateTime? expiresAt}) =>
      PollModel(
        question: question,
        type: PollType.yesNo,
        options: [
          PollOption(id: 'yes', text: 'Yes'),
          PollOption(id: 'no', text: 'No'),
        ],
        expiresAt: expiresAt,
      );

  Map<String, dynamic> toMap() => {
    'question': question,
    'type': type.name,
    'options': options.map((o) => o.toMap()).toList(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'isClosed': isClosed,
  };

  factory PollModel.fromMap(Map<String, dynamic> map) => PollModel(
    question: map['question'] ?? '',
    type: PollType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => PollType.yesNo,
    ),
    options:
        (map['options'] as List<dynamic>?)
            ?.map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
            .toList() ??
        [],
    expiresAt: map['expiresAt'] != null
        ? DateTime.tryParse(map['expiresAt'])
        : null,
    isClosed: map['isClosed'] ?? false,
  );

  PollModel copyWith({
    String? question,
    PollType? type,
    List<PollOption>? options,
    DateTime? expiresAt,
    bool? isClosed,
  }) => PollModel(
    question: question ?? this.question,
    type: type ?? this.type,
    options: options ?? this.options,
    expiresAt: expiresAt ?? this.expiresAt,
    isClosed: isClosed ?? this.isClosed,
  );
}





