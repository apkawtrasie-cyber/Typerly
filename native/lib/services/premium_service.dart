import '../../models/profile.dart';

class PremiumService {
  // Free user limits
  static const int maxLeaguesForFreeUser = 1;
  static const bool customMatchesForFreeUser = false;
  static const bool showAdsForFreeUser = true;

  // Premium user benefits
  static const int maxLeaguesForPremiumUser = -1; // Unlimited
  static const bool customMatchesForPremiumUser = true;
  static const bool showAdsForPremiumUser = false;

  /// Check if user can create more leagues
  static bool canCreateLeague(Profile profile, int currentLeagueCount) {
    if (profile.isPremiumActive) {
      return true; // Unlimited for premium
    }
    return currentLeagueCount < maxLeaguesForFreeUser;
  }

  /// Check if user can create custom matches
  static bool canCreateCustomMatches(Profile profile) {
    if (profile.isPremiumActive) {
      return customMatchesForPremiumUser;
    }
    return customMatchesForFreeUser;
  }

  /// Check if user should see ads
  static bool shouldShowAds(Profile profile) {
    if (profile.isPremiumActive) {
      return showAdsForPremiumUser;
    }
    return showAdsForFreeUser;
  }

  /// Get remaining league slots for free user
  static int getRemainingLeagueSlots(Profile profile, int currentLeagueCount) {
    if (profile.isPremiumActive) {
      return -1; // Unlimited
    }
    return maxLeaguesForFreeUser - currentLeagueCount;
  }

  /// Get league creation limit message
  static String getLeagueLimitMessage(Profile profile, int currentLeagueCount) {
    if (profile.isPremiumActive) {
      return 'You can create unlimited leagues with Premium';
    }
    final remaining = getRemainingLeagueSlots(profile, currentLeagueCount);
    if (remaining <= 0) {
      return 'You have reached your league limit. Upgrade to Premium for unlimited leagues.';
    }
    return 'You can create $remaining more league${remaining == 1 ? '' : 's'}. Upgrade to Premium for unlimited.';
  }

  /// Check if feature is premium only
  static bool isPremiumFeature(String feature) {
    const premiumFeatures = {
      'custom_matches',
      'unlimited_leagues',
      'no_ads',
      'advanced_analytics',
      'custom_themes',
    };
    return premiumFeatures.contains(feature);
  }

  /// Get upgrade message for premium feature
  static String getPremiumFeatureMessage(String feature) {
    switch (feature) {
      case 'custom_matches':
        return 'Custom matches are available for Premium users only';
      case 'unlimited_leagues':
        return 'Unlimited leagues are available for Premium users only';
      case 'no_ads':
        return 'Ad-free experience is available for Premium users only';
      case 'advanced_analytics':
        return 'Advanced analytics are available for Premium users only';
      case 'custom_themes':
        return 'Custom themes are available for Premium users only';
      default:
        return 'This feature is available for Premium users only';
    }
  }
}
