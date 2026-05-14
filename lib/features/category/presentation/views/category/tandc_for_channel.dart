import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:truthworld/theme/app_colors.dart';

class TermsAndConditionsWidget extends StatefulWidget {
  final bool isDarkMode;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const TermsAndConditionsWidget({
    super.key,
    required this.isDarkMode,
    required this.value,
    this.onChanged,
  });

  @override
  State<TermsAndConditionsWidget> createState() =>
      _TermsAndConditionsWidgetState();
}

class _TermsAndConditionsWidgetState extends State<TermsAndConditionsWidget> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.brand;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.value
              ? accentColor.withValues(alpha: 0.5)
              : (widget.isDarkMode ? Colors.white10 : Colors.black12),
          width: 2,
        ),
        boxShadow: widget.value
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.blue, // Placeholder for confetti
                      Colors.purple,
                      Colors.white,
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      final newValue = !widget.value;
                      if (newValue) {
                        _confettiController.play();
                      }
                      widget.onChanged?.call(newValue);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: widget.value ? accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.value
                              ? accentColor
                              : (widget.isDarkMode
                                    ? Colors.white30
                                    : Colors.black26),
                          width: 2,
                        ),
                      ),
                      child: widget.value
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        final newValue = !widget.value;
                        if (newValue) {
                          _confettiController.play();
                        }
                        widget.onChanged?.call(newValue);
                      },
                      child: Text(
                        "I agree to the Terms and Conditions",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: widget.isDarkMode
                              ? Colors.white
                              : AppColors.bgSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showTermsModal(context),
                      child: Text(
                        "Read our policies & guidelines",
                        style: TextStyle(
                          fontSize: 13,
                          color: accentColor,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: widget.isDarkMode ? AppColors.bgInput : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Terms & Conditions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTermSection(
                      "Community Guidelines",
                      "By creating a channel, you agree to post content that is respectful and follows our community safety guidelines. Prohibited content include hate speech, violence, and illegal materials.",
                    ),
                    _buildTermSection(
                      "Content Ownership",
                      "You retain ownership of the content you upload, but grant Truthworld a non-exclusive license to host, display, and distribute your content across our platforms.",
                    ),
                    _buildTermSection(
                      "Channel Conduct",
                      "Impersonation, spamming, and harassment are strictly forbidden. Repeated violations may result in channel suspension or permanent account termination.",
                    ),
                    _buildTermSection(
                      "Monetization & Ads",
                      "Channel owners must comply with our monetization policies. We reserve the right to display advertisements next to your content unless otherwise specified.",
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}






