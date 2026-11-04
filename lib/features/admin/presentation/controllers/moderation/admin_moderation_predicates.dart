/// Utility class providing validation predicates for content moderation items
/// across videos, channels, topics, images/posts, and reports.
class AdminModerationPredicates {
  const AdminModerationPredicates._();

  /// Checks if a video is pending moderation review
  static bool isVideoPending(Map<String, dynamic> v) {
    if (isVideoRejected(v)) return false;
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    final status = modStatus ?? vStatus;

    if (mod?['violationCategories']?.contains('timeout_passthrough') == true) {
      return true;
    }
    if (status == null) {
      if (v['isApproved'] == false) return true;
      return false;
    }
    return status == 'pending' ||
        status == 'processing' ||
        status == 'error' ||
        status == 'under_review' ||
        status == 'underreview' ||
        status == 'in_review' ||
        status == 'pending_review' ||
        status == 'flagged' ||
        status == 'uploading' ||
        status == 'unverified' ||
        status == 'pending_approval';
  }

  /// Checks if a video is approved/published/active
  static bool isVideoApproved(Map<String, dynamic> v) {
    if (isVideoRejected(v)) return false;
    if (isVideoPending(v)) return false;
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    final status = modStatus ?? vStatus;

    if (status == 'approved' ||
        status == 'published' ||
        status == 'active' ||
        status == 'ready' ||
        status == 'passed') {
      return true;
    }
    if (v['isApproved'] == true || v['visibility'] == 'public') {
      return true;
    }
    return true; // Default fallback for existing videos without status
  }

  /// Checks if a video is rejected
  static bool isVideoRejected(Map<String, dynamic> v) {
    final mod = v['moderation'] as Map<String, dynamic>?;
    final modStatus = mod?['status']?.toString().toLowerCase();
    final vStatus = v['status']?.toString().toLowerCase();
    return modStatus == 'rejected' || vStatus == 'rejected';
  }

  /// Checks if a channel is on hold
  static bool isChannelOnHold(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    return status == 'onhold' ||
        status == 'hold' ||
        status == 'held';
  }

  /// Checks if a channel is pending verification/review
  static bool isChannelPending(Map<String, dynamic> c) {
    if (isChannelRejected(c) || isChannelOnHold(c)) return false;
    final status = (c['status'] ?? '').toString().toLowerCase();
    if (status == 'underreview' ||
        status == 'under_review' ||
        status == 'pending' ||
        status == 'pending_approval' ||
        status == 'unverified' ||
        status == 'verification_pending' ||
        status == 'in_review') {
      return true;
    }
    if (status.isEmpty &&
        (c['isVerified'] == false || c['geminiApproved'] == false)) {
      return true;
    }
    return false;
  }

  /// Checks if a channel is active/verified
  static bool isChannelActive(Map<String, dynamic> c) {
    if (isChannelRejected(c) || isChannelOnHold(c)) return false;
    if (isChannelPending(c)) return false;
    final status = (c['status'] ?? 'active').toString().toLowerCase();
    return status == 'active' ||
        status == 'verified' ||
        status == 'approved' ||
        status == 'published' ||
        status == 'ready' ||
        c['isApproved'] == true ||
        c['isVerified'] == true ||
        c['geminiApproved'] == true ||
        c['status'] == null;
  }

  /// Checks if a channel is approved (alias for isChannelActive)
  static bool isChannelApproved(Map<String, dynamic> c) => isChannelActive(c);

  /// Checks if a channel verification was rejected or banned
  static bool isChannelRejected(Map<String, dynamic> c) {
    if (isChannelOnHold(c)) return false;
    final status = (c['status'] ?? '').toString().toLowerCase();
    return status == 'verificationrejected' ||
        status == 'verification_rejected' ||
        status == 'rejected' ||
        status == 'banned' ||
        status == 'suspended';
  }

  /// Checks if a topic is pending review / verification
  static bool isTopicPending(Map<String, dynamic> t) {
    if (isTopicRejected(t)) return false;
    final status = (t['status'] ?? '').toString().toLowerCase();
    if (status == 'underreview' ||
        status == 'under_review' ||
        status == 'pending' ||
        status == 'pending_approval' ||
        status == 'unverified' ||
        status == 'in_review' ||
        status == 'flagged') {
      return true;
    }
    if (t['geminiApproved'] == false &&
        status != 'active' &&
        status != 'approved') {
      return true;
    }
    return false;
  }

  /// Checks if a topic is active / approved
  static bool isTopicApproved(Map<String, dynamic> t) {
    if (isTopicRejected(t)) return false;
    if (isTopicPending(t)) return false;
    final status = (t['status'] ?? '').toString().toLowerCase();
    return status == 'active' ||
        status == 'approved' ||
        status == 'published' ||
        status == 'verified' ||
        t['isApproved'] == true ||
        t['geminiApproved'] == true;
  }

  /// Checks if a topic was rejected
  static bool isTopicRejected(Map<String, dynamic> t) {
    final status = (t['status'] ?? '').toString().toLowerCase();
    return status == 'verificationrejected' ||
        status == 'verification_rejected' ||
        status == 'rejected' ||
        status == 'banned' ||
        status == 'suspended';
  }

  /// Checks if an image/post is confirmed rejected by admin
  static bool isImagePostRejected(Map<String, dynamic> img) {
    final status = (img['status'] ?? '').toString().toUpperCase();
    final modStatus =
        (img['moderation']?['status'] ?? '').toString().toUpperCase();
    return status == 'REJECTED' ||
        status == 'MANUALLY_REJECTED' ||
        status == 'ADMIN_REJECTED' ||
        status == 'DELETED' ||
        status == 'REMOVED' ||
        status == 'BANNED' ||
        modStatus == 'REJECTED' ||
        modStatus == 'MANUALLY_REJECTED';
  }

  /// Checks if an image/post is pending review (including items flagged by SafeSearch/Vision AI)
  static bool isImagePostPending(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    final status = (img['status'] ?? '')
        .toString()
        .toUpperCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    final modStatus = (img['moderation']?['status'] ?? '')
        .toString()
        .toUpperCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');

    if (status == 'PENDINGREVIEW' ||
        status == 'PENDING' ||
        status == 'PROCESSING' ||
        status == 'UNDERREVIEW' ||
        status == 'PENDINGAPPROVAL' ||
        status == 'UNVERIFIED' ||
        status == 'INREVIEW' ||
        status == 'FLAGGED' ||
        status == 'FLAGGEDFORREVIEW' ||
        status == 'FLAGGEDBYAI' ||
        status == 'VERIFICATIONREJECTED' ||
        status == 'QUARANTINED' ||
        status == 'NEEDSREVIEW' ||
        status == 'AWAITINGREVIEW' ||
        status == 'AWAITINGAPPROVAL' ||
        status == 'FAILED' ||
        modStatus == 'PENDING' ||
        modStatus == 'PENDINGREVIEW' ||
        modStatus == 'FLAGGED' ||
        modStatus == 'VERIFICATIONREJECTED') {
      return true;
    }

    if (img['isApproved'] == false &&
        status != 'APPROVED' &&
        status != 'ACTIVE' &&
        status != 'PUBLISHED' &&
        status != 'PASSED') {
      return true;
    }
    return false;
  }

  /// Checks if an image/post is approved/published
  static bool isImagePostApproved(Map<String, dynamic> img) {
    if (isImagePostRejected(img)) return false;
    if (isImagePostPending(img)) return false;
    final status = (img['status'] ?? '').toString().toUpperCase();
    final modStatus =
        (img['moderation']?['status'] ?? '').toString().toUpperCase();
    return status == 'APPROVED' ||
        status == 'ACTIVE' ||
        status == 'PUBLISHED' ||
        status == 'PASSED' ||
        status == 'SUCCESS' ||
        modStatus == 'APPROVED' ||
        img['isApproved'] == true;
  }

  /// Checks if a video/content report is pending
  static bool isReportPending(Map<String, dynamic> r) {
    if (isReportResolved(r)) return false;
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    return status == 'pending' ||
        status == 'under_review' ||
        status == 'underreview' ||
        status == 'in_review' ||
        status == 'unresolved' ||
        status == 'new';
  }

  /// Checks if a video/content report is resolved or dismissed
  static bool isReportResolved(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString().toLowerCase();
    return r['isResolved'] == true ||
        r['resolved'] == true ||
        status == 'resolved' ||
        status == 'dismissed' ||
        status == 'resolved_rejected' ||
        status == 'resolved_dismissed' ||
        status == 'closed';
  }
}
