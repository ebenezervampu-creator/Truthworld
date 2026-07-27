import 'package:cloud_firestore/cloud_firestore.dart';

class SavedCommentModel {
  SavedCommentModel({
    required this.id,
    required this.text,
    required this.userName,
    required this.userImage,
    required this.sourceType,
    required this.sourceId,
    required this.sourceTitle,
    required this.savedAt,
  });

  factory SavedCommentModel.fromMap(Map<String, dynamic> map, String docId) {
    return SavedCommentModel(
      id: docId,
      text: map['text'] ?? '',
      userName: map['userName'] ?? map['displayName'] ?? 'User',
      userImage: map['userImage'] ?? map['avatarUrl'] ?? map['userProfilePicUrl'] ?? '',
      sourceType: map['sourceType'] ?? 'video',
      sourceId: map['sourceId'] ?? '',
      sourceTitle: map['sourceTitle'] ?? map['title'] ?? '',
      savedAt: map['savedAt'] != null
          ? (map['savedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  final String id;
  final String text;
  final String userName;
  final String userImage;
  final String sourceType; // 'video', 'community_post', 'topic'
  final String sourceId;
  final String sourceTitle;
  final DateTime savedAt;

  Map<String, dynamic> toMap() => {
        'text': text,
        'userName': userName,
        'userImage': userImage,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'sourceTitle': sourceTitle,
        'savedAt': Timestamp.fromDate(savedAt),
      };
}
