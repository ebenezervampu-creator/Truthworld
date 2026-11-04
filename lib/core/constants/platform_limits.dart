/// 🔒 TRUTHWORLD PLATFORM CAPACITY & PHASE QUOTAS
///
/// Industry-standard platform capacity limits for Phase 1:
/// - 10,000 standard users (capped)
/// - 100 standard channels (capped)
/// - Custom channels: UNLIMITED (no restriction)
class PlatformLimits {
  const PlatformLimits._();

  /// Current platform rollout phase
  static const int currentPhase = 1;

  /// Maximum allowed registered users in Phase 1 (10,000)
  static const int maxStandardUsers = 10000;

  /// Maximum allowed standard creator channels in Phase 1 (100)
  static const int maxStandardChannels = 100;

  /// Custom channels have dedicated custom infrastructure and zero limits
  static const bool isCustomChannelUnlimited = true;

  /// Helpful message when standard channel cap is reached
  static const String standardChannelLimitMessage =
      'Phase 1 standard channel capacity ($maxStandardChannels channels) has been reached. '
      'Pro Channels have zero restrictions and can be created immediately, '
      'or you can apply for the standard creator waitlist.';

  /// Helpful message when user registration cap is reached
  static const String userRegistrationLimitMessage =
      'Truthworld Phase 1 capacity ($maxStandardUsers users) has been reached. '
      'New account registrations are temporarily waitlisted for early access.';
}
