import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';


class UserClipsController extends GetxController {
  final clips = <VideoClip>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchClips();
  }

  Future<void> fetchClips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isLoading.value = false;
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('clips')
          .orderBy('createdAt', descending: true)
          .get();

      clips.assignAll(snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return VideoClip.fromMap(data);
      }).toList());
    } catch (e) {
      debugPrint('Error fetching clips: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void deleteClip(String clipId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('clips')
          .doc(clipId)
          .delete();
      clips.removeWhere((c) => c.id == clipId);
      Get.snackbar("Success", "Clip deleted");
    } catch (e) {
      Get.snackbar("Error", "Failed to delete clip");
    }
  }
}

ThemeData _getTheme(BuildContext context) {
  final parentTheme = Theme.of(context);
  final parentColors = parentTheme.extension<TWColors>()!;
  final parentTypography = parentTheme.extension<TWTypography>()!;

  final homeColors = TWColors(
    brand: const Color(0xFF1976D2), // Professional blue
    brandContainer: const Color(0xFF1976D2).withValues(alpha: 0.12),
    brandVariant: const Color(0xFF42A5F5), // Lighter blue
    textPrimary: const Color(0xFFE8E8E8),
    textSecondary: const Color(0xFFB8B8B8),
    textTertiary: const Color(0xFFB8B8B8).withValues(alpha: 0.7),
    textDisabled: const Color(0xFFB8B8B8).withValues(alpha: 0.38),
    background: const Color(0xFF0F0F0F),
    surface: const Color(0xFF121212),
    surfaceContainer: const Color(0xFF1E1E1E),
    surfaceContainerHigh: const Color(0xFF1E1E1E),
    surfaceContainerHighest: const Color(0xFF1E1E1E),
    surfaceInput: const Color(0xFF121212),
    appBarSurface: const Color(0xFF121212),
    divider: const Color(0xFF1E1E1E),
    success: parentColors.success,
    warning: parentColors.warning,
    error: const Color(0xFFFF6B6B),
    info: const Color(0xFF42A5F5),
    successContainer: parentColors.successContainer,
    warningContainer: parentColors.warningContainer,
    errorContainer: parentColors.errorContainer,
    infoContainer: parentColors.infoContainer,
    selectedOverlay: parentColors.selectedOverlay,
    hoverOverlay: parentColors.hoverOverlay,
    pressedOverlay: parentColors.pressedOverlay,
    focusRing: parentColors.focusRing,
  );

  final homeTypography = TWTypography(
    logo: GoogleFonts.roboto(textStyle: parentTypography.logo),
    hero: GoogleFonts.roboto(textStyle: parentTypography.hero),
    display: GoogleFonts.roboto(textStyle: parentTypography.display),
    headline: GoogleFonts.roboto(textStyle: parentTypography.headline),
    title: GoogleFonts.roboto(textStyle: parentTypography.title),
    body: GoogleFonts.roboto(textStyle: parentTypography.body),
    bodySmall: GoogleFonts.roboto(textStyle: parentTypography.bodySmall),
    label: GoogleFonts.roboto(textStyle: parentTypography.label),
    caption: GoogleFonts.roboto(textStyle: parentTypography.caption),
    button: GoogleFonts.roboto(textStyle: parentTypography.button),
    overline: GoogleFonts.roboto(textStyle: parentTypography.overline),
  );

  return modernDarkProfessionalTheme.copyWith(
    extensions: [
      homeColors,
      homeTypography,
      parentTheme.extension<TWSpacing>()!,
      parentTheme.extension<TWRadius>()!,
      parentTheme.extension<TWMotion>()!,
      parentTheme.extension<TWShadows>()!,
      parentTheme.extension<TWGradients>()!,
      parentTheme.extension<TWLayoutTokens>()!,
    ],
  );
}

class ClipsPage extends StatelessWidget {
  final bool isDashboard;
  const ClipsPage({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserClipsController());

    return Theme(
      data: _getTheme(context),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Your Clips',
                style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
                onPressed: () {
                  if (isDashboard) {
                    Get.find<HomeController>().sideNavSelectedIndex.value = HomeController.indexLibrary;
                  } else {
                    Get.back();
                  }
                },
              ),
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    context.colors.brand.withValues(alpha: 0.1),
                    context.colors.background,
                  ],
                ),
              ),
              child: Obx(() {
                if (controller.isLoading.value) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 350,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) => const ShimmerVideoGridCard(),
                  );
                }

                if (controller.clips.isEmpty) {
                  return _buildEmptyState(context);
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: controller.clips.length,
                  itemBuilder: (context, index) {
                    final clip = controller.clips[index];
                    return _buildClipCard(context, clip);
                  },
                );
              }),
            ),
          );
        }
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.divider.withValues(alpha: 0.1)),
            ),
            child: Icon(Icons.content_cut_rounded, size: 64, color: context.colors.textSecondary.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'No clips yet',
            style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Find your favorite moments and clip them!',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildClipCard(BuildContext context, VideoClip clip) {
    return InkWell(
      onTap: () {
        // Navigate to video loader which will fetch the video and pass the clip argument
        Get.toNamed('/watch/${clip.videoId}', arguments: {
          'clip': clip,
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.divider.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: clip.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(clip.endTime - clip.startTime).toInt()}s',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => Get.find<UserClipsController>().deleteClip(clip.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    clip.videoTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(fontSize: 12, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: context.colors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        FormatUtils.formatDate(clip.createdAt),
                        style: GoogleFonts.roboto(fontSize: 11, color: context.colors.textSecondary.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}





