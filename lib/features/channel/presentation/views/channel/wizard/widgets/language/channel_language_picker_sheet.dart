import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_languages_data.dart';
import 'package:truthworld/theme/tw_typography.dart';

void showLanguagePicker(BuildContext context, ChannelController controller) {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
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
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
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
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF52525B),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          maxLength: 100,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                          onChanged: (query) {
                            searchQuery.value = query;
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Search language...',
                            hintStyle: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      Obx(
                        () => searchQuery.value.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  searchController.clear();
                                  searchQuery.value = '';
                                  filteredLanguages.assignAll(
                                    worldLanguagesDescending,
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.cancel,
                                    color: Color(0xFFA1A1AA),
                                    size: 18,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(
                color: Color(0xFF27272A),
                height: 1,
              ),
              Expanded(
                child: Obx(
                  () => filteredLanguages.isEmpty
                      ? const Center(
                          child: Text(
                            'No languages match your search.',
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
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

                            return Obx(() {
                              final isSelected = controller.language.value.trim().toLowerCase() == code.toLowerCase();

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                onTap: () {
                                  controller.language.value = code;
                                  Navigator.pop(ctx);
                                },
                                leading: const Icon(
                                  Icons.language,
                                  color: Color(0xFFA1A1AA),
                                  size: 20,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (native.isNotEmpty && native != name) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '($native)',
                                        style: _getNativeLanguageStyle(code),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              );
                            });
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

TextStyle _getNativeLanguageStyle(String code) {
  const devanagariCodes = {
    'hi',
    'mr',
    'ne',
    'sa',
    'bho',
    'kok',
    'mai',
    'awa',
    'mag',
  };
  const bengaliCodes = {'bn', 'as'};

  if (devanagariCodes.contains(code)) {
    return const TextStyle(
      fontFamily: 'Noto Sans Devanagari',
      fontSize: 12,
      color: Color(0xFFA1A1AA),
      fontFamilyFallback: TWTypography.fallbackFamilies,
    );
  }
  if (bengaliCodes.contains(code)) {
    return const TextStyle(
      fontFamily: 'Noto Sans Bengali',
      fontSize: 12,
      color: Color(0xFFA1A1AA),
      fontFamilyFallback: TWTypography.fallbackFamilies,
    );
  }
  return const TextStyle(
    fontSize: 12,
    color: Color(0xFFA1A1AA),
    fontFamilyFallback: TWTypography.fallbackFamilies,
  );
}
