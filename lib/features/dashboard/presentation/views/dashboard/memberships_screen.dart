import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelMembershipTier {
  ChannelMembershipTier({
    required this.id,
    required this.name,
    required this.price,
    required this.perks,
    this.badgeColorHex = '0xFFF59E0B',
    this.isEnabled = true,
  });

  factory ChannelMembershipTier.fromMap(Map<String, dynamic> map, String id) {
    return ChannelMembershipTier(
      id: id,
      name: map['name'] ?? 'Tier Name',
      price: (map['price'] as num?)?.toDouble() ?? 4.99,
      perks: List<String>.from(map['perks'] ?? []),
      badgeColorHex: map['badgeColorHex'] ?? '0xFFF59E0B',
      isEnabled: map['isEnabled'] ?? true,
    );
  }
  final String id;
  final String name;
  final double price;
  final List<String> perks;
  final String badgeColorHex;
  final bool isEnabled;

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'perks': perks,
    'badgeColorHex': badgeColorHex,
    'isEnabled': isEnabled,
    'updatedAt': Timestamp.now(),
  };
}

class MembershipsScreen extends StatefulWidget {
  const MembershipsScreen({
    super.key,
    this.channelId,
    this.isDarkMode = true,
  });

  final String? channelId;
  final bool isDarkMode;

  @override
  State<MembershipsScreen> createState() => _MembershipsScreenState();
}

class _MembershipsScreenState extends State<MembershipsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get activeChannelId {
    if (widget.channelId != null && widget.channelId!.isNotEmpty) {
      return widget.channelId!;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Stream<List<ChannelMembershipTier>> _tiersStream() {
    if (activeChannelId.isEmpty) return const Stream.empty();
    return _firestore
        .collection(FirestoreCollections.channels)
        .doc(activeChannelId)
        .collection('membership_tiers')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChannelMembershipTier.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.textSecondary,
      appBar: AppBar(
        title: Text(
          'Channel Memberships & Fan Funding',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 20,
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddTierDialog(context, isDarkMode),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text('Add Tier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0% Commission Banner
            _buildCommissionNoticeBanner(isDarkMode),
            const SizedBox(height: 24),

            // Metrics Row
            _buildMetricsSummary(isDarkMode),
            const SizedBox(height: 28),

            // Tiers List Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Membership Tiers & Perks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddTierDialog(context, isDarkMode),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  label: const Text(
                    'Create Custom Tier',
                    style: TextStyle(color: AppColors.brand),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stream of Tiers
            StreamBuilder<List<ChannelMembershipTier>>(
              stream: _tiersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  );
                }

                final tiers = snapshot.data ?? [];

                if (tiers.isEmpty) {
                  return _buildDefaultOrEmptyTiers(isDarkMode);
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tiers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final tier = tiers[index];
                    return _buildTierCard(tier, isDarkMode);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionNoticeBanner(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '0% Platform Commission Guarantee',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '100% of your channel membership & fan support revenues go directly to your channel account without any platform cuts or commission fees.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummary(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Active Members',
            value: '0',
            subtitle: 'Direct Subscribers',
            icon: Icons.people_alt_rounded,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: 'Monthly Fan Income',
            value: r'$0.00',
            subtitle: '100% Direct Payout',
            icon: Icons.account_balance_wallet_rounded,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: 'Platform Fee Rate',
            value: '0.0%',
            subtitle: 'Zero Commission',
            icon: Icons.verified_rounded,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultOrEmptyTiers(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 48,
            color: AppColors.textPrimary,
          ),
          const SizedBox(height: 12),
          Text(
            'No Membership Tiers Created Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            r'Set up membership levels (e.g. Bronze $1.99/mo, Silver VIP $4.99/mo) so fans can support your channel directly with 0% platform commission.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode
                  ? AppColors.textSecondary
                  : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _setupDefaultTiers,
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text('Setup Default Starter Tiers'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(ChannelMembershipTier tier, bool isDarkMode) {
    return Card(
      elevation: 0,
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tier.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black,
                    ),
                  ),
                ),
                Text(
                  '\$${tier.price.toStringAsFixed(2)} / month',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () =>
                      _showEditTierDialog(context, tier, isDarkMode),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: () => _deleteTier(tier.id),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            Text(
              'MEMBERSHIP PERKS:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            if (tier.perks.isEmpty)
              const Text(
                '• Loyalty badge beside name in comments',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tier.perks.map((perk) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          perk,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setupDefaultTiers() async {
    final defaultTiers = [
      ChannelMembershipTier(
        id: 'tier_fan',
        name: 'Channel Fan',
        price: 1.99,
        perks: [
          'Loyalty badge beside channel comments',
          'Exclusive member-only community posts',
        ],
      ),
      ChannelMembershipTier(
        id: 'tier_vip',
        name: 'VIP Supporter',
        price: 4.99,
        perks: [
          'All previous perks',
          'Early access to new videos',
          'Custom channel badges & priority replies',
        ],
      ),
      ChannelMembershipTier(
        id: 'tier_patron',
        name: 'Gold Patron',
        price: 9.99,
        perks: [
          'All previous perks',
          'Monthly Live Stream Q&A Access',
          'Special shoutouts in video credits',
        ],
      ),
    ];

    for (final tier in defaultTiers) {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(activeChannelId)
          .collection('membership_tiers')
          .doc(tier.id)
          .set(tier.toMap());
    }

    Get.snackbar(
      'Success',
      'Default membership tiers created!',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  void _showAddTierDialog(BuildContext context, bool isDarkMode) {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '4.99');
    final perksController = TextEditingController(
      text: 'Loyalty badge, Early access to videos',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        title: Text(
          'Create Membership Tier',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Tier Name (e.g. Silver VIP)',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.bgInput
                    : const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: r'Monthly Price ($)',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.bgInput
                    : const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: perksController,
              maxLines: 2,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Perks (comma-separated)',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.bgInput
                    : const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final nameVal = ContentValidator.validate(name, fieldName: 'Tier Name');
              if (!nameVal.isValid) {
                Get.snackbar(
                  'Inappropriate Content',
                  nameVal.message,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.textPrimary,
                );
                return;
              }

              final price =
                  double.tryParse(priceController.text.trim()) ?? 4.99;
              final perks = perksController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              for (final p in perks) {
                final perkVal = ContentValidator.validate(p, fieldName: 'Perk');
                if (!perkVal.isValid) {
                  Get.snackbar(
                    'Inappropriate Content',
                    perkVal.message,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.textPrimary,
                  );
                  return;
                }
              }

              final docRef = _firestore
                  .collection(FirestoreCollections.channels)
                  .doc(activeChannelId)
                  .collection('membership_tiers')
                  .doc();
              final newTier = ChannelMembershipTier(
                id: docRef.id,
                name: name,
                price: price,
                perks: perks,
              );

              await docRef.set(newTier.toMap());
              if (context.mounted) Navigator.pop(ctx);
              Get.snackbar(
                'Created',
                'Tier "$name" added.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Add Tier'),
          ),
        ],
      ),
    );
  }

  void _showEditTierDialog(
    BuildContext context,
    ChannelMembershipTier tier,
    bool isDarkMode,
  ) {
    final nameController = TextEditingController(text: tier.name);
    final priceController = TextEditingController(
      text: tier.price.toStringAsFixed(2),
    );
    final perksController = TextEditingController(text: tier.perks.join(', '));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        title: Text(
          'Edit Membership Tier',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: const InputDecoration(labelText: 'Tier Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: const InputDecoration(
                labelText: r'Monthly Price ($)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: perksController,
              maxLines: 2,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: const InputDecoration(
                labelText: 'Perks (comma-separated)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final nameVal = ContentValidator.validate(name, fieldName: 'Tier Name');
              if (!nameVal.isValid) {
                Get.snackbar(
                  'Inappropriate Content',
                  nameVal.message,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.textPrimary,
                );
                return;
              }

              final price =
                  double.tryParse(priceController.text.trim()) ?? tier.price;
              final perks = perksController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              for (final p in perks) {
                final perkVal = ContentValidator.validate(p, fieldName: 'Perk');
                if (!perkVal.isValid) {
                  Get.snackbar(
                    'Inappropriate Content',
                    perkVal.message,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.textPrimary,
                  );
                  return;
                }
              }

              await _firestore
                  .collection(FirestoreCollections.channels)
                  .doc(activeChannelId)
                  .collection('membership_tiers')
                  .doc(tier.id)
                  .update({
                    'name': name,
                    'price': price,
                    'perks': perks,
                    'updatedAt': Timestamp.now(),
                  });

              if (context.mounted) Navigator.pop(ctx);
              Get.snackbar(
                'Updated',
                'Tier updated successfully.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTier(String tierId) async {
    await _firestore
        .collection(FirestoreCollections.channels)
        .doc(activeChannelId)
        .collection('membership_tiers')
        .doc(tierId)
        .delete();
    Get.snackbar(
      'Deleted',
      'Membership tier removed.',
      backgroundColor: AppColors.error,
      colorText: AppColors.textPrimary,
    );
  }
}
