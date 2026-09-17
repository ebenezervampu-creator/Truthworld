import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class EditVideoScreen extends StatefulWidget {
  const EditVideoScreen({required this.video, super.key});
  final Video video;

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final RxString _selectedVisibility;
  late final RxBool _isKidFriendly;
  late final RxBool _showLikeCount;
  late final RxBool _showDislikeCount;

  final _formKey = GlobalKey<FormState>();
  final VideoManagementController _controller =
      Get.isRegistered<VideoManagementController>()
          ? Get.find<VideoManagementController>()
          : Get.put(VideoManagementController());

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.video.title);
    _descriptionController = TextEditingController(
      text: widget.video.description,
    );
    _tagsController = TextEditingController(text: widget.video.tags.join(', '));
    _selectedVisibility = widget.video.visibility.obs;
    _isKidFriendly = widget.video.isKidFriendly.obs;
    _showLikeCount = widget.video.showLikeCount.obs;
    _showDislikeCount = widget.video.showDislikeCount.obs;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      final titleResult = ContentValidator.validate(title, fieldName: 'Title');
      if (!titleResult.isValid) {
        AppSnackbar.warning(titleResult.message);
        return;
      }

      final description = _descriptionController.text.trim();
      if (description.isNotEmpty) {
        final descResult = ContentValidator.validate(
          description,
          fieldName: 'Description',
        );
        if (!descResult.isValid) {
          AppSnackbar.warning(descResult.message);
          return;
        }
      }

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(5)
          .toList();

      if (tags.isNotEmpty) {
        final tagsResult = ContentValidator.validateTags(tags);
        if (!tagsResult.isValid) {
          AppSnackbar.warning(tagsResult.message);
          return;
        }
      }

      final updatedData = {
        'title': title,
        'description': description,
        'tags': tags,
        'visibility': _selectedVisibility.value,
        'isKidFriendly': _isKidFriendly.value,
        'showLikeCount': _showLikeCount.value,
        'showDislikeCount': _showDislikeCount.value,
      };
      _controller.updateVideo(widget.video.id, updatedData);
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(
          'Edit Video',
          style: AppTextStyles.titleLarge,
        ),
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _onSave,
              icon: const Icon(Icons.save, size: 18, color: Colors.white),
              label: Text('Save', style: AppTextStyles.buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'Title',
                validator: ContentValidator.formValidator('Title'),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 5,
                validator: ContentValidator.formValidator('Description', required: false),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _tagsController,
                label: 'Tags (comma separated, max 5)',
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    final tagList = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    if (tagList.length > 5) {
                      return 'Maximum 5 tags allowed';
                    }
                    for (final tag in tagList) {
                      final res = ContentValidator.validate(tag, fieldName: 'Tag');
                      if (!res.isValid) return res.message;
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(),
              const SizedBox(height: 20),
              _buildSwitchField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: [...TruthworldTextInputFormatters.standard],
      validator: validator,
      style: AppTextStyles.inputText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.inputHint,
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    final options = [
      {'value': 'public', 'label': 'Public (Everyone can watch)'},
      {'value': 'private', 'label': 'Private (Only you can watch)'},
      {'value': 'members_only', 'label': 'Members Only (Channel members)'},
      {'value': 'subscribers_only', 'label': 'Subscribers Only (Subscribers)'},
      {'value': 'unlisted', 'label': 'Unlisted (Anyone with link)'},
    ];

    return Obx(
      () {
        var current = _selectedVisibility.value.toLowerCase().replaceAll(' ', '_');
        if (current == 'members') current = 'members_only';
        if (current == 'subscribers') current = 'subscribers_only';
        if (!options.any((o) => o['value'] == current)) {
          current = 'public';
        }

        return DropdownButtonFormField<String>(
          initialValue: current,
          onChanged: (value) {
            if (value != null) {
              _selectedVisibility.value = value;
            }
          },
          items: options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt['value'],
                  child: Text(opt['label']!, style: AppTextStyles.bodyMedium),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            labelText: 'Visibility & Access',
            labelStyle: AppTextStyles.inputHint,
            filled: true,
            fillColor: AppColors.bgInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 2),
            ),
          ),
          dropdownColor: AppColors.bgSurface,
          style: AppTextStyles.inputText,
        );
      },
    );
  }

  Widget _buildSwitchField() {
    return Column(
      children: [
        Obx(
          () => SwitchListTile(
            title: Text(
              'Is this video "Made for Kids"?',
              style: AppTextStyles.bodyMedium,
            ),
            value: _isKidFriendly.value,
            onChanged: (value) {
              _isKidFriendly.value = value;
            },
            activeThumbColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Show Like Count',
              style: AppTextStyles.bodyMedium,
            ),
            subtitle: Text(
              'Show how many viewers like this video',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            value: _showLikeCount.value,
            onChanged: (value) {
              _showLikeCount.value = value;
            },
            activeThumbColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            title: Text(
              'Show Dislike Count',
              style: AppTextStyles.bodyMedium,
            ),
            subtitle: Text(
              'Show how many viewers dislike this video',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            value: _showDislikeCount.value,
            onChanged: (value) {
              _showDislikeCount.value = value;
            },
            activeThumbColor: AppColors.brand,
            tileColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
