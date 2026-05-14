import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class EditVideoScreen extends StatefulWidget {
  final Video video;

  const EditVideoScreen({super.key, required this.video});

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
  final VideoManagementController _controller = Get.find();

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
      // The snackbar is already shown by the controller, so we can remove it from here.
    }
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.surface
          : AppTheme.colors.textPrimary,
      appBar: AppBar(
        title: Text(
          'Edit Video',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDarkMode
            ? AppTheme.colors.surface
            : AppTheme.colors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _onSave,
              icon: Icon(Icons.save, size: 18),
              label: Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colors.info,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
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
              SizedBox(height: 20),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 5,
              ),
              SizedBox(height: 20),
              _buildTextField(
                controller: _tagsController,
                label: 'Tags (comma separated)',
              ),
              SizedBox(height: 20),
              _buildDropdownField(),
              SizedBox(height: 20),
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
      style: TextStyle(
        color: isDarkMode
            ? AppTheme.colors.textPrimary
            : AppTheme.colors.background,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode
              ? AppTheme.colors.textPrimary70
              : AppTheme.colors.background54,
        ),
        filled: true,
        fillColor: isDarkMode
            ? AppTheme.colors.surface
            : AppTheme.colors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.colors.info, width: 2),
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
          .map((label) => DropdownMenuItem(value: label, child: Text(label)))
          .toList(),
      decoration: InputDecoration(
        labelText: 'Visibility',
        labelStyle: TextStyle(
          color: isDarkMode
              ? AppTheme.colors.textPrimary70
              : AppTheme.colors.background54,
        ),
        filled: true,
        fillColor: isDarkMode
            ? AppTheme.colors.surface
            : AppTheme.colors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: isDarkMode
          ? AppTheme.colors.surface
          : AppTheme.colors.textPrimary,
      style: TextStyle(
        color: isDarkMode
            ? AppTheme.colors.textPrimary
            : AppTheme.colors.background,
      ),
    ));
  }

  Widget _buildSwitchField() {
    return Obx(() => SwitchListTile(
      title: Text(
        'Is this video "Made for Kids"?',
        style: TextStyle(
          color: isDarkMode
              ? AppTheme.colors.textPrimary
              : AppTheme.colors.background,
        ),
      ),
      value: _isKidFriendly.value,
      onChanged: (value) {
        _isKidFriendly.value = value;
      },
      activeThumbColor: AppTheme.colors.primary,
      tileColor: isDarkMode
          ? AppTheme.colors.surface
          : AppTheme.colors.textSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}





