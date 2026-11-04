import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ShiftTimingsDialog {
  static void show(BuildContext context, SubtitlesController controller) {
    final offsetController = TextEditingController(text: '1000');
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Row(
          children: [
            Icon(Icons.timelapse_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Shift Subtitle Timings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shift all cues forward (+) or backward (-) in time across the active language track.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('-1000ms (-1s)'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(-1000);
                  },
                ),
                ActionChip(
                  label: const Text('-500ms'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(-500);
                  },
                ),
                ActionChip(
                  label: const Text('+500ms'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(500);
                  },
                ),
                ActionChip(
                  label: const Text('+1000ms (+1s)'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(1000);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: offsetController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              maxLength: 8,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(8),
                FilteringTextInputFormatter.allow(RegExp('^-?[0-9]*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Custom Offset (Milliseconds)',
                hintText: 'e.g. -250 or 750',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ms = int.tryParse(offsetController.text.trim()) ?? 0;
              Get.back<void>();
              controller.shiftAllCues(ms);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Apply Shift'),
          ),
        ],
      ),
    );
  }
}
