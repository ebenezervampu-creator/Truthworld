/// Industry-standard playback access policy interface.
/// Decouples video player controllers and mixins from deep sub-controller
/// hierarchies, satisfying the Law of Demeter and providing resilient fallbacks.
abstract class VideoPlaybackAccessPolicy {
  /// Whether the current viewer is an active member of the video's channel.
  bool get isChannelMember;

  /// Whether the channel creator enabled ad-free viewing perks for members.
  bool get channelHasMemberAdFreePerk;

  /// Whether playback is ad-free for the current user and context.
  bool get hasAdFreePlayback;

  /// Whether the viewer is authorized to stream high resolution (1080p, 1440p, 4K).
  bool get canStreamHighResolution;
}
