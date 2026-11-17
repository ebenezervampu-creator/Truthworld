import 'package:truthworld/core/exceptions/app_exceptions.dart';

/// Centralized Industry-Standard User Feedback Sanitizer.
///
/// Ensures end users NEVER see raw developer errors, stack traces, technical error
/// codes, or jarring 'Error' titles anywhere in the application.
///
/// Any raw exception or developer string passed to user-facing UI is automatically
/// translated into clear, polite, solution-oriented standard English.
class UserFeedbackSanitizer {
  UserFeedbackSanitizer._();

  /// Known technical exception patterns that must never be shown to end users.
  static final List<Pattern> _technicalPatterns = [
    RegExp(r'\[[a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-]+\]'), // [cloud_firestore/permission-denied]
    RegExp('FirebaseException', caseSensitive: false),
    RegExp('FirebaseAuthException', caseSensitive: false),
    RegExp('PlatformException', caseSensitive: false),
    RegExp('SocketException', caseSensitive: false),
    RegExp('HttpException', caseSensitive: false),
    RegExp('HandshakeException', caseSensitive: false),
    RegExp('TimeoutException', caseSensitive: false),
    RegExp('FormatException', caseSensitive: false),
    RegExp('NoSuchMethodError', caseSensitive: false),
    RegExp('Null check operator', caseSensitive: false),
    RegExp('LateInitializationError', caseSensitive: false),
    RegExp('RangeError', caseSensitive: false),
    RegExp('TypeError', caseSensitive: false),
    RegExp('StateError', caseSensitive: false),
    RegExp('Exception:', caseSensitive: false),
    RegExp('OS Error:', caseSensitive: false),
    RegExp('Failed host lookup', caseSensitive: false),
    RegExp('connection refused', caseSensitive: false),
    RegExp('connection closed', caseSensitive: false),
    RegExp('connection abort', caseSensitive: false),
    RegExp('permission-denied', caseSensitive: false),
    RegExp('unauthenticated', caseSensitive: false),
    RegExp('authentication failed', caseSensitive: false),
    RegExp('authentication_error', caseSensitive: false),
    RegExp('request_failed', caseSensitive: false),
    RegExp('PaymentLink_', caseSensitive: false),
    RegExp('resource-exhausted', caseSensitive: false),
    RegExp('network-request-failed', caseSensitive: false),
    RegExp(r'status code:\s*\d{3}', caseSensitive: false),
    RegExp(r'\binternal\b', caseSensitive: false),
    RegExp(r'\bunavailable\b', caseSensitive: false),
    RegExp('FirebaseFunctionsException', caseSensitive: false),
    RegExp('FunctionsException', caseSensitive: false),
    RegExp(r'\[firebase_functions/[a-zA-Z0-9_\-]+\]', caseSensitive: false),
    RegExp('profile_inactive', caseSensitive: false),
    RegExp('server error', caseSensitive: false),
    RegExp(r'com\.truthworld', caseSensitive: false),
    RegExp('whitelist', caseSensitive: false),
    RegExp('whitelisting', caseSensitive: false),
    RegExp('not enabled or approved', caseSensitive: false),
    RegExp('package_not_approved', caseSensitive: false),
    RegExp('installer_package', caseSensitive: false),
  ];

  /// Known technical moderation, timeout, or developer status signatures that must NEVER leak as a video summary.
  static final List<Pattern> _invalidSummaryPatterns = [
    RegExp('moderation timed out', caseSensitive: false),
    RegExp('video apppro?ved pending', caseSensitive: false),
    RegExp('pending async review', caseSensitive: false),
    RegExp('moderation could not complete', caseSensitive: false),
    RegExp('video verification in progress', caseSensitive: false),
    RegExp('held safely in review queue', caseSensitive: false),
    RegExp('video held for admin', caseSensitive: false),
    RegExp('admin manual review', caseSensitive: false),
    RegExp('routed to admin', caseSensitive: false),
    RegExp('gemini ai bypassed', caseSensitive: false),
    RegExp('bypassed per system settings', caseSensitive: false),
    RegExp('quota saturated', caseSensitive: false),
    RegExp('quota_backpressure', caseSensitive: false),
    RegExp('timeout_passthrough', caseSensitive: false),
    RegExp('retry_exhausted_passthrough', caseSensitive: false),
    RegExp('summary unavailable', caseSensitive: false),
    RegExp('synthesis unavailable', caseSensitive: false),
    RegExp('synthesis was unavailable', caseSensitive: false),
    RegExp('analysis unavailable', caseSensitive: false),
    RegExp('peak load', caseSensitive: false),
    RegExp('scheduled for verification review', caseSensitive: false),
    RegExp('moderation system error', caseSensitive: false),
    RegExp('strategic analysis unavailable', caseSensitive: false),
    RegExp('infrastructure timeout', caseSensitive: false),
    RegExp('claim verdicts are still valid', caseSensitive: false),
    RegExp(r'\btimeout\b', caseSensitive: false),
    RegExp('timed out', caseSensitive: false),
    RegExp('capacity spikes', caseSensitive: false),
    RegExp('processing error due to', caseSensitive: false),
    RegExp('ai provider.*capacity', caseSensitive: false),
  ];

  /// Checks if a summary is in the wrong language compared to target language.
  /// E.g. an English summary for a Telugu or Hindi video returns true (mismatch).
  static bool isSummaryLanguageMismatch(String? summary, String? targetLanguage) {
    if (summary == null || targetLanguage == null) return false;
    final trimmed = summary.trim();
    if (trimmed.length < 10) return false;

    final lang = targetLanguage.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    if (lang.isEmpty || lang == 'en') {
      return false;
    }

    final scriptPatterns = <String, RegExp>{
      'te': RegExp(r'[\u0C00-\u0C7F]'), // Telugu
      'ta': RegExp(r'[\u0B80-\u0BFF]'), // Tamil
      'kn': RegExp(r'[\u0C80-\u0CFF]'), // Kannada
      'ml': RegExp(r'[\u0D00-\u0D7F]'), // Malayalam
      'hi': RegExp(r'[\u0900-\u097F]'), // Hindi / Devanagari
      'mr': RegExp(r'[\u0900-\u097F]'), // Marathi
      'bn': RegExp(r'[\u0980-\u09FF]'), // Bengali
      'gu': RegExp(r'[\u0A80-\u0AFF]'), // Gujarati
      'pa': RegExp(r'[\u0A00-\u0A7F]'), // Punjabi
      'or': RegExp(r'[\u0B00-\u0B7F]'), // Odia
      'ar': RegExp(r'[\u0600-\u06FF\u0750-\u077F]'), // Arabic
      'ja': RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]'), // Japanese
      'ko': RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]'), // Korean
      'zh': RegExp(r'[\u4E00-\u9FFF]'), // Chinese
      'ru': RegExp(r'[\u0400-\u04FF]'), // Russian
      'th': RegExp(r'[\u0E00-\u0E7F]'), // Thai
    };

    final pattern = scriptPatterns[lang];
    if (pattern != null) {
      final matches = pattern.allMatches(trimmed);
      final latinMatches = RegExp(r'[a-zA-Z]').allMatches(trimmed);
      if (matches.length < 3 && latinMatches.length > 15) {
        return true;
      }
    }

    // Common English opener pattern for non-English videos
    if (RegExp(r'^(This video|In this video|The video|The creator|This clip|Here is|Summary:|A comprehensive)\b', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Checks if a string is a genuine content summary and not a moderation/system message or verbatim transcript slice.
  static bool isValidVideoSummary(
    String? summary, {
    String? transcript,
    List<dynamic>? transcriptSegments,
    String? targetLanguage,
  }) {
    if (summary == null) return false;
    final trimmed = summary.trim();
    if (trimmed.isEmpty) return false;

    if (targetLanguage != null && isSummaryLanguageMismatch(trimmed, targetLanguage)) {
      return false;
    }

    for (final pattern in _invalidSummaryPatterns) {
      if (trimmed.contains(pattern)) {
        return false;
      }
    }

    // A genuine AI summary is a complete synthesis, not a truncated transcript cut off with '...'
    if (trimmed.endsWith('...') && trimmed.length >= 150) {
      if (trimmed.startsWith('Welcome to') ||
          trimmed.startsWith('Hey guys') ||
          trimmed.startsWith('Hey everyone') ||
          trimmed.startsWith('In this video') ||
          trimmed.startsWith('Today we') ||
          trimmed.startsWith('Today I')) {
        return false;
      }
    }

    final cleanSummary = trimmed.replaceAll(RegExp(r'\.{3}$'), '').trim();
    if (cleanSummary.length > 20) {
      if (transcript != null && transcript.trim().isNotEmpty) {
        if (transcript.trim().startsWith(cleanSummary)) {
          return false;
        }
      }
      if (transcriptSegments != null && transcriptSegments.isNotEmpty) {
        final segmentsText = transcriptSegments
            .take(6)
            .map((s) => s is String ? s : (s.text as String? ?? ''))
            .join(' ')
            .trim();
        if (segmentsText.isNotEmpty && segmentsText.startsWith(cleanSummary)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Returns a clean video summary if valid, or an empty string if invalid or a moderation message.
  static String sanitizeVideoSummary(
    String? summary, {
    String? transcript,
    List<dynamic>? transcriptSegments,
    String? targetLanguage,
  }) {
    if (!isValidVideoSummary(
      summary,
      transcript: transcript,
      transcriptSegments: transcriptSegments,
      targetLanguage: targetLanguage,
    )) {
      return '';
    }
    return summary!.trim();
  }

  /// Sanitizes viewer notes / advisories. If technical, timeout, or error messages are present, returns empty string.
  static String sanitizeViewerNote(String? note) {
    if (note == null) return '';
    final trimmed = note.trim();
    if (trimmed.isEmpty) return '';
    if (!isValidVideoSummary(trimmed)) return '';
    return trimmed;
  }

  /// Generic or harsh titles that must be sanitized or removed.
  static final Set<String> _forbiddenTitles = {
    'error',
    'errors',
    'developer error',
    'input error',
    'validation error',
    'submission error',
    'system error',
    'runtime error',
    'server error',
    'fatal error',
    'unknown error',
    'failure',
    'failed',
    'exception',
    'internal',
    'internal error',
    'unavailable',
    'service unavailable',
    'functions error',
  };

  /// Cleanses and standardizes any title for user display.
  /// Returns `null` if the title is generic, redundant, or harsh (e.g. "Error"),
  /// allowing the toast to display a clean, single-statement message.
  static String? sanitizeTitle(String? title) {
    if (title == null) return null;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (_forbiddenTitles.contains(lower)) {
      return null;
    }

    // Replace harsh titles like "Membership Error" -> "Membership"
    if (lower.endsWith(' error')) {
      final prefix = trimmed.substring(0, trimmed.length - 6).trim();
      return prefix.isNotEmpty ? prefix : null;
    }
    if (lower.startsWith('error:')) {
      final suffix = trimmed.substring(6).trim();
      return suffix.isNotEmpty ? suffix : null;
    }

    return trimmed;
  }

  /// Sanitizes any raw error, exception, or message into polite, standard English.
  static String sanitizeMessage(dynamic errorOrMessage, {String? defaultActionContext}) {
    if (errorOrMessage == null) {
      return 'An unexpected issue occurred. Please try again.';
    }

    // Extract message candidate from AppException, native Exception/Error, or raw object
    String msg;
    if (errorOrMessage is AppException) {
      msg = errorOrMessage.displayMessage.trim();
    } else if (errorOrMessage is Exception || errorOrMessage is Error) {
      msg = AppException.from(errorOrMessage).displayMessage.trim();
    } else {
      msg = errorOrMessage.toString().trim();
    }

    // Remove leading 'Exception: ' or 'Error: '
    if (msg.toLowerCase().startsWith('exception:')) {
      msg = msg.substring(10).trim();
    }
    if (msg.toLowerCase().startsWith('error:')) {
      msg = msg.substring(6).trim();
    }

    // Check if the string contains raw technical error signatures
    final hasTechnicalSignature = _technicalPatterns.any((pattern) => msg.contains(pattern));

    if (hasTechnicalSignature) {
      // If the string was formatted like "Failed to do X: <technical exception>",
      // extract the user action context and produce clean English.
      final colonIndex = msg.indexOf(':');
      if (colonIndex != -1) {
        final actionPart = msg.substring(0, colonIndex).trim();
        final technicalPart = msg.substring(colonIndex + 1).trim();

        // Check specific causes in the technical part
        final lowerTech = technicalPart.toLowerCase();
        if (lowerTech.contains('permission-denied') || lowerTech.contains('permission denied')) {
          return 'You do not have permission to complete this action.';
        }
        if (lowerTech.contains('socketexception') ||
            lowerTech.contains('failed host lookup') ||
            lowerTech.contains('network is unreachable') ||
            lowerTech.contains('connection refused') ||
            lowerTech.contains('connection closed') ||
            lowerTech.contains('connection abort') ||
            lowerTech.contains('network-request-failed')) {
          return 'You appear to be offline. Please check your internet connection and try again.';
        }
        if (lowerTech.contains('timeout') || lowerTech.contains('timed out')) {
          return 'The operation took too long. Please check your connection and try again.';
        }
        if (lowerTech.contains('not-found') || lowerTech.contains('not found')) {
          return 'The requested item could not be found.';
        }
        if (lowerTech.contains('already-exists')) {
          return 'This item already exists.';
        }
        if (lowerTech.contains('unauthenticated')) {
          return 'Please sign in to continue.';
        }
        if (lowerTech.contains('whitelist') ||
            lowerTech.contains('not enabled or approved') ||
            lowerTech.contains('package_not_approved') ||
            lowerTech.contains('installer_package') ||
            lowerTech.contains('com.truthworld')) {
          return 'Unable to process payment right now. Please try again shortly or contact support.';
        }
        if (lowerTech.contains('authentication failed') ||
            lowerTech.contains('authentication_error') ||
            lowerTech.contains('request_failed') ||
            lowerTech.contains('paymentlink_') ||
            lowerTech.contains('profile_inactive')) {
          return 'Payment service is temporarily unavailable. Please try again in a few moments or contact support.';
        }
        if (lowerTech.contains('internal') || lowerTech.contains('unavailable')) {
          if (defaultActionContext != null && defaultActionContext.isNotEmpty) {
            return 'Unable to $defaultActionContext right now. Please try again in a few moments.';
          }
          return 'The service is temporarily unavailable. Please try again shortly.';
        }

        // Otherwise transform "Failed to <action>" into "Unable to <action>. Please try again."
        if (actionPart.toLowerCase().startsWith('failed to ')) {
          final action = actionPart.substring(10).trim();
          return 'Unable to $action. Please try again.';
        }
        if (actionPart.toLowerCase().startsWith('could not ')) {
          final action = actionPart.substring(10).trim();
          return 'Unable to $action. Please try again.';
        }
        final isActionTechnical = _technicalPatterns.any(actionPart.contains);
        if (actionPart.isNotEmpty && !actionPart.contains('[') && !isActionTechnical) {
          return '$actionPart. Please try again.';
        }
      }

      // Check root technical cause if no prefix or if prefix was technical
      final lower = msg.toLowerCase();
      if (lower.contains('permission-denied') || lower.contains('permission denied')) {
        return 'You do not have permission to perform this action.';
      }
      if (lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('network is unreachable') ||
          lower.contains('connection refused') ||
          lower.contains('connection closed') ||
          lower.contains('connection abort') ||
          lower.contains('network-request-failed') ||
          lower.contains('network') ||
          lower.contains('connection')) {
        return 'You appear to be offline. Please check your internet connection and try again.';
      }
      if (lower.contains('timeout') || lower.contains('timed out')) {
        return 'The operation took too long. Please check your connection and try again.';
      }
      if (lower.contains('unauthenticated')) {
        return 'Please sign in to continue.';
      }
      if (lower.contains('whitelist') ||
          lower.contains('not enabled or approved') ||
          lower.contains('package_not_approved') ||
          lower.contains('installer_package') ||
          lower.contains('com.truthworld')) {
        return 'Unable to process payment right now. Please try again shortly or contact support.';
      }
      if (lower.contains('authentication failed') ||
          lower.contains('authentication_error') ||
          lower.contains('request_failed') ||
          lower.contains('paymentlink_') ||
          lower.contains('profile_inactive')) {
        return 'Payment service is temporarily unavailable. Please try again in a few moments or contact support.';
      }
      if (lower.contains('internal') || lower.contains('unavailable') || lower.contains('server error')) {
        if (defaultActionContext != null && defaultActionContext.isNotEmpty) {
          return 'Unable to $defaultActionContext right now. Please try again in a few moments.';
        }
        return 'The service is temporarily unavailable. Please try again shortly.';
      }

      // Fallback for technical errors
      if (defaultActionContext != null && defaultActionContext.isNotEmpty) {
        final lower = defaultActionContext.toLowerCase();
        if (lower.startsWith('unable to') ||
            lower.startsWith('could not') ||
            lower.startsWith('failed to') ||
            lower.contains('please')) {
          return defaultActionContext;
        }
        return 'Unable to $defaultActionContext. Please try again.';
      }
      return 'Something went wrong. Please try again in a moment.';
    }

    // Convert blunt developer phrasing like "Failed to X" or "Could not X" into polite standard English
    if (msg.toLowerCase().startsWith('failed to ')) {
      final action = msg.substring(10).trim();
      final cleanAction = action.endsWith('.') ? action.substring(0, action.length - 1) : action;
      return 'Unable to $cleanAction. Please try again.';
    }
    if (msg.toLowerCase().startsWith('could not ')) {
      final action = msg.substring(10).trim();
      final cleanAction = action.endsWith('.') ? action.substring(0, action.length - 1) : action;
      return 'Unable to $cleanAction. Please try again.';
    }

    final lowerMsg = msg.toLowerCase();
    if (lowerMsg.contains('whitelist') ||
        lowerMsg.contains('not enabled or approved') ||
        lowerMsg.contains('package_not_approved') ||
        lowerMsg.contains('installer_package') ||
        lowerMsg.contains('com.truthworld')) {
      return 'Unable to process payment right now. Please try again shortly or contact support.';
    }
    if (lowerMsg.contains('authentication failed') ||
        lowerMsg.contains('authentication_error') ||
        lowerMsg.contains('profile_inactive')) {
      return 'Payment service is temporarily unavailable. Please try again in a few moments or contact support.';
    }
    if (lowerMsg.contains('internal') || lowerMsg.contains('unavailable') || lowerMsg.contains('server error')) {
      if (defaultActionContext != null && defaultActionContext.isNotEmpty) {
        return 'Unable to $defaultActionContext right now. Please try again in a few moments.';
      }
      return 'The service is temporarily unavailable. Please try again shortly.';
    }

    // If message is too generic or blunt, polish it
    if (msg.isEmpty || lowerMsg == 'error' || lowerMsg == 'failed' || lowerMsg == 'unknown') {
      if (defaultActionContext != null && defaultActionContext.isNotEmpty) {
        return 'Unable to $defaultActionContext. Please try again.';
      }
      return 'An unexpected issue occurred. Please try again.';
    }

    return msg;
  }
}
