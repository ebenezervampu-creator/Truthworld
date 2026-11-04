import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Repeat offenders panel displaying accounts with multiple strikes, bans, or policy rejections.
class AdminAnalyticsTopOffenders extends StatelessWidget {
  const AdminAnalyticsTopOffenders({
    required this.data,
    super.key,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final offendersRaw = data['topOffenders'];
    final offenders = offendersRaw is List ? offendersRaw : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Repeat Offenders',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (offenders.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${offenders.length} Accounts',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Accounts with multiple strikes, bans, or policy rejections',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          if (offenders.isEmpty)
            const AdminAnalyticsZeroOffendersState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offenders.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 12,
              ),
              itemBuilder: (context, index) {
                final item = offenders[index] as Map<String, dynamic>? ?? {};
                return AdminAnalyticsOffenderTile(item: item);
              },
            ),
        ],
      ),
    );
  }
}

/// Offender list tile displaying avatar, username, ban badge, email, and violation/strike counts.
class AdminAnalyticsOffenderTile extends StatelessWidget {
  const AdminAnalyticsOffenderTile({
    required this.item,
    super.key,
  });

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final username = (item['user'] ?? 'Unknown User').toString();
    final email = item['email']?.toString() ?? '';
    final count = item['violationsCount'] ?? 0;
    final strikes = item['strikes'] ?? 0;
    final isBanned = item['isBanned'] == true;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: isBanned
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.bgSurface,
          child: Icon(
            isBanned ? Icons.block_rounded : Icons.person_outline,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isBanned) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BANNED',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          email.isNotEmpty ? email : 'Strikes: $strikes',
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$count violation${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (strikes > 0)
              Text(
                '$strikes strike${strikes == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Zero offenders empty state widget.
class AdminAnalyticsZeroOffendersState extends StatelessWidget {
  const AdminAnalyticsZeroOffendersState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Repeat Offenders Recorded',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'All creators and users are currently within community guideline limits in this time period.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
