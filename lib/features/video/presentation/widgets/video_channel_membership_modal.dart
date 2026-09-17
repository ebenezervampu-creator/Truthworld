import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet and widgets for previewing channel membership tiers, perks,
/// and joining channel memberships.
class VideoChannelMembershipModal {
  static void show({
    required BuildContext context,
    required VideoController controller,
    required bool isUserSignedIn,
    required VoidCallback onSignInPrompt,
  }) {
    if (!isUserSignedIn) {
      onSignInPrompt();
      return;
    }

    final channelId = controller.video.channelId;
    final channelName = controller.video.channelName.isNotEmpty
        ? controller.video.channelName
        : 'Channel';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.bgDivider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join $channelName Membership',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unlock exclusive badges, perks & support the creator',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  const SizedBox(height: 16),

                  // Tiers Stream
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(FirestoreCollections.channels)
                          .doc(channelId)
                          .collection('membership_tiers')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
                          );
                        }

                        var tiers = <ChannelMembershipTier>[];
                        if (snapshot.hasData &&
                            snapshot.data!.docs.isNotEmpty) {
                          tiers = snapshot.data!.docs
                              .map(
                                (doc) => ChannelMembershipTier.fromMap(
                                  doc.data()! as Map<String, dynamic>,
                                  doc.id,
                                ),
                              )
                              .where((t) => t.isEnabled)
                              .toList();
                        }

                        // Default fallback tiers if creator hasn't set custom ones
                        if (tiers.isEmpty) {
                          tiers = [
                            ChannelMembershipTier(
                              id: 'default_bronze',
                              name: 'Bronze Supporter',
                              price: 2.0,
                              perks: [
                                'Exclusive channel loyalty badge next to your name',
                                'Custom channel emojis in live chat & comments',
                                'Early access to newly uploaded videos',
                              ],
                            ),
                            ChannelMembershipTier(
                              id: 'default_silver',
                              name: 'Silver Supporter',
                              price: 5.0,
                              perks: [
                                'All Bronze perks included',
                                'Priority reply to your comments from creator',
                                'Access to members-only community polls & posts',
                                'Downloadable exclusive wallpaper & assets',
                              ],
                            ),
                            ChannelMembershipTier(
                              id: 'default_gold',
                              name: 'Gold VIP',
                              price: 10.0,
                              perks: [
                                'All Silver & Bronze perks included',
                                'Exclusive behind-the-scenes video updates',
                                'Direct Q&A live chat with creator',
                                'Special credit shoutout in future video descriptions',
                              ],
                            ),
                          ];
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: tiers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final tier = tiers[index];
                            return _buildMembershipTierCard(
                              context,
                              tier,
                              channelId,
                              channelName,
                              onSignInPrompt,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildMembershipTierCard(
    BuildContext context,
    ChannelMembershipTier tier,
    String channelId,
    String channelName,
    VoidCallback onSignInPrompt,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tier.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${tier.formattedPrice} / mo',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 12),
          Text(
            'PERKS & BENEFITS:',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...tier.perks.map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () =>
                  _joinMembershipTier(context, tier, channelId, channelName, onSignInPrompt),
              child: Text(
                'Join ${tier.name}',
                style: AppTextStyles.buttonText.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _joinMembershipTier(
    BuildContext context,
    ChannelMembershipTier tier,
    String channelId,
    String channelName,
    VoidCallback onSignInPrompt,
  ) async {
    if (!AuthService.to.isAuthenticated.value) {
      onSignInPrompt();
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    Navigator.pop(context);
    try {
      final amountINR = tier.currency.toUpperCase() == 'INR'
          ? tier.price
          : (tier.price * 85.0).roundToDouble();
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: amountINR,
        purpose: 'channel_membership',
        orderNote: 'Membership: $channelName - ${tier.name}',
        metadata: {
          'channelId': channelId,
          'channelName': channelName,
          'tierId': tier.id,
          'tierName': tier.name,
          'currency': tier.currency,
          'userName': AuthService.to.currentUser.value?.displayName ?? 'Channel Supporter',
          'userAvatarUrl': AuthService.to.currentUser.value?.photoURL ?? '',
        },
      );

      if (!paymentResult.success) {
        if (paymentResult.errorMessage != null &&
            !paymentResult.errorMessage!.toLowerCase().contains('cancel')) {
          AppSnackbar.error(paymentResult.errorMessage!);
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      final memberRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('members')
          .doc(uid);

      batch.set(
        memberRef,
        {
          'userId': uid,
          'userName': AuthService.to.currentUser.value?.displayName ?? 'Channel Supporter',
          'userAvatarUrl': AuthService.to.currentUser.value?.photoURL ?? '',
          'tierId': tier.id,
          'tierName': tier.name,
          'price': tier.price,
          'currency': tier.currency,
          'orderId': paymentResult.orderId,
          'paymentGateway': 'cashfree',
          'joinedAt': FieldValue.serverTimestamp(),
          'status': 'active',
        },
        SetOptions(merge: true),
      );

      final userMembershipRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('channel_memberships')
          .doc(channelId);

      final membershipData = {
        'channelId': channelId,
        'channelName': channelName,
        'tierId': tier.id,
        'tierName': tier.name,
        'price': tier.price,
        'currency': tier.currency,
        'perks': tier.perks,
        'orderId': paymentResult.orderId,
        'paymentGateway': 'cashfree',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      batch.set(userMembershipRef, membershipData, SetOptions(merge: true));

      // Legacy fallback mirror for any components still reading camelCase
      final legacyUserMembershipRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('channelMemberships')
          .doc(channelId);
      batch.set(legacyUserMembershipRef, membershipData, SetOptions(merge: true));

      // Note: memberCount on the tier document and channel revenue are incremented authoritatively by backend fulfillOrder
      await batch.commit();

      AppSnackbar.success(
        'Welcome to ${tier.name}! You are now a member of $channelName. Enjoy your exclusive perks!',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to join membership. Please try again.',
      );
    }
  }


}
