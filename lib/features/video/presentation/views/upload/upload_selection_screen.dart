import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Upload Selection Screen
///
/// A modern selection screen that allows users to choose between different
/// content upload types. Features include:
/// - Clean card-based layout
/// - Hover animations for desktop
/// - Keyboard shortcuts (web)
/// - Last used preference memory
/// - Theme compliance
class UploadSelectionScreen extends StatefulWidget {
  const UploadSelectionScreen({super.key});

  @override
  State<UploadSelectionScreen> createState() => _UploadSelectionScreenState();
}

class _UploadSelectionScreenState extends State<UploadSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _storage = GetStorage();
  UploadType? _lastUsedType;

  @override
  void initState() {
    super.initState();
    _loadLastUsedType();
  }

  void _loadLastUsedType() {
    final lastUsedString = _storage.read('last_upload_type') as String?;
    if (lastUsedString != null) {
      _lastUsedType = uploadTypeFromStorageString(lastUsedString);
    }
  }

  void _navigateToUpload(UploadType type) {
    // Save as last used
    _storage.write('last_upload_type', type.toStorageString());

    // Navigate to specific upload screen
    Get.toNamed(type.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(context),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (kIsWeb) {
            // Handle keyboard shortcuts
            if (event.logicalKey == LogicalKeyboardKey.keyV) {
              _navigateToUpload(UploadType.video);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyC) {
              _navigateToUpload(UploadType.communityPost);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.layoutTokens.contentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.layoutSpacing,
                  vertical: context.layoutSpacing * 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    if (_lastUsedType != null) ...[
                      _buildLastUsedSection(context),
                      const SizedBox(height: 24),
                    ],
                    _buildUploadOptions(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.colors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close, color: context.colors.textPrimary),
        onPressed: Get.back,
      ),
      title: Text(
        'Create',
        style: context.themeTypography.headline,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create',
          style: context.themeTypography.hero,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose what you want to create',
          style: context.themeTypography.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLastUsedSection(BuildContext context) {
    if (_lastUsedType == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last used',
          style: context.themeTypography.label.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        _buildUploadOptionCard(context, _lastUsedType!, isLastUsed: true),
      ],
    );
  }

  Widget _buildUploadOptions(BuildContext context) {
    final availableTypes = UploadType.values
        .where((type) => type.isAvailable)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All options',
          style: context.themeTypography.label.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        ...availableTypes.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildUploadOptionCard(context, type),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.toNamed('/create-playlist'),
              borderRadius: context.radius.md,
              splashColor: context.colors.brandContainer,
              hoverColor: context.colors.hoverOverlay,
              child: Container(
                padding: EdgeInsets.all(context.layoutSpacing),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: context.radius.md,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainer,
                        borderRadius: context.radius.sm,
                      ),
                      child: const Icon(
                        Icons.playlist_add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Playlist',
                            style: context.themeTypography.title,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Organize videos into shareable playlists',
                            style: context.themeTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadOptionCard(
    BuildContext context,
    UploadType type, {
    bool isLastUsed = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToUpload(type),
        borderRadius: context.radius.md,
        splashColor: context.colors.brandContainer,
        hoverColor: context.colors.hoverOverlay,
        child: Container(
          padding: EdgeInsets.all(context.layoutSpacing),
          decoration: BoxDecoration(
            color: isLastUsed
                ? context.colors.surfaceContainer
                : context.colors.surface,
            borderRadius: context.radius.md,
            border: isLastUsed
                ? Border.all(
                    color: context.colors.brand,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLastUsed
                      ? context.colors.brandContainer
                      : context.colors.surfaceContainer,
                  borderRadius: context.radius.sm,
                ),
                child: Icon(
                  type.icon,
                  color: isLastUsed
                      ? context.colors.brand
                      : context.colors.textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: context.themeTypography.title,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.subtitle,
                      style: context.themeTypography.bodySmall,
                    ),
                  ],
                ),
              ),

              // Keyboard shortcut (web only)
              if (kIsWeb && type.keyboardShortcut != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    borderRadius: context.radius.sm,
                  ),
                  child: Text(
                    type.keyboardShortcut!,
                    style: context.themeTypography.label.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Chevron
              Icon(
                Icons.chevron_right,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
