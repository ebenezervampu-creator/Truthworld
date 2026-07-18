import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

class Subscription {
  final String userId;
  final String channelId;
  final Timestamp? timestamp;
  final bool notificationsEnabled;

  Subscription({
    required this.userId,
    required this.channelId,
    this.timestamp,
    this.notificationsEnabled = true,
  });

  factory Subscription.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawTimestamp = data['subscribedAt'] ?? data['timestamp'];
    return Subscription(
      userId: data['userId'] ?? '',
      channelId: data['channelId'] ?? '',
      timestamp: rawTimestamp != null ? TimestampUtils.parse(rawTimestamp) : null,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'channelId': channelId,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'subscribedAt': timestamp ?? FieldValue.serverTimestamp(),
      'notificationsEnabled': notificationsEnabled,
    };
  }
}





