import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

class LanguagePreferencesDialog extends StatelessWidget {
  const LanguagePreferencesDialog({super.key});

  Widget _buildSectionHeader(String title, VoidCallback onEdit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(
            Icons.edit_rounded,
            size: 14,
            color: AppColors.brand,
          ),
          label: const Text(
            'Edit',
            style: TextStyle(
              
              color: AppColors.brand,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    String label, {
    bool showLock = false,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
          if (showLock) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: AppColors.textTertiary,
            ),
          ] else if (onRemove != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = UserLanguagesService.to;
    final primary = service.primaryLanguage.value.obs;
    final secondaries = <String>[].obs;
    final known = <String>[].obs;

    secondaries.addAll(service.secondaryLanguages);
    known.addAll(service.knownLanguages);

    void syncKnownList() {
      if (!known.contains(primary.value)) {
        known.add(primary.value);
      }
      for (final sec in secondaries) {
        if (!known.contains(sec)) {
          known.add(sec);
        }
      }
    }

    // Ensure primary and secondaries are in known
    syncKnownList();

    Future<void> editPrimary() async {
      final result = await Get.dialog<String>(
        const LanguageSelectionDialog(
          title: 'Select Primary Language',
          multiple: false,
        ),
      );
      if (result != null) {
        primary.value = result;
        secondaries.remove(result);
        syncKnownList();
      }
    }

    Future<void> editSecondaries() async {
      final result = await Get.dialog<List<String>>(
        LanguageSelectionDialog(
          title: 'Select Secondary Languages',
          multiple: true,
          initialSelection: secondaries,
          exclude: [primary.value],
        ),
      );
      if (result != null) {
        secondaries.clear();
        secondaries.addAll(result);
        syncKnownList();
      }
    }

    Future<void> editKnown() async {
      final result = await Get.dialog<List<String>>(
        LanguageSelectionDialog(
          title: 'Select All Known Languages',
          multiple: true,
          initialSelection: known,
          locked: [primary.value, ...secondaries],
        ),
      );
      if (result != null) {
        known.clear();
        known.addAll(result);
        syncKnownList();
      }
    }

    Future<void> save() async {
      await UserLanguagesService.to.saveLanguages(
        primary: primary.value,
        secondaries: secondaries,
        known: known,
      );
      Get.back();
      AppSnackbar.success('Language preferences saved successfully');
    }

    return Dialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.settings_suggest_rounded,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Preferred Languages',
                    style: TextStyle(
                      
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Set your language profile to automatically enable matched subtitles and dubs.',
                style: TextStyle(
                  
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Primary Language
              _buildSectionHeader('Primary Language', editPrimary),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [_buildChip(primary.value, showLock: true)],
              ),
              const SizedBox(height: 20),

              // Secondary Languages
              _buildSectionHeader('Secondary Languages', editSecondaries),
              const SizedBox(height: 8),
              if (secondaries.isEmpty)
                const Text(
                  'None configured',
                  style: TextStyle(
                    
                    color: AppColors.textDisabled,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: secondaries.map((lang) {
                    return _buildChip(
                      lang,
                      onRemove: () {
                        secondaries.remove(lang);
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),

              // All Known Languages
              _buildSectionHeader('All Known Languages', editKnown),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: known.map((lang) {
                  final isLocked =
                      lang == primary.value || secondaries.contains(lang);
                  return _buildChip(
                    lang,
                    showLock: isLocked,
                    onRemove: isLocked
                        ? null
                        : () {
                            known.remove(lang);
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save Preferences',
                      style: TextStyle(
                        
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

class LanguageSelectionDialog extends StatelessWidget {

  const LanguageSelectionDialog({
    required this.title, required this.multiple, super.key,
    this.initialSelection = const [],
    this.exclude = const [],
    this.locked = const [],
  });
  final String title;
  final bool multiple;
  final List<String> initialSelection;
  final List<String> exclude;
  final List<String> locked;

  @override
  Widget build(BuildContext context) {
    final selected = <String>[].obs;
    final searchCtrl = TextEditingController();
    final filtered = <TranslationLanguage>[].obs;

    selected.addAll(initialSelection);
    filtered.addAll(supportedLanguages.where((l) => !exclude.contains(l.name)));

    void onSearch(String q) {
      filtered.clear();
      filtered.addAll(
        supportedLanguages
            .where((l) => !exclude.contains(l.name))
            .where(
              (l) =>
                  l.name.toLowerCase().contains(q.toLowerCase()) ||
                  l.nativeName.toLowerCase().contains(q.toLowerCase()),
            )
            .toList(),
      );
    }

    void toggle(String name) {
      if (locked.contains(name)) return;

      if (multiple) {
        if (selected.contains(name)) {
          selected.remove(name);
        } else {
          selected.add(name);
        }
      } else {
        selected.clear();
        selected.add(name);
      }
    }

    return Dialog(
      backgroundColor: const Color(0xFF1F1F1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    searchCtrl.dispose();
                    Get.back();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search language...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                filled: true,
                fillColor: AppColors.textPrimary.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Obx(() {
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final lang = filtered[index];
                    final isSelected =
                        selected.contains(lang.name) ||
                        locked.contains(lang.name);
                    final isLocked = locked.contains(lang.name);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        lang.name,
                        style: TextStyle(
                          
                          color: isSelected ? AppColors.brand : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        lang.nativeName,
                        style: const TextStyle(
                          
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: isLocked
                          ? const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textTertiary,
                              size: 16,
                            )
                          : isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.brand,
                              size: 18,
                            )
                          : null,
                      onTap: isLocked ? null : () => toggle(lang.name),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    searchCtrl.dispose();
                    Get.back();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final result = multiple
                        ? List<String>.from(selected)
                        : (selected.isNotEmpty ? selected.first : null);
                    searchCtrl.dispose();
                    Get.back(result: result);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
