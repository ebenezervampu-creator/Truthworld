import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Reusable accordion card widget for the Channel Creation Wizard mobile view.
class ChannelWizardAccordionCard extends StatelessWidget {
  const ChannelWizardAccordionCard({
    required this.title,
    required this.isExpanded,
    required this.isDarkMode,
    required this.child,
    super.key,
  });

  final String title;
  final RxBool isExpanded;
  final bool isDarkMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => isExpanded.value = !isExpanded.value,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Obx(
                    () => Icon(
                      isExpanded.value
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(
            () => isExpanded.value
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
