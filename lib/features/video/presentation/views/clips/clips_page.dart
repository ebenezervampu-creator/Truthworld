import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/user_clips_controller.dart';
import 'package:truthworld/features/video/presentation/views/clips/components/clips_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/controllers/user_clips_controller.dart';
export 'package:truthworld/features/video/presentation/views/clips/components/clips_barrel.dart';

class ClipsPage extends GetView<UserClipsController> {
  const ClipsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  UserClipsController get controller =>
      Get.isRegistered<UserClipsController>()
          ? Get.find<UserClipsController>()
          : Get.put(UserClipsController());

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipsHeader(
              controller: controller,
              isDashboard: isDashboard,
            ),
          ),
          SliverToBoxAdapter(
            child: ClipsCategoryChips(controller: controller),
          ),
          Obx(() {
            if (controller.rxIsLoading.value) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brand,
                  ),
                ),
              );
            }

            if (controller.rxErrorMessage.isNotEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Error: ${controller.rxErrorMessage.value}',
                      style: const TextStyle(color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final clips = controller.filteredClips;
            if (clips.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: ClipsEmptyState(),
              );
            }

            if (!controller.isListView.value) {
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: clips.length,
                  itemBuilder: (context, index) {
                    final clip = clips[index];
                    return ClipVideoGridCard(
                      clip: clip,
                      controller: controller,
                    );
                  },
                ),
              );
            }

            final groupedClips = controller.groupClipsByDate(clips);

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final dateKey = groupedClips.keys.elementAt(index);
                final dateClips = groupedClips[dateKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Text(
                        dateKey,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...dateClips.map(
                      (clip) => ClipVideoListCard(
                        clip: clip,
                        controller: controller,
                      ),
                    ),
                  ],
                );
              }, childCount: groupedClips.length),
            );
          }),
        ],
      ),
    );
  }
}
