import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// GetX controller managing search bar focus and text reactivity without setState.
class SearchBarController extends GetxController {
  final FocusNode focusNode = FocusNode();
  final RxBool isFocused = false.obs;
  final RxBool hasText = false.obs;
  TextEditingController? _textController;

  /// Attaches the text editing controller listener.
  void attachTextController(TextEditingController controller) {
    if (_textController == controller) return;
    _textController?.removeListener(_handleTextChanged);
    _textController = controller;
    hasText.value = controller.text.isNotEmpty;
    _textController?.addListener(_handleTextChanged);
  }

  @override
  void onInit() {
    super.onInit();
    focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    isFocused.value = focusNode.hasFocus;
  }

  void _handleTextChanged() {
    hasText.value = _textController?.text.isNotEmpty ?? false;
  }

  @override
  void onClose() {
    _textController?.removeListener(_handleTextChanged);
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.onClose();
  }
}

/// Search bar widget with multi-language text formatter, voice search trigger, and GetX reactivity.
class SearchBar extends StatelessWidget {
  const SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSearchSubmitted,
    super.key,
    this.hintText = 'Search videos, channels, topics...',
    this.isLoading = false,
  });

  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final VoidCallback onSearchSubmitted;
  final String hintText;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barController = Get.isRegistered<SearchBarController>(
      tag: controller.hashCode.toString(),
    )
        ? Get.find<SearchBarController>(tag: controller.hashCode.toString())
        : Get.put(
            SearchBarController(),
            tag: controller.hashCode.toString(),
          );
    barController.attachTextController(controller);

    final textField = TextField(
      controller: controller,
      focusNode: barController.focusNode,
      maxLength: ContentValidator.defaultMaxSearchLength,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: TruthworldTextInputFormatters.withLimit(
        ContentValidator.defaultMaxSearchLength,
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onSearchSubmitted(),
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: AppColors.brand,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        prefixIcon: isLoading
            ? Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.all(12),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brand,
                ),
              )
            : IconButton(
                icon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onSearchSubmitted,
              ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              if (!barController.hasText.value) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  barController.hasText.value = false;
                  onClear();
                },
              );
            }),
            IconButton(
              icon: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                Get.dialog(
                  VoiceSearchDialog(
                    onSearch: (query) {
                      controller.text = query;
                      onChanged(query);
                      onSearchSubmitted();
                    },
                  ),
                  useSafeArea: false,
                );
              },
            ),
          ],
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );

    return Obx(
      () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: barController.isFocused.value
                ? AppColors.brand
                : AppColors.bgSurfaceContainerHighest,
          ),
        ),
        child: textField,
      ),
    );
  }
}
