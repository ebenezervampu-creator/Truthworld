import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad/mixins/ad_metrics_mixin.dart';
import 'package:truthworld/core/services/ad/models/ad_item.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:url_launcher/url_launcher.dart';

mixin AdTargetingMixin on AdMetricsMixin {
  /// Check if ads should be rendered based on user's premium status and real campaigns availability
  RxBool get showAds {
    final hasAuth = Get.isRegistered<AuthService>();
    final isFullPremium = hasAuth && AuthService.to.hasFullPremium;
    return RxBool(
      !isFullPremium && customCampaigns.any((ad) => ad.status == 'active'),
    );
  }

  bool hasAdsForType(String type) {
    if (Get.isRegistered<AuthService>() && AuthService.to.isPremiumUser.value) {
      final auth = AuthService.to;
      // Full TruthWorld Premium ($2) & Fact-Checked ($3): zero ads anywhere
      if (auth.hasFullPremium) {
        return false;
      }
      // Audio Premium (₹40): suppresses audio and audio_only ads
      if (type == 'audio' || type == 'audio_only') {
        return false;
      }
    }
    return customCampaigns.any(
      (ad) =>
          ((type == 'scroll' && (ad.adType == 'scroll' || ad.adType == 'search')) ||
              ad.adType == type) &&
          ad.status == 'active',
    );
  }

  /// Retrieve ad dynamically by list/grid index. Returns null if no active campaigns match.
  AdItem? getAdForIndex(int index) {
    final activeCampaigns = customCampaigns
        .where((ad) => ad.status == 'active')
        .toList();
    if (activeCampaigns.isEmpty) {
      return null;
    }
    final targeted = activeCampaigns.where(matchesUserTargeting).toList();
    final candidateList = targeted.isNotEmpty ? targeted : activeCampaigns;
    return candidateList[index % candidateList.length];
  }

  /// Checks whether an ad matches the currently logged-in user's demographics.
  /// Broad campaigns (All Ages, All Genders, Worldwide) match all users.
  /// Specific demographic campaigns require matching viewer demographic data.
  bool matchesUserTargeting(AdItem ad) {
    if (!Get.isRegistered<AuthService>()) return true;
    final auth = AuthService.to;

    // 1. Age targeting
    if (ad.targetAgeGroups != null && ad.targetAgeGroups!.isNotEmpty) {
      final hasAllAges = ad.targetAgeGroups!.any(
        (grp) =>
            grp.toLowerCase() == 'all' ||
            grp.toLowerCase() == 'all ages',
      );

      if (!hasAllAges) {
        final userAgeGrp = auth.userAgeGroup.value?.trim();
        final userAge = auth.userAge.value;
        if (userAgeGrp != null && userAgeGrp.isNotEmpty) {
          final matchesGroup = ad.targetAgeGroups!.any(
            (grp) =>
                grp.toLowerCase() == userAgeGrp.toLowerCase() ||
                userAgeGrp.toLowerCase().contains(grp.toLowerCase()),
          );
          if (!matchesGroup) return false;
        } else if (userAge != null) {
          final matchesNum = ad.targetAgeGroups!.any((grp) {
            if (grp == 'Under 13' && userAge < 13) return true;
            if (grp == '13–17' && userAge >= 13 && userAge <= 17) return true;
            if (grp == '18–24' && userAge >= 18 && userAge <= 24) return true;
            if (grp == '25–34' && userAge >= 25 && userAge <= 34) return true;
            if (grp == '35–44' && userAge >= 35 && userAge <= 44) return true;
            if (grp == '45–54' && userAge >= 45 && userAge <= 54) return true;
            if (grp == '55–64' && userAge >= 55 && userAge <= 64) return true;
            if (grp == '65+' && userAge >= 65) return true;
            return false;
          });
          if (!matchesNum) return false;
        } else {
          // Viewer demographic unknown; does not qualify for specific age targeting
          return false;
        }
      }
    }

    // 2. Gender targeting
    if (ad.targetGenders != null && ad.targetGenders!.isNotEmpty) {
      final hasAllGenders = ad.targetGenders!.any(
        (g) =>
            g.toLowerCase() == 'all' ||
            g.toLowerCase() == 'all genders',
      );

      if (!hasAllGenders) {
        final userGender = auth.userGender.value?.trim().toLowerCase();
        if (userGender != null &&
            userGender.isNotEmpty &&
            userGender != 'prefer not to say') {
          final matchesGender = ad.targetGenders!.any((g) {
            final target = g.toLowerCase();
            if (target == 'all' || target == 'all genders') return true;
            if (userGender.startsWith(target) || target.startsWith(userGender)) {
              return true;
            }
            return false;
          });
          if (!matchesGender) return false;
        } else {
          // Viewer demographic unknown; does not qualify for specific gender targeting
          return false;
        }
      }
    }

    // 3. Location targeting
    if (ad.targetLocations != null && ad.targetLocations!.isNotEmpty) {
      final hasWorldwide = ad.targetLocations!.any(
        (loc) =>
            loc.toLowerCase() == 'worldwide' ||
            loc.toLowerCase() == 'all locations',
      );

      if (!hasWorldwide) {
        final userCountry = auth.userCountry.value?.trim().toLowerCase();
        final userCity = auth.userCity.value?.trim().toLowerCase();
        final userLoc = auth.userLocation.value?.trim().toLowerCase();

        if (userLoc != null || userCountry != null || userCity != null) {
          final matchesLocation = ad.targetLocations!.any((loc) {
            final l = loc.toLowerCase();
            if (userCountry != null &&
                (userCountry.contains(l) || l.contains(userCountry))) {
              return true;
            }
            if (userCity != null &&
                (userCity.contains(l) || l.contains(userCity))) {
              return true;
            }
            if (userLoc != null &&
                (userLoc.contains(l) || l.contains(userLoc))) {
              return true;
            }
            return false;
          });
          if (!matchesLocation) return false;
        } else {
          // Viewer location unknown; does not qualify for specific geo targeting
          return false;
        }
      }
    }

    return true;
  }

  /// Get specific ads based on target adType
  List<AdItem> getAdsForType(String type) {
    if (Get.isRegistered<AuthService>()) {
      final auth = AuthService.to;
      if (auth.hasFullPremium) return [];
      if (auth.isAudioPremiumOnly && (type == 'audio' || type == 'audio_only')) {
        return [];
      }
    }
    final matchedCandidates = customCampaigns
        .where(
          (ad) =>
              ((type == 'scroll' && (ad.adType == 'scroll' || ad.adType == 'search')) ||
                  ad.adType == type) &&
              ad.status == 'active' &&
              !hiddenAdIds.contains(ad.id),
        )
        .toList();

    // Prioritize targeted ads for the current user's profile
    final targeted = matchedCandidates.where(matchesUserTargeting).toList();
    if (targeted.isNotEmpty) {
      return targeted;
    }
    return matchedCandidates;
  }

  /// Get list of active skippable video ads
  List<AdItem> getSkippableVideoAds() {
    if (Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium) {
      return [];
    }
    final activeVideoAds = customCampaigns
        .where(
          (ad) =>
              ad.isSkippableAd &&
              ad.videoUrl != null &&
              ad.videoUrl!.isNotEmpty &&
              ad.status == 'active',
        )
        .toList();

    // Prioritize targeted video ads for current user
    final targeted = activeVideoAds.where(matchesUserTargeting).toList();
    if (targeted.isNotEmpty) {
      return targeted;
    }
    return activeVideoAds;
  }

  /// Get active video sponsor campaign for a given video ID (prioritizing user targeting)
  AdItem? getSponsorAdForVideo(String? videoId) {
    if (Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium) {
      return null;
    }
    final activeSponsors = customCampaigns
        .where((ad) => ad.adType == 'video_sponsor' && ad.status == 'active')
        .toList();

    if (videoId != null && videoId.isNotEmpty) {
      final videoSpecific =
          activeSponsors.where((ad) => ad.videoId == videoId).toList();
      if (videoSpecific.isNotEmpty) {
        final targeted = videoSpecific.where(matchesUserTargeting).toList();
        return targeted.isNotEmpty ? targeted.first : videoSpecific.first;
      }
    }

    final targetedGlobal = activeSponsors.where(matchesUserTargeting).toList();
    return targetedGlobal.isNotEmpty
        ? targetedGlobal.first
        : activeSponsors.firstOrNull;
  }

  /// Unified handler when an ad card (e.g. HomepageAdCard, ScrollAdCard) is tapped.
  /// If the ad has a video, it plays that video in VideoScreen.
  /// If it does not have a video, it navigates to the CTA link provided.
  Future<void> handleAdTap(AdItem ad) async {
    if (ad.hasVideo) {
      Video? targetVideo;
      if (ad.videoId != null && ad.videoId!.trim().isNotEmpty) {
        final cleanVideoId = ad.videoId!.trim();
        targetVideo = DeepLinkService.instance.getVideoFromCache(cleanVideoId);
        if (targetVideo == null) {
          try {
            targetVideo = await DeepLinkService.instance
                .loadVideo(cleanVideoId)
                .timeout(
                  const Duration(milliseconds: 1500),
                  onTimeout: () => null,
                );
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'AdService.loadVideo');
          }
        }
      }

      targetVideo ??= ad.toVideo();

      if (targetVideo.videoUrl.isNotEmpty ||
          targetVideo.hlsUrl.isNotEmpty ||
          targetVideo.dashUrl.isNotEmpty ||
          targetVideo.adaptiveResolutions.isNotEmpty) {
        recordClick(ad.id);
        await MiniplayerNavigationHelper.navigateToVideoScreen(
          video: targetVideo,
          routeArguments: {
            'video': targetVideo,
            'heroTag': 'ad_${ad.id}',
          },
        );
        return;
      }
    }

    // Fallback: No video present or playable -> open link provided
    await launchCtaUrl(ad);
  }

  /// Launch Call-To-Action (CTA) target URL in external browser/app
  Future<void> launchCtaUrl(AdItem ad) async {
    recordClick(ad.id);
    final rawTarget = ad.ctaTarget.trim();
    if (rawTarget.isEmpty) return;

    if (rawTarget == '/premium') {
      Get.toNamed('/premium');
      return;
    }

    var formattedUrl = rawTarget;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    try {
      final uri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.launchCtaUrl');
    }
  }

}
