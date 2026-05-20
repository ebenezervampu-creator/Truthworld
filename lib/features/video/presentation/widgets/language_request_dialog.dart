import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

class LanguageRequestDialog extends StatefulWidget {
  final String type; // 'subtitle' or 'audio'
  final Function(String language) onRequested;

  const LanguageRequestDialog({
    super.key,
    required this.type,
    required this.onRequested,
  });

  @override
  State<LanguageRequestDialog> createState() => _LanguageRequestDialogState();
}

class _LanguageRequestDialogState extends State<LanguageRequestDialog> {
  String? selectedLanguage;
  final TextEditingController _searchController = TextEditingController();
  List<TranslationLanguage> filteredLanguages = supportedLanguages;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.type == 'subtitle' 
                      ? Icons.subtitles_rounded 
                      : Icons.audiotrack_rounded,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 12),
                Text(
                  'Request ${widget.type.capitalizeFirst} Language',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a language you would like to see for this video.',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  filteredLanguages = supportedLanguages
                      .where((l) =>
                          l.name.toLowerCase().contains(val.toLowerCase()) ||
                          l.nativeName.toLowerCase().contains(val.toLowerCase()))
                      .toList();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search language...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: filteredLanguages.length,
                itemBuilder: (context, index) {
                  final lang = filteredLanguages[index];
                  final isSelected = selectedLanguage == lang.name;
                  return ListTile(
                    title: Text(
                      lang.name,
                      style: GoogleFonts.outfit(
                        color: isSelected ? AppColors.brand : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      lang.nativeName,
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: AppColors.brand)
                        : null,
                    onTap: () {
                      setState(() {
                        selectedLanguage = lang.name;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: selectedLanguage == null
                    ? null
                    : () {
                        widget.onRequested(selectedLanguage!);
                        Get.back();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Submit Request',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
