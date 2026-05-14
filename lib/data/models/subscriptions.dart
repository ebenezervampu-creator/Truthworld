import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final String userId;
  final String channelId;
  final Timestamp? timestamp;

  Subscription({required this.userId, required this.channelId, this.timestamp});

  factory Subscription.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Subscription(
      userId: data['userId'] ?? '',
      channelId: data['channelId'] ?? '',
      timestamp: data['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'channelId': channelId,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }
}





