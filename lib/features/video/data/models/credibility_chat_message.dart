import 'package:truthworld/features/video/data/models/credibility_report.dart';

/// 💬 CredibilityChatMessage
///
/// Model representing a single turn in an AI Credibility Chat conversation,
/// carrying verified citations, timestamp references, and suggested follow-ups.
class CredibilityChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<UISource> sources;
  final List<String> suggestedFollowups;
  final String scope; // 'video' | 'claim'
  final int? claimIndex;
  final String? disclaimer;
  final bool isStreaming;

  CredibilityChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sources = const [],
    this.suggestedFollowups = const [],
    this.scope = 'video',
    this.claimIndex,
    this.disclaimer,
    this.isStreaming = false,
  });

  factory CredibilityChatMessage.user(String text, {String scope = 'video', int? claimIndex}) {
    return CredibilityChatMessage(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      scope: scope,
      claimIndex: claimIndex,
    );
  }

  factory CredibilityChatMessage.ai({
    required String text,
    List<UISource> sources = const [],
    List<String> suggestedFollowups = const [],
    String scope = 'video',
    int? claimIndex,
    String? disclaimer,
    bool isStreaming = false,
  }) {
    return CredibilityChatMessage(
      id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      sources: sources,
      suggestedFollowups: suggestedFollowups,
      scope: scope,
      claimIndex: claimIndex,
      disclaimer: disclaimer,
      isStreaming: isStreaming,
    );
  }

  CredibilityChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<UISource>? sources,
    List<String>? suggestedFollowups,
    String? scope,
    int? claimIndex,
    String? disclaimer,
    bool? isStreaming,
  }) {
    return CredibilityChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      suggestedFollowups: suggestedFollowups ?? this.suggestedFollowups,
      scope: scope ?? this.scope,
      claimIndex: claimIndex ?? this.claimIndex,
      disclaimer: disclaimer ?? this.disclaimer,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toHistoryMap() {
    return {
      'role': isUser ? 'user' : 'model',
      'content': text,
    };
  }
}
