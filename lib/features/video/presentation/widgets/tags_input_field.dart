import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TagInputField extends StatelessWidget {
  final Function(List<String>) onTagsChanged;
  final RxList<String> tags = <String>[].obs;
  final TextEditingController _tagController = TextEditingController();

  TagInputField({super.key, required this.onTagsChanged});

  void _addTag(String tag) {
    tag = tag.trim().toLowerCase(); // Normalize tag input
    if (tag.isNotEmpty && !tags.contains(tag) && tags.length < 10) {
      tags.add(tag);
      onTagsChanged(tags.toList());
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    tags.remove(tag);
    onTagsChanged(tags.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            labelText: "Enter tags",
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addTag(_tagController.text),
            ),
          ),
          onSubmitted: _addTag,
        ),
        const SizedBox(height: 10),
        Obx(() => Wrap(
          spacing: 8.0,
          children: tags.map((tag) {
            return Chip(
              label: Text(tag),
              onDeleted: () => _removeTag(tag),
            );
          }).toList(),
        )),
      ],
    );
  }
}





