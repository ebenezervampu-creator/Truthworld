import 'package:flutter/material.dart';

/// Data model representing a parsed section within the Terms and Conditions policy.
class PolicySection {
  PolicySection({
    required this.title,
    required this.content,
    required this.key,
  });

  final String title;
  final String content;
  final GlobalKey key;
}
