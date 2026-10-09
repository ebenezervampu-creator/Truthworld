import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';

void main() {
  group('Channel Model Social and Custom Links Tests', () {
    test('Channel.fromMap accurately parses socialLinks and customLinks', () {
      final data = <String, dynamic>{
        'name': 'Test Channel',
        'socialLinks': {
          'youtube': 'https://youtube.com/@truthworld',
          'twitter': 'https://x.com/truthworld',
          'instagram': 'https://instagram.com/truthworld',
          'facebook': 'https://facebook.com/truthworld',
          'linkedin': 'https://linkedin.com/in/truthworld',
          'tiktok': 'https://tiktok.com/@truthworld',
          'whatsapp': 'https://whatsapp.com/channel/truthworld',
          'telegram': 'https://t.me/truthworld',
          'discord': 'https://discord.gg/truthworld',
          'github': 'https://github.com/truthworld',
          'twitch': 'https://twitch.tv/truthworld',
          'reddit': 'https://reddit.com/r/truthworld',
          'patreon': 'https://patreon.com/truthworld',
          'threads': 'https://threads.net/@truthworld',
          'website': 'https://truthworld.com',
        },
        'customLinks': [
          {'title': 'Merch Store', 'url': 'https://shop.truthworld.com'},
          {'title': 'Portfolio', 'url': 'https://portfolio.example.com'},
        ],
      };

      final channel = Channel.fromMap(data, 'channel-123');

      expect(channel.socialLinks, isNotNull);
      expect(channel.socialLinks!['youtube'], 'https://youtube.com/@truthworld');
      expect(channel.socialLinks!['discord'], 'https://discord.gg/truthworld');
      expect(channel.socialLinks!['patreon'], 'https://patreon.com/truthworld');
      expect(channel.websiteUrl, 'https://truthworld.com');

      expect(channel.customLinks.length, 2);
      expect(channel.customLinks[0]['title'], 'Merch Store');
      expect(channel.customLinks[0]['url'], 'https://shop.truthworld.com');
      expect(channel.customLinks[1]['title'], 'Portfolio');
      expect(channel.customLinks[1]['url'], 'https://portfolio.example.com');
    });

    test('Channel.fromMap handles fallback of customLinks from socialLinks', () {
      final data = <String, dynamic>{
        'name': 'Test Channel',
        'socialLinks': {
          'twitter': 'https://x.com/truthworld',
          'customLinks': [
            {'title': 'Backup Link', 'url': 'https://backup.example.com'},
          ],
        },
      };

      final channel = Channel.fromMap(data, 'channel-456');
      expect(channel.customLinks.length, 1);
      expect(channel.customLinks[0]['title'], 'Backup Link');
      expect(channel.customLinks[0]['url'], 'https://backup.example.com');
    });

    test('Channel.toMap serializes customLinks correctly', () {
      final channel = Channel.fromMap({
        'name': 'Test Channel',
        'socialLinks': {'twitter': 'https://x.com/truthworld'},
        'customLinks': [
          {'title': 'My Store', 'url': 'https://store.truthworld.com'},
        ],
      }, 'channel-789');

      final map = channel.toMap();
      expect(map['customLinks'], isNotNull);
      expect(map['customLinks'], [
        {'title': 'My Store', 'url': 'https://store.truthworld.com'},
      ]);
    });
  });

  group('CustomLinkItem Unit Tests', () {
    test('CustomLinkItem initializes with default and given values', () {
      final emptyItem = CustomLinkItem();
      expect(emptyItem.titleController.text, '');
      expect(emptyItem.urlController.text, '');
      emptyItem.dispose();

      final filledItem = CustomLinkItem(
        title: 'Community Discord',
        url: 'https://discord.gg/truth',
      );
      expect(filledItem.titleController.text, 'Community Discord');
      expect(filledItem.urlController.text, 'https://discord.gg/truth');
      filledItem.dispose();
    });
  });
}
