import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      final updatedData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'tags': _tagsController.text.split(',').map((e) => e.trim()).toList(),
        'visibility': _selectedVisibility.value,
        'isKidFriendly': _isKidFriendly.value,
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
              icon: const Icon(Icons.save, size: 18),
              label: Text('Save', style: AppTextStyles.buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
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
                validator: (value) =>
                    value!.isEmpty ? 'Title cannot be empty' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _tagsController,
                label: 'Tags (comma separated)',
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
    return Obx(() => DropdownButtonFormField<String>(
      initialValue: _selectedVisibility.value,
      onChanged: (value) {
        if (value != null) {
          _selectedVisibility.value = value;
        }
      },
      items: ['Public', 'Private', 'Unlisted']
          .map((label) => DropdownMenuItem(
                value: label,
                child: Text(label, style: AppTextStyles.bodyMedium),
              ))
          .toList(),
      decoration: InputDecoration(
        labelText: 'Visibility',
        labelStyle: AppTextStyles.inputHint,
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: AppColors.bgSurface,
      style: AppTextStyles.inputText,
    ));
  }

  Widget _buildSwitchField() {
    return Obx(() => SwitchListTile(
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}





