import 'package:flutter/material.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AppealsTab extends StatelessWidget {
  final AdminController controller;
  const AppealsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildAppealsList(),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _buildAppealDetail(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAppealsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: ListView.separated(
        itemCount: 5,
        separatorBuilder: (context, index) =>
            const Divider(color: AppColors.bgDivider, height: 1),
        itemBuilder: (context, index) {
          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                'Appeal #${1042 + index}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'User: user${index}@example.com',
                    style: const TextStyle(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${index + 1}h ago',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textPrimary,
              ),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppealDetail() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Text(
                  'Appeal Details',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text(
                    'SLA: 12h remaining',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildCard(
                              'Original Content & AI Analysis',
                              'Image containing inappropriate material.\n\nAI Confidence: 98%\nCategory: Nudity',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCard(
                              'Creator\'s Appeal Statement',
                              '"This is a classical painting from a museum, not explicit content. Please review." - User',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCard(
                            'Original Content & AI Analysis',
                            'Image containing inappropriate material.\n\nAI Confidence: 98%\nCategory: Nudity',
                          ),
                          const SizedBox(height: 16),
                          _buildCard(
                            'Creator\'s Appeal Statement',
                            '"This is a classical painting from a museum, not explicit content. Please review." - User',
                          ),
                        ],
                      );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Resolution Reason',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for decision...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Uphold Rejection',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Overturn (Restore)',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                  onPressed: () {},
                  child: const Text('Escalate to Senior'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
