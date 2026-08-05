import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Widget that displays availability status with animated indicators
class AvailabilityIndicatorWidget extends StatelessWidget {
  const AvailabilityIndicatorWidget({
    required this.status,
    required this.isDarkMode,
    super.key,
    this.size = 20.0,
    this.showMessage = true,
  });
  final AvailabilityStatus status;
  final bool isDarkMode;
  final double size;
  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          if (showMessage && status.message.isNotEmpty) ...[
            const SizedBox(width: 8),
            _buildMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: SizedBox(
        key: ValueKey(status),
        width: size,
        height: size,
        child: status == AvailabilityStatus.checking
            ? SizedBox(
                width: size * 0.8,
                height: size * 0.8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                ),
              )
            : Icon(status.icon, size: size, color: status.color),
      ),
    );
  }

  Widget _buildMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Text(
        status.message,
        key: ValueKey(status.message),
        style: TextStyle(
          fontSize: 12,
          color: status.color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Enhanced text field with real-time availability checking
class AvailabilityTextField extends StatefulWidget {
  const AvailabilityTextField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.icon,
    required this.isDarkMode,
    required this.onChanged,
    required this.availabilityStatus,
    super.key,
    this.validator,
    this.maxLength,
    this.isRequired = false,
    this.prefixText,
    this.inputFormatters,
  });
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData icon;
  final bool isDarkMode;
  final Function(String) onChanged;
  final AvailabilityStatus availabilityStatus;
  final String? Function(String?)? validator;
  final int? maxLength;
  final bool isRequired;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AvailabilityTextField> createState() => _AvailabilityTextFieldState();
}

class _AvailabilityTextFieldState extends State<AvailabilityTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final RxBool _isFocused = false.obs;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Obx(
        () => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.isDarkMode
                    ? Colors.black26
                    : AppColors.bgPage.withValues(alpha: 0.08),
                blurRadius: _isFocused.value ? 15 : 10,
                spreadRadius: _isFocused.value ? 2 : 1,
                offset: Offset(0, _isFocused.value ? 6 : 4),
              ),
            ],
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              _isFocused.value = hasFocus;
              if (hasFocus) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            },
            child: TextFormField(
              controller: widget.controller,
              maxLength: widget.maxLength,
              inputFormatters: widget.inputFormatters,
              style: TextStyle(
                fontSize: 16,
                color: widget.isDarkMode
                    ? AppColors.textPrimary
                    : AppTheme.colors.surface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: widget.isRequired
                    ? '${widget.labelText} *'
                    : widget.labelText,
                hintText: widget.hintText,
                prefixText: widget.prefixText,
                prefixStyle: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : AppTheme.colors.surface,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.icon,
                    color: AppTheme.colors.primary,
                    size: 20,
                  ),
                ),
                suffixIcon:
                    widget.availabilityStatus != AvailabilityStatus.unknown
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: AvailabilityIndicatorWidget(
                          status: widget.availabilityStatus,
                          isDarkMode: widget.isDarkMode,
                          showMessage: false,
                        ),
                      )
                    : null,
                labelStyle: TextStyle(
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : AppTheme.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                hintStyle: TextStyle(
                  color: widget.isDarkMode
                      ? AppColors.textTertiary
                      : const Color(0xFFA0AEC0),
                ),
                filled: true,
                fillColor: widget.isDarkMode
                    ? AppTheme.colors.surface
                    : AppColors.textPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _getFocusedBorderColor(),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.colors.error,
                    width: 2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.colors.error,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                counterStyle: TextStyle(
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : AppTheme.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              onChanged: widget.onChanged,
              validator: widget.validator,
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
      ),
    );
  }

  Color _getFocusedBorderColor() {
    switch (widget.availabilityStatus) {
      case AvailabilityStatus.available:
        return AppTheme.colors.hoverAccent;
      case AvailabilityStatus.taken:
      case AvailabilityStatus.invalid:
      case AvailabilityStatus.error:
        return AppTheme.colors.error;
      case AvailabilityStatus.checking:
        return AppTheme.colors.primary;
      default:
        return AppTheme.colors.primary;
    }
  }
}

/// Widget to display availability message below text field
class AvailabilityMessageWidget extends StatelessWidget {
  const AvailabilityMessageWidget({
    required this.status,
    required this.isDarkMode,
    super.key,
    this.customMessage,
  });
  final AvailabilityStatus status;
  final bool isDarkMode;
  final String? customMessage;

  @override
  Widget build(BuildContext context) {
    if (status == AvailabilityStatus.available) {
      return const SizedBox.shrink();
    }

    final message = customMessage ?? status.message;

    if (message.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8, left: 16),
      child: Row(
        children: [
          AvailabilityIndicatorWidget(
            status: status,
            isDarkMode: isDarkMode,
            size: 16,
            showMessage: false,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                message,
                key: ValueKey(message),
                style: TextStyle(
                  fontSize: 13,
                  color: status.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper widget for channel creation limits display
class ChannelLimitIndicatorWidget extends StatelessWidget {
  const ChannelLimitIndicatorWidget({
    required this.currentCount,
    required this.maxCount,
    required this.isDarkMode,
    super.key,
  });
  final int currentCount;
  final int maxCount;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final isAtLimit = currentCount >= maxCount;
    final color = isAtLimit ? AppTheme.colors.error : AppTheme.colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAtLimit ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Channels: $currentCount / $maxCount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          if (isAtLimit) ...[
            const SizedBox(width: 8),
            Text(
              '(Limit reached)',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Advanced settings section widget
class AdvancedSettingsSection extends StatefulWidget {
  const AdvancedSettingsSection({
    required this.isDarkMode,
    required this.settings,
    required this.onSettingsChanged,
    super.key,
  });
  final bool isDarkMode;
  final Map<String, dynamic> settings;
  final Function(Map<String, dynamic>) onSettingsChanged;

  @override
  State<AdvancedSettingsSection> createState() =>
      _AdvancedSettingsSectionState();
}

class _AdvancedSettingsSectionState extends State<AdvancedSettingsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  final RxBool _isExpanded = false.obs;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    _isExpanded.value = !_isExpanded.value;
    if (_isExpanded.value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? AppTheme.colors.surface
                  : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.isDarkMode
                      ? Colors.black26
                      : AppColors.bgPage.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: AppTheme.colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advanced Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: widget.isDarkMode
                              ? AppColors.textPrimary
                              : AppTheme.colors.surface,
                        ),
                      ),
                      Text(
                        'Configure additional channel options',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDarkMode
                              ? AppColors.textSecondary
                              : AppTheme.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => AnimatedRotation(
                    turns: _isExpanded.value ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: widget.isDarkMode
                          ? AppColors.textSecondary
                          : AppTheme.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? AppTheme.colors.surface
                  : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.isDarkMode
                      ? Colors.black26
                      : AppColors.bgPage.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingSwitch(
                  'Allow Comments',
                  'Let viewers comment on your videos',
                  Icons.comment_rounded,
                  widget.settings['allowComments'] ?? true,
                  (value) => _updateSetting('allowComments', value),
                ),
                const SizedBox(height: 16),
                _buildSettingSwitch(
                  'Allow Subscriptions',
                  'Let users subscribe to your channel',
                  Icons.notifications_rounded,
                  widget.settings['allowSubscriptions'] ?? true,
                  (value) => _updateSetting('allowSubscriptions', value),
                ),
                const SizedBox(height: 16),
                _buildSettingSwitch(
                  'Show Subscriber Count',
                  'Display subscriber count publicly',
                  Icons.visibility_rounded,
                  widget.settings['showSubscriberCount'] ?? true,
                  (value) => _updateSetting('showSubscriberCount', value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.colors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.isDarkMode
                      ? AppColors.textPrimary
                      : AppTheme.colors.surface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : AppTheme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.colors.primary,
          activeTrackColor: AppTheme.colors.primary.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  void _updateSetting(String key, dynamic value) {
    final updatedSettings = Map<String, dynamic>.from(widget.settings);
    updatedSettings[key] = value;
    widget.onSettingsChanged(updatedSettings);
  }
}
