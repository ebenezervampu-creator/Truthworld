import 'package:cloud_firestore/cloud_firestore.dart';

/// Poll types supported for community posts.
enum PollType { yesNo, multiChoice }

/// A single option inside a poll.
class PollOption {
  const PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.voterIds = const [],
  });

  factory PollOption.fromMap(Map<String, dynamic> map, [int fallbackIndex = 0]) {
    final rawId = (map['id'] ?? map['optionId'] ?? '').toString().trim();
    final rawVoters = map['voterIds'] ?? map['voters'];
    final votersList = <String>[];
    if (rawVoters is List) {
      votersList.addAll(rawVoters.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty));
    }

    final parsedCount = () {
      final val = map['voteCount'] ?? map['votes'] ?? map['count'];
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return votersList.length;
    }();

    return PollOption(
      id: rawId.isNotEmpty ? rawId : 'opt_$fallbackIndex',
      text: (map['text'] ?? map['option'] ?? '').toString().trim(),
      voteCount: parsedCount,
      voterIds: votersList,
    );
  }
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterIds;

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'voteCount': voteCount,
    'votes': voteCount,
    'voterIds': voterIds,
  };

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
  const PollModel({
    required this.question,
    required this.type,
    required this.options,
    this.expiresAt,
    this.isClosed = false,
  });

  /// Quick factory for a yes/no poll.
  factory PollModel.yesNo({required String question, DateTime? expiresAt}) =>
      PollModel(
        question: question,
        type: PollType.yesNo,
        options: [
          const PollOption(id: 'yes', text: 'Yes'),
          const PollOption(id: 'no', text: 'No'),
        ],
        expiresAt: expiresAt,
      );

  factory PollModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawOptions = map['options'] as List<dynamic>? ?? [];
    final optionsList = <PollOption>[];
    for (var i = 0; i < rawOptions.length; i++) {
      final item = rawOptions[i];
      if (item is Map) {
        optionsList.add(PollOption.fromMap(Map<String, dynamic>.from(item), i));
      } else if (item is String) {
        optionsList.add(PollOption(id: 'opt_$i', text: item));
      }
    }

    return PollModel(
      question: (map['question'] ?? '').toString().trim(),
      type: PollType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => PollType.yesNo,
      ),
      options: optionsList,
      expiresAt: parseDate(map['expiresAt']),
      isClosed: map['isClosed'] == true,
    );
  }

  final String question;
  final PollType type;
  final List<PollOption> options;
  final DateTime? expiresAt;
  final bool isClosed;

  /// Total votes across all options.
  int get totalVotes => options.fold(0, (sum, o) => sum + o.voteCount);

  /// Whether the poll is expired or closed.
  bool get isExpired => isClosed || (expiresAt != null && DateTime.now().isAfter(expiresAt!));

  /// Checks if a user has cast a vote.
  bool hasVoted(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    return options.any((o) => o.voterIds.contains(uid));
  }

  /// Returns the ID of the option voted for by [uid], if any.
  String? selectedOptionId(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    for (final opt in options) {
      if (opt.voterIds.contains(uid)) return opt.id;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'question': question,
    'type': type.name,
    'options': options.map((o) => o.toMap()).toList(),
    if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    'isClosed': isClosed,
  };

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
