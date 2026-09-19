import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_invite_only_language_dialog.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_languages_data.dart';
import 'package:truthworld/theme/app_theme.dart';

void showLanguagePicker(BuildContext context, ChannelController controller) {
  final searchController = TextEditingController();
  final filteredLanguages = RxList<Map<String, dynamic>>(
    worldLanguagesDescending,
  );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Material(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.language,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Channel Language',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Notice banner
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF221A10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD97706).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Truthworld is accepting only English as of now. All other world languages are invite-only at this stage.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) {
                      final q = query.trim().toLowerCase();
                      if (q.isEmpty) {
                        filteredLanguages.assignAll(
                          worldLanguagesDescending,
                        );
                      } else {
                        filteredLanguages.assignAll(
                          worldLanguagesDescending.where((lang) {
                            final name = (lang['name']! as String)
                                .toLowerCase();
                            final native = (lang['native']! as String)
                                .toLowerCase();
                            final code = (lang['code']! as String)
                                .toLowerCase();
                            return name.contains(q) ||
                                native.contains(q) ||
                                code.contains(q);
                          }),
                        );
                      }
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search world languages...',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFF27272A), height: 1),
              Expanded(
                child: Obx(
                  () => filteredLanguages.isEmpty
                      ? const Center(
                          child: Text(
                            'No languages match your search.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          itemCount: filteredLanguages.length,
                          separatorBuilder: (_, _) => const Divider(
                            color: Color(0xFF27272A),
                            height: 1,
                          ),
                          itemBuilder: (itemCtx, index) {
                            final lang = filteredLanguages[index];
                            final name = lang['name'] as String? ?? '';
                            final native = lang['native'] as String? ?? '';
                            final code = lang['code'] as String? ?? '';
                            final speakers = lang['speakers'] as String? ?? '';
                            final rank = lang['rank'] as int? ?? (index + 1);

                            final isEnglish = code == 'en';

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              onTap: () {
                                if (isEnglish) {
                                  controller.language.value = 'en';
                                  Navigator.pop(ctx);
                                } else {
                                  showInviteOnlyLanguageDialog(
                                    context,
                                    langName: name,
                                    nativeName: native,
                                    code: code,
                                    speakers: speakers,
                                    rank: rank,
                                    controller: controller,
                                  );
                                }
                              },
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isEnglish
                                      ? const Color(0xFF15803D).withValues(
                                          alpha: 0.2,
                                        )
                                      : const Color(0xFF27272A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '#$rank',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isEnglish
                                        ? const Color(0xFF4ADE80)
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isEnglish
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isEnglish
                                            ? Colors.white
                                            : const Color(0xFFD4D4D8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '($native)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                speakers,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: isEnglish
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF15803D,
                                            ).withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: const Text(
                                            'Accepted',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF3F3F46,
                                            ).withValues(alpha: 0.4),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF52525B,
                                              ).withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.lock_outline,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Invite Only',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
