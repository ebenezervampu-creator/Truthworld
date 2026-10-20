import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardLinksCard extends StatelessWidget {
  final ChannelController controller;
  final bool isDarkMode;
  final bool contentOnly;
  final TextEditingController Function(String key) getSocialController;
  final RxBool showMoreLinks;

  ChannelWizardLinksCard({
    required this.controller,
    required this.isDarkMode,
    required this.getSocialController,
    this.contentOnly = false,
    RxBool? showMoreLinks,
    super.key,
  }) : showMoreLinks = showMoreLinks ?? false.obs;

  static const Map<String, List<String>> _bannedSocialPlatformsByCountry = {
    'India': ['tiktok'],
    'China': ['youtube', 'facebook', 'twitter', 'instagram', 'tiktok'],
    'Iran': ['facebook', 'twitter', 'youtube'],
    'North Korea': ['youtube', 'facebook', 'twitter', 'instagram', 'tiktok'],
  };

  static final Map<String, List<Map<String, dynamic>>>
  _countrySpecificSocialPlatforms = {
    'China': [
      {
        'key': 'weibo',
        'label': 'Weibo',
        'icon': Icons.public,
        'hint': 'https://weibo.com/u/...',
        'domain': 'weibo.com',
      },
      {
        'key': 'bilibili',
        'label': 'Bilibili',
        'icon': Icons.video_library,
        'hint': 'https://space.bilibili.com/...',
        'domain': 'bilibili.com',
      },
      {
        'key': 'douyin',
        'label': 'Douyin',
        'icon': Icons.music_video,
        'hint': 'https://v.douyin.com/...',
        'domain': 'douyin.com',
      },
    ],
    'Russia': [
      {
        'key': 'vk',
        'label': 'VKontakte (VK)',
        'icon': Icons.public,
        'hint': 'https://vk.com/...',
        'domain': 'vk.com',
      },
      {
        'key': 'rutube',
        'label': 'RuTube',
        'icon': Icons.video_library,
        'hint': 'https://rutube.ru/...',
        'domain': 'rutube.ru',
      },
      {
        'key': 'telegram',
        'label': 'Telegram Channel',
        'icon': Icons.send,
        'hint': 'https://t.me/...',
        'domain': 't.me',
      },
    ],
    'Japan': [
      {
        'key': 'line',
        'label': 'LINE Official',
        'icon': Icons.chat,
        'hint': 'https://line.me/...',
        'domain': 'line.me',
      },
      {
        'key': 'niconico',
        'label': 'Niconico',
        'icon': Icons.tv,
        'hint': 'https://nicovideo.jp/...',
        'domain': 'nicovideo.jp',
      },
    ],
    'South Korea': [
      {
        'key': 'kakaotalk',
        'label': 'KakaoTalk Channel',
        'icon': Icons.chat_bubble,
        'hint': 'https://pf.kakao.com/...',
        'domain': 'kakao.com',
      },
      {
        'key': 'naver',
        'label': 'Naver Blog/TV',
        'icon': Icons.article,
        'hint': 'https://blog.naver.com/...',
        'domain': 'naver.com',
      },
    ],
    'Brazil': [
      {
        'key': 'whatsapp',
        'label': 'WhatsApp Business',
        'icon': Icons.chat,
        'hint': 'https://wa.me/...',
        'domain': 'wa.me',
      },
      {
        'key': 'kwai',
        'label': 'Kwai',
        'icon': Icons.video_call,
        'hint': 'https://kwai.com/...',
        'domain': 'kwai.com',
      },
    ],
  };

  Widget _buildSocialBrandIcon(String key, IconData fallbackIcon) {
    final iconData = switch (key) {
      'twitter' => Icons.alternate_email,
      'instagram' => Icons.camera_alt_outlined,
      'youtube' => Icons.smart_display_outlined,
      'facebook' => Icons.facebook,
      'tiktok' => Icons.music_note_outlined,
      'linkedin' => Icons.work_outline,
      'github' => Icons.code,
      'discord' => Icons.forum_outlined,
      'telegram' => Icons.send_outlined,
      'twitch' => Icons.live_tv_outlined,
      'reddit' => Icons.chat_outlined,
      'patreon' => Icons.monetization_on_outlined,
      'threads' => Icons.alternate_email_outlined,
      _ => fallbackIcon,
    };
    return Icon(iconData, size: 18, color: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    if (contentOnly) {
      return buildContent(context);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => Text(
              controller.country.value.isNotEmpty
                  ? '5. Links for ${controller.country.value} (Optional)'
                  : '5. Links (Optional)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          buildContent(context),
        ],
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    return Obx(() {
      final isOrg =
          controller.channelTypeCategory.value == 'Organization / Company';
      final selectedCountry = controller.country.value;
      final bannedPlatforms =
          _bannedSocialPlatformsByCountry[selectedCountry] ?? const [];

      // Clean up any banned platform links from controller state if present
      for (final bannedKey in bannedPlatforms) {
        if (controller.socialLinks.containsKey(bannedKey)) {
          controller.socialLinks.remove(bannedKey);
        }
        getSocialController(bannedKey).clear();
      }

      final standardLinks = [
        {
          'key': 'website',
          'label': 'Website',
          'icon': Icons.language,
          'placeholder': 'https://yourwebsite.com',
        },
        {
          'key': 'email',
          'label': isOrg ? 'Email *' : 'Email',
          'icon': Icons.email_outlined,
          'placeholder': isOrg
              ? 'contact@yourcompany.com (Custom domain required)'
              : 'youremail@example.com',
        },
        {
          'key': 'youtube',
          'label': 'YouTube',
          'icon': Icons.play_circle_outline,
          'placeholder': 'https://youtube.com/yourchannel',
        },
        {
          'key': 'facebook',
          'label': 'Facebook',
          'icon': Icons.facebook,
          'placeholder': 'https://facebook.com/yourpage',
        },
        {
          'key': 'twitter',
          'label': 'X (Twitter)',
          'icon': Icons.alternate_email,
          'placeholder': 'https://x.com/yourhandle',
        },
        {
          'key': 'instagram',
          'label': 'Instagram',
          'icon': Icons.camera_alt_outlined,
          'placeholder': 'https://instagram.com/yourhandle',
        },
        {
          'key': 'linkedin',
          'label': 'LinkedIn',
          'icon': Icons.work_outline,
          'placeholder': 'https://linkedin.com/in/yourprofile',
        },
        {
          'key': 'tiktok',
          'label': 'TikTok',
          'icon': Icons.music_note_outlined,
          'placeholder': 'https://tiktok.com/@yourhandle',
        },
        {
          'key': 'whatsapp',
          'label': 'WhatsApp Channel',
          'icon': Icons.chat_outlined,
          'placeholder': 'https://whatsapp.com/channel/...',
        },
        {
          'key': 'telegram',
          'label': 'Telegram',
          'icon': Icons.send_outlined,
          'placeholder': 'https://t.me/yourchannel',
        },
        {
          'key': 'discord',
          'label': 'Discord',
          'icon': Icons.forum_outlined,
          'placeholder': 'https://discord.gg/yourserver',
        },
        {
          'key': 'github',
          'label': 'GitHub',
          'icon': Icons.code,
          'placeholder': 'https://github.com/yourprofile',
        },
        {
          'key': 'twitch',
          'label': 'Twitch',
          'icon': Icons.live_tv_outlined,
          'placeholder': 'https://twitch.tv/yourchannel',
        },
        {
          'key': 'reddit',
          'label': 'Reddit',
          'icon': Icons.chat_outlined,
          'placeholder': 'https://reddit.com/r/yourcommunity',
        },
        {
          'key': 'patreon',
          'label': 'Patreon',
          'icon': Icons.monetization_on_outlined,
          'placeholder': 'https://patreon.com/yourpage',
        },
        {
          'key': 'threads',
          'label': 'Threads',
          'icon': Icons.alternate_email_outlined,
          'placeholder': 'https://threads.net/@yourhandle',
        },
      ];

      final filteredStandard = standardLinks
          .where((item) => !bannedPlatforms.contains(item['key']))
          .toList();
      final countrySpecific =
          _countrySpecificSocialPlatforms[selectedCountry] ?? const [];

      final existingKeys = filteredStandard.map((e) => e['key']).toSet();
      final extraLinks = countrySpecific
          .where((e) => !existingKeys.contains(e['key']))
          .toList();

      final allLinksList = [...filteredStandard, ...extraLinks];

      // Show top 6 links by default (Website + Email + top 4 social links), or any filled link
      final visibleLinksList = showMoreLinks.value
          ? allLinksList
          : allLinksList.where((item) {
              final idx = allLinksList.indexOf(item);
              final key = item['key']! as String;
              final hasValue = getSocialController(key)
                  .text
                  .trim()
                  .isNotEmpty;
              return idx < 6 || hasValue;
            }).toList();

      final hasHiddenLinks =
          allLinksList.length > visibleLinksList.length || showMoreLinks.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOrg) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Custom Email Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Organization / Company channels require a custom business domain email (e.g. info@company.com). Free emails (@gmail.com, @yahoo.com) are not allowed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFBBF24),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
          ...visibleLinksList.map((item) {
            final itemKey = item['key']! as String;
            final ctrl = getSocialController(itemKey);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        _buildSocialBrandIcon(
                          itemKey,
                          item['icon']! as IconData,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['label']! as String,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF27272A)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: ctrl,
                        maxLength: 500,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(500),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: item['placeholder']! as String,
                          hintStyle: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (hasHiddenLinks) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => showMoreLinks.value = !showMoreLinks.value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showMoreLinks.value
                          ? Icons.keyboard_arrow_up
                          : Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      showMoreLinks.value
                          ? 'Show Less Links'
                          : 'Add More Links',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF27272A)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Custom Links',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (controller.customLinks.length >= 10) {
                    AppSnackbar.warning('You can add up to 10 custom links.');
                    return;
                  }
                  controller.customLinks.add({'title': '', 'url': ''});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Add Custom Link',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Add links to your merchandise, portfolio, or other external sites.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          if (controller.customLinks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Text(
                'No custom links added yet. Tap "Add Custom Link" above to add your own links.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            )
          else
            ...List.generate(controller.customLinks.length, (idx) {
              final linkMap = controller.customLinks[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          initialValue: linkMap['title'] ?? '',
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(50),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Link Title (e.g. Store)',
                            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) {
                            controller.customLinks[idx] = {
                              'title': val.trim(),
                              'url': controller.customLinks[idx]['url'] ?? '',
                            };
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          initialValue: linkMap['url'] ?? '',
                          maxLength: 500,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(500),
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'https://...',
                            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) {
                            controller.customLinks[idx] = {
                              'title': controller.customLinks[idx]['title'] ?? '',
                              'url': val.trim(),
                            };
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      onPressed: () {
                        controller.customLinks.removeAt(idx);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
        ],
      );
    });
  }

  // ========================================================================
  // CARD 5: CHANNEL VISIBILITY
  // ========================================================================
}

class ChannelWizardVisibilityCard extends StatelessWidget {
  final ChannelController controller;
  final bool isDarkMode;
  final bool contentOnly;

  const ChannelWizardVisibilityCard({
    required this.controller,
    required this.isDarkMode,
    this.contentOnly = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (contentOnly) {
      return buildContent(context);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '6. Channel Visibility',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          buildContent(context),
        ],
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose who can view your channel.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () {
            final vis = controller.visibility.value;
            IconData iconData;
            String title;
            String desc;

            if (vis == 'Members') {
              iconData = Icons.card_membership_rounded;
              title = 'Members';
              desc = 'Only channel members can view your channel';
            } else if (vis == 'Private') {
              iconData = Icons.lock_outline;
              title = 'Private';
              desc = 'Only approved users can view your channel';
            } else {
              iconData = Icons.public;
              title = 'Public';
              desc = 'Anyone can find and view your channel';
            }

            return GestureDetector(
              onTap: () => _showVisibilityPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    Icon(
                      iconData,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showVisibilityPicker(BuildContext context) {
    final options = [
      {
        'value': 'Public',
        'title': 'Public',
        'subtitle': 'Anyone can find and view your channel and videos.',
        'icon': Icons.public,
      },
      {
        'value': 'Members',
        'title': 'Members',
        'subtitle':
            'Only channel members can view your channel and exclusive content.',
        'icon': Icons.card_membership_rounded,
      },
      {
        'value': 'Private',
        'title': 'Private',
        'subtitle': 'Only you and approved users can view your channel.',
        'icon': Icons.lock_outline,
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF18181B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F3F46),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Channel Visibility',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose who can discover and view your channel.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  return Obx(() {
                    final isSelected =
                        controller.visibility.value == opt['value'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF27272A),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          controller.setVisibility(opt['value']! as String);
                          Navigator.pop(context);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F23),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            opt['icon']! as IconData,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          opt['title']! as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          opt['subtitle']! as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  });
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // CARD 6: COUNTRY
  // ========================================================================
  // ========================================================================
  // CARD 6: COUNTRY
  // ========================================================================
}
