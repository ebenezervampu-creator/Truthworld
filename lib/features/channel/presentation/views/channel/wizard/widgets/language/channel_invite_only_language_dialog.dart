import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

void showInviteOnlyLanguageDialog(
  BuildContext context, {
  required String langName,
  required String nativeName,
  required String code,
  required String speakers,
  required int rank,
  required ChannelController controller,
}) {
  final isSubmitting = false.obs;
  final isSubmitted = false.obs;

  showDialog<void>(
    context: context,
    builder: (ctx) => Obx(
      () => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$langName is Invite-Only',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Truthworld currently accepts channel creation only in English.\n\n$langName ($nativeName) is ranked #$rank worldwide with $speakers. You can request language support below, and our admin team will review your request.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  Icon(
                    isSubmitted.value
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSubmitted.value
                          ? 'Request submitted to admin for $langName! Your channel remains set to English.'
                          : 'Your channel language will remain set to English.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isSubmitted.value) ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27272A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isSubmitting.value
                  ? null
                  : () async {
                      isSubmitting.value = true;
                      try {
                        final auth = Get.isRegistered<AuthService>()
                            ? AuthService.to
                            : null;
                        final currentUser = FirebaseAuth.instance.currentUser ??
                            auth?.currentUser.value;
                        final currentUid =
                            currentUser?.uid ?? auth?.uid ?? '';
                        final email = currentUser?.email ??
                            auth?.currentUser.value?.email ??
                            '';
                        final displayName = currentUser?.displayName ??
                            auth?.currentUser.value?.displayName ??
                            '';

                        if (currentUid.isEmpty) {
                          isSubmitting.value = false;
                          AppSnackbar.info(
                            'Please sign in to request language access.',
                            title: 'Sign In Required',
                          );
                          return;
                        }

                        // Check if a pending request already exists
                        final existing = await FirebaseFirestore.instance
                            .collection(
                              FirestoreCollections.channelLanguageRequests,
                            )
                            .where('userId', isEqualTo: currentUid)
                            .where('languageCode', isEqualTo: code)
                            .where('status', isEqualTo: 'pending')
                            .limit(1)
                            .get();

                        if (existing.docs.isNotEmpty) {
                          isSubmitting.value = false;
                          AppSnackbar.info(
                            'You already have a pending invite request for $langName.',
                            title: 'Request Already Pending',
                          );
                          return;
                        }

                        // Save request to Firestore
                        await FirebaseFirestore.instance
                            .collection(
                              FirestoreCollections.channelLanguageRequests,
                            )
                            .add({
                              'userId': currentUid,
                              'userEmail': email,
                              'userName': displayName,
                              'languageName': langName,
                              'languageNative': nativeName,
                              'languageCode': code,
                              'speakers': speakers,
                              'rank': rank,
                              'channelNameDraft': controller.channelName.text
                                  .trim(),
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                        isSubmitted.value = true;
                        isSubmitting.value = false;

                        AppSnackbar.success(
                          'Your request for $langName has been submitted for review.',
                        );
                      } catch (e) {
                        isSubmitting.value = false;
                        ErrorHandler.log(e);
                        AppSnackbar.error(
                          'Unable to submit request. Please try again.',
                        );
                      }
                    },
              child: isSubmitting.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Request Invite'),
            ),
          ] else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27272A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    ),
  );
}
