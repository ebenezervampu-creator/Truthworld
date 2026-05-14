import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportReason {
  sexual('Sexual content or exploitation'),
  hateful('Hateful or abusive language'),
  harassment('Harassment or bullying'),
  spam('Spam or misleading'),
  violent('Violent or repugnant content'),
  copyright('Copyright infringement'),
  other('Other');

  final String label;
  const ReportReason(this.label);
}

class CommentReport {
  final String id;
  final String commentId;
  final String? replyId; // Null if reporting comment, filled if reporting reply
  final String videoId;
  final String reporterId;
  final String reporterName;
  final ReportReason reason;
  final String? description;
  final Timestamp createdAt;
  final bool isResolved;
  final String? resolvedBy; // Admin/Moderator ID
  final String? resolution; // Notes on resolution

  CommentReport({
    required this.id,
    required this.commentId,
    this.replyId,
    required this.videoId,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    this.description,
    required this.createdAt,
    this.isResolved = false,
    this.resolvedBy,
    this.resolution,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commentId': commentId,
      'replyId': replyId,
      'videoId': videoId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reason': reason.name,
      'description': description,
      'createdAt': createdAt,
      'isResolved': isResolved,
      'resolvedBy': resolvedBy,
      'resolution': resolution,
    };
  }

  factory CommentReport.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentReport(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      replyId: data['replyId'],
      videoId: data['videoId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reason: ReportReason.values.firstWhere(
        (e) => e.name == (data['reason'] ?? 'other'),
        orElse: () => ReportReason.other,
      ),
      description: data['description'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isResolved: data['isResolved'] ?? false,
      resolvedBy: data['resolvedBy'],
      resolution: data['resolution'],
    );
  }

  CommentReport copyWith({
    String? id,
    String? commentId,
    String? replyId,
    String? videoId,
    String? reporterId,
    String? reporterName,
    ReportReason? reason,
    String? description,
    Timestamp? createdAt,
    bool? isResolved,
    String? resolvedBy,
    String? resolution,
  }) {
    return CommentReport(
      id: id ?? this.id,
      commentId: commentId ?? this.commentId,
      replyId: replyId ?? this.replyId,
      videoId: videoId ?? this.videoId,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolution: resolution ?? this.resolution,
    );
  }
}





