/// Unified export for TruthWorld Ad Widgets suite.
///
/// Modularized architecture with single-responsibility components:
/// - [AdMediaWidget] & [AdMediaController]: Reactive video/image ad media display
/// - [AdCardController]: Hover state and tracking controller
/// - [HomepageAdCard]: Rich YouTube feed-scale native ad card
/// - [ScrollAdCard]: Compact feed and scroll interstitial ad card
/// - [PinnedSponsorCommentCard] & [showSponsorDiscussionModal]: Verified sponsor comments
library;

export 'ad/ad_card_controller.dart';
export 'ad/ad_media_controller.dart';
export 'ad/ad_media_widget.dart';
export 'ad/homepage_ad_card.dart';
export 'ad/pinned_sponsor_comment_card.dart';
export 'ad/scroll_ad_card.dart';
export 'ad/sponsor_comment_reply_sheet.dart';
