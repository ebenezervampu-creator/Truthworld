/// Industry-standard input validation utilities
/// Prevents injection attacks, validates formats, and ensures data integrity
library;

import 'package:truthworld/core/utils/exception_handler.dart';

class InputValidator {
  // Regex patterns for common validations
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/' // http:// or https://
    r'(?:(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?|' // domain
    r'(?:\d{1,3}\.){3}\d{1,3})' // or IP
    r'(?::\d+)?' // optional port
    r'(?:\/[^\s]*)?$',
  );

  static final RegExp _alphanumeric = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Validate email format
  static bool isValidEmail(String email) {
    return _emailRegex.hasMatch(email.toLowerCase());
  }

  /// Validate URL format and protocol
  static bool isValidUrl(
    String url, {
    List<String> allowedProtocols = const ['https'],
  }) {
    if (!_urlRegex.hasMatch(url)) return false;

    for (final protocol in allowedProtocols) {
      if (url.startsWith('$protocol://')) return true;
    }
    return false;
  }

  /// Validate text length with error message
  static String validateTextLength(
    String text, {
    required int minLength,
    required int maxLength,
    required String fieldName,
  }) {
    text = text.trim();
    if (text.isEmpty) {
      throw ValidationException(
        fieldName: fieldName,
        message: '$fieldName cannot be empty',
      );
    }
    if (text.length < minLength) {
      throw ValidationException(
        fieldName: fieldName,
        message: '$fieldName must be at least $minLength characters',
      );
    }
    if (text.length > maxLength) {
      throw ValidationException(
        fieldName: fieldName,
        message: '$fieldName cannot exceed $maxLength characters',
      );
    }
    return text;
  }

  /// Validate and sanitize username
  static String validateUsername(String username) {
    username = username.trim();
    if (username.isEmpty) {
      throw const ValidationException(
        fieldName: 'username',
        message: 'Username cannot be empty',
      );
    }
    if (username.length < 3) {
      throw const ValidationException(
        fieldName: 'username',
        message: 'Username must be at least 3 characters',
      );
    }
    if (username.length > 30) {
      throw const ValidationException(
        fieldName: 'username',
        message: 'Username cannot exceed 30 characters',
      );
    }
    if (!_alphanumeric.hasMatch(username)) {
      throw const ValidationException(
        fieldName: 'username',
        message:
            'Username can only contain letters, numbers, hyphens, and underscores',
      );
    }
    return username;
  }

  /// Validate and sanitize comment text
  static String validateComment(String text, {int maxLength = 5000}) {
    text = text.trim();
    if (text.isEmpty) {
      throw const ValidationException(
        fieldName: 'comment',
        message: 'Comment cannot be empty',
      );
    }
    if (text.length > maxLength) {
      throw ValidationException(
        fieldName: 'comment',
        message: 'Comment cannot exceed $maxLength characters',
      );
    }
    // Remove potential XSS vectors (basic sanitization)
    text = _sanitizeXSS(text);
    return text;
  }

  /// Validate channel name
  static String validateChannelName(String name) {
    return validateTextLength(
      name,
      minLength: 3,
      maxLength: 100,
      fieldName: 'Channel name',
    );
  }

  /// Validate video title
  static String validateVideoTitle(String title) {
    return validateTextLength(
      title,
      minLength: 5,
      maxLength: 100,
      fieldName: 'Video title',
    );
  }

  /// Validate video description
  static String validateVideoDescription(String description) {
    return validateTextLength(
      description,
      minLength: 10,
      maxLength: 5000,
      fieldName: 'Video description',
    );
  }

  /// Validate tag format
  static String validateTag(String tag) {
    tag = tag.trim().toLowerCase();
    if (tag.isEmpty) {
      throw const ValidationException(
        fieldName: 'tag',
        message: 'Tag cannot be empty',
      );
    }
    if (tag.length < 2) {
      throw const ValidationException(
        fieldName: 'tag',
        message: 'Tag must be at least 2 characters',
      );
    }
    if (tag.length > 50) {
      throw const ValidationException(
        fieldName: 'tag',
        message: 'Tag cannot exceed 50 characters',
      );
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(tag)) {
      throw const ValidationException(
        fieldName: 'tag',
        message:
            'Tag can only contain lowercase letters, numbers, hyphens, and underscores',
      );
    }
    return tag;
  }

  /// Sanitize text to remove XSS vectors
  static String _sanitizeXSS(String text) {
    return text
        .replaceAll('<script>', '&lt;script&gt;')
        .replaceAll('</script>', '&lt;/script&gt;')
        .replaceAll('<iframe>', '&lt;iframe&gt;')
        .replaceAll('</iframe>', '&lt;/iframe&gt;')
        .replaceAll('onclick=', 'onclick_blocked=')
        .replaceAll('onerror=', 'onerror_blocked=')
        .replaceAll('onload=', 'onload_blocked=')
        .replaceAll('javascript:', 'javascript_blocked:');
  }

  /// Sanitize HTML entities
  static String sanitizeHtml(String html) {
    return html
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Validate non-empty string
  static String requireNonEmpty(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ValidationException(
        fieldName: fieldName,
        message: '$fieldName is required',
      );
    }
    return value.trim();
  }

  /// Validate integer range
  static int validateIntRange(
    int value, {
    required int min,
    required int max,
    required String fieldName,
  }) {
    if (value < min || value > max) {
      throw ValidationException(
        fieldName: fieldName,
        message: '$fieldName must be between $min and $max',
      );
    }
    return value;
  }
}
