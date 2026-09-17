import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/channel.dart';

void main() {
  group('Channel Model Deserialization Tests', () {
    test('Channel.fromMap deserializes exact Firestore document without type errors', () {
      final docData = <String, dynamic>{
        'id': 'rjhYjftjEMy1MtpISPNU',
        'allowComments': true,
        'allowSubscriptions': true,
        'avatarFileId': '6b764617-46c3-48c0-9b3b-ef4cdb0f6f42.png',
        'avatarStatus': 'APPROVED',
        'avatarStatusReason': 'Passed all safety checks',
        'avatarUrl':
            'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/channels%2Favatars%2FBA9Qphy87aOOwtlhOUq8tmpYfRa2%2F6b764617-46c3-48c0-9b3b-ef4cdb0f6f42.png?alt=media&token=fb25e148-10d7-4348-a604-e2120ab686af',
        'bannerStatus': 'APPROVED',
        'bannerStatusReason': 'Pre-filter approved',
        'bannerUrl':
            'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/channels%2Fbanners%2FBA9Qphy87aOOwtlhOUq8tmpYfRa2%2F20925cd2-dbfa-4c02-a8f2-d0425a06ba72.png?alt=media&token=38ca7613-2a80-4b1c-9ec6-b6c78b78ffc4',
        'blockedUserIds': <dynamic>[],
        // Simulating nested map coming from Firestore SDK as Map<dynamic, dynamic>
        'brandingSettings': <dynamic, dynamic>{
          'bannerStyle': 'gradient',
          'primaryColor': '#6B46C1',
          'secondaryColor': '#9333EA',
        },
        'categories': <dynamic>[
          'Business',
          'News',
          'Education',
          'Finance',
        ],
        'category': 'Business, News, Education, Finance',
        'channelName': 'Ebenezer Vampu',
        'channelNameLowercase': 'ebenezer vampu',
        'channelPlan': 'standard',
        'channelType': 'standard',
        'channelTypeCategory': 'Creator',
        'contactEmail': '',
        'country': 'US',
        'createdAt': Timestamp.now(),
        'customPricingTier': 'basic',
        'customUrl': 'ebenezer-vampu',
        'customUrlLowercase': 'ebenezer-vampu',
        'description': 'Exploring business in india',
        'entityType': 'Creator',
        'geminiApproved': true,
        'handle': 'ebenezer-vampu',
        'handleLowercase': 'ebenezer-vampu',
        'isArchived': false,
        'isLive': false,
        'isPublic': true,
        'isVerified': false,
        'language': 'en',
        // Simulating nested map coming from Firestore SDK as Map<dynamic, dynamic>
        'metrics': <dynamic, dynamic>{
          'averageRetention': 0,
          'totalViews': 0,
          'totalWatchTimeMinutes': 0,
        },
        'moderationReason': '',
        'moderatorIds': <dynamic>[],
        'monetizationTier': 'free',
        'name': 'Ebenezer Vampu',
        'nameLowercase': 'ebenezer vampu',
        'ownerId': 'BA9Qphy87aOOwtlhOUq8tmpYfRa2',
        'showSubscriberCount': true,
        // Simulating nested map coming from Firestore SDK as Map<dynamic, dynamic>
        'socialLinks': <dynamic, dynamic>{
          'instagram': '',
          'twitter': '',
          'website': '',
          'youtube': '',
        },
        'status': 'active',
        'subscriberCount': 0,
        'superchatRevenueTotal': 0,
        'tags': <dynamic>['india'],
        'updatedAt': 1789496983924,
        'userId': 'BA9Qphy87aOOwtlhOUq8tmpYfRa2',
        'videoCount': 0,
        'websiteUrl': '',
      };

      final channel = Channel.fromMap(docData, 'rjhYjftjEMy1MtpISPNU');

      expect(channel.id, 'rjhYjftjEMy1MtpISPNU');
      expect(channel.name, 'Ebenezer Vampu');
      expect(channel.handle, 'ebenezer-vampu');
      expect(channel.ownerId, 'BA9Qphy87aOOwtlhOUq8tmpYfRa2');
      expect(channel.status, ChannelStatus.active);
      expect(channel.geminiApproved, isTrue);
      expect(channel.brandingSettings, isNotNull);
      expect(channel.brandingSettings?['primaryColor'], '#6B46C1');
      expect(channel.socialLinks, isNotNull);
      expect(channel.metrics.totalViews, 0);
      expect(channel.categories, contains('Business'));
    });
  });
}
