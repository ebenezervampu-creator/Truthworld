import 'package:cloud_firestore/cloud_firestore.dart';

class VideoReport {
  final String id;
  final String videoId;
  final String channelId;
  final String userId;
  final String userEmail;
  final String reasonId;
  final String reasonLabel;
  final String comment;
  final String status;
  final Timestamp createdAt;

  VideoReport({
    required this.id,
    required this.videoId,
    required this.channelId,
    this.userId = '',
    this.userEmail = '',
    required this.reasonId,
    required this.reasonLabel,
    required this.comment,
    required this.status,
    required this.createdAt,
  });

  factory VideoReport.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reasonData = data['reason'];
    
    String rId = '';
    String rLabel = '';
    
    if (reasonData is Map) {
      rId = reasonData['id']?.toString() ?? '';
      rLabel = reasonData['label']?.toString() ?? '';
    } else if (reasonData is String) {
      rId = reasonData.toLowerCase().replaceAll(' ', '_');
      rLabel = reasonData;
    }

    return VideoReport(
      id: doc.id,
      videoId: data['videoId'] ?? '',
      channelId: data['channelId'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      reasonId: rId,
      reasonLabel: rLabel,
      comment: data['comment'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] is Timestamp 
          ? data['createdAt'] 
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'channelId': channelId,
      'userId': userId,
      'userEmail': userEmail,
      'reason': {
        'id': reasonId,
        'label': reasonLabel,
      },
      'comment': comment,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
