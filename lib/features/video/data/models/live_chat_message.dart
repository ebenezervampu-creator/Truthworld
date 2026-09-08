import 'package:flutter/material.dart';

/// Real-time Live Chat message model stored in Firebase RTDB `/liveChat/{videoId}/messages`.
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.text,
    required this.timestamp,
    this.channelId,
    this.channelName,
    this.isModerator = false,
    this.isCreator = false,
    this.isSuperchat = false,
    this.superchatAmount = 0.0,
    this.superchatCurrency = 'USD',
    this.superchatTierColor = '#1E88E5',
    this.expiresAt,
  });

  factory LiveChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawAmount = map['superchatAmount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;

    return LiveChatMessage(
      id: id,
      videoId: (map['videoId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? 'Viewer').toString(),
      userProfilePicUrl: (map['userProfilePicUrl'] ?? '').toString(),
      channelId: map['channelId']?.toString(),
      channelName: map['channelName']?.toString(),
      text: (map['text'] ?? '').toString(),
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isModerator: map['isModerator'] == true,
      isCreator: map['isCreator'] == true,
      isSuperchat: map['isSuperchat'] == true || amount > 0,
      superchatAmount: amount,
      superchatCurrency: (map['superchatCurrency'] ?? 'USD').toString(),
      superchatTierColor: (map['superchatTierColor'] ?? '#1E88E5').toString(),
      expiresAt: (map['expiresAt'] as num?)?.toInt(),
    );
  }

  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String? channelId;
  final String? channelName;
  final String text;
  final int timestamp;
  final bool isModerator;
  final bool isCreator;
  final bool isSuperchat;
  final double superchatAmount;
  final String superchatCurrency;
  final String superchatTierColor;
  final int? expiresAt;

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'userId': userId,
    'userName': userName,
    'userProfilePicUrl': userProfilePicUrl,
    if (channelId != null) 'channelId': channelId,
    if (channelName != null) 'channelName': channelName,
    'text': text,
    'timestamp': timestamp,
    if (isModerator) 'isModerator': true,
    if (isCreator) 'isCreator': true,
    if (isSuperchat) 'isSuperchat': true,
    if (superchatAmount > 0) 'superchatAmount': superchatAmount,
    if (isSuperchat) 'superchatCurrency': superchatCurrency,
    if (isSuperchat) 'superchatTierColor': superchatTierColor,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };

  Color get tierColor {
    try {
      final hex = superchatTierColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }
}
