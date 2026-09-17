class AdComment {
  AdComment({
    required this.id,
    required this.adId,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.text,
    required this.createdAt,
    this.replyText,
    this.repliedAt,
    this.repliedBy,
  });

  factory AdComment.fromMap(Map<String, dynamic> map, String docId) {
    return AdComment(
      id: docId,
      adId: map['adId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      userProfilePicUrl: map['userProfilePicUrl'] ?? '',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      replyText: map['replyText'],
      repliedAt: map['repliedAt'] != null
          ? DateTime.parse(map['repliedAt'])
          : null,
      repliedBy: map['repliedBy'],
    );
  }
  final String id;
  final String adId;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String text;
  final DateTime createdAt;
  final String? replyText;
  final DateTime? repliedAt;
  final String? repliedBy;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adId': adId,
      'userId': userId,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'replyText': replyText,
      'repliedAt': repliedAt?.toIso8601String(),
      'repliedBy': repliedBy,
    };
  }
}
