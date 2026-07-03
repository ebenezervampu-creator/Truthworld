import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

class RequestLanguageButton extends StatelessWidget {
  final String type;
  final VoidCallback onTap;
  const RequestLanguageButton({
    super.key,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PT.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PT.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: PT.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Request ${type.capitalizeFirst} Language',
                style: TS.bold.copyWith(color: PT.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageRequestsList extends StatelessWidget {
  final String type;
  final String? tag;
  const LanguageRequestsList({super.key, required this.type, this.tag});

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Requested Features',
            style: TS.bodySm.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (!Get.isRegistered<VideoController>(tag: tag)) {
              return const SizedBox.shrink();
            }
            final vc = Get.find<VideoController>(tag: tag);
            final reqs = vc.languageRequests
                .where((r) => r.type == type)
                .toList();
            if (vc.isLoadingLanguageRequests.value) {
              return Shimmer.fromColors(
                baseColor: Colors.white.withValues(alpha: 0.1),
                highlightColor: Colors.white.withValues(alpha: 0.2),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: 3,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Container(
                        width: 80,
                        height: 12,
                        color: Colors.white,
                      ),
                      subtitle: Container(
                        width: 120,
                        height: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }
            if (reqs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No requests yet',
                    style: TS.bodySm.copyWith(color: Colors.white24),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: reqs.length,
              itemBuilder: (_, i) {
                final r = reqs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.language_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                    title: Text(
                      r.language,
                      style: TS.body.copyWith(fontSize: 13),
                    ),
                    subtitle: Text(
                      'Requested on ${_fmtDate(r.createdAt.toDate())}',
                      style: TS.bodySm.copyWith(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SWIPE HUD
// ─────────────────────────────────────────────────────────────────────────────
